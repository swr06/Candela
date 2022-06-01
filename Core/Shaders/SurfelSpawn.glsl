#version 430 core 

layout(local_size_x = 16, local_size_y = 16) in;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;

uniform float u_Time;
uniform float u_zNear;
uniform float u_zFar;

const int LIST_SIZE = 8 ;

struct Surfel {
	vec4 Position; // <- Radius in w 
	vec4 Normal; // <- Luminance map offset in w
	vec4 Radiance; // <- Accumulated frames in w
	vec4 Extra;  // <- Surfel ID, Valid (0 - 1)

};

layout (std430, binding = 0) buffer SSBO_SurfelBuffer {
	Surfel SurfelCellVolume[];
};

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

ivec3 Get3DIdx(int idx)
{
    ivec3 GridSize = ivec3(32, 16, 32);
	int z = idx / (GridSize.x * GridSize.y);
	idx -= (z * GridSize.x * GridSize.y);
	int y = idx / GridSize.x;
	int x = idx % GridSize.x;
	return ivec3(x, y, z);
}

int Get1DIdx(ivec3 index)
{
    ivec3 GridSize = ivec3(32, 16, 32);
    return (index.z * GridSize.x * GridSize.y) + (index.y * GridSize.x) + GridSize.x;
}

int GetNearestSurfelCell(vec3 Position) {

	Position += vec3(16.,8.,16.);
	ivec3 Rounded = ivec3(floor(Position));

	int Index1D = Get1DIdx(Rounded) * LIST_SIZE;
	return Index1D;
}

vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

void main() {
	
	ivec2 Pixel = ivec2(gl_GlobalInvocationID.xy);
	vec2 UV = vec2(Pixel) / textureSize(u_Depth, 0).xy;

	HASH2SEED = (UV.x * UV.y) * 64.0 * u_Time;

	float Depth = texture(u_Depth, UV, 0).x;

	float LinearDepth = LinearizeDepth(Depth);

	float LinearDepthNormalzed = LinearDepth / u_zFar;

	vec3 Normal = normalize(texture(u_Normals, UV, 0).xyz);

	vec3 WorldPosition = WorldPosFromDepth(Depth, UV) + Normal * 0.02f;

	int SurfelCellIndex = GetNearestSurfelCell(WorldPosition);

	float PixelCoverage = 0.0f;
	int CellSurfelsUsed = 0;

	groupMemoryBarrier();
	barrier();

	for (int i = 0 ; i < LIST_SIZE ; i++) {
		
		int SurfelIndex = SurfelCellIndex + i;
		Surfel surfel = SurfelCellVolume[SurfelIndex];

		if (surfel.Extra.y > 0.01f) {
			
			vec3 Difference = WorldPosition - surfel.Position.xyz;
			float DistanceSquared = dot(Difference, Difference);
			
			float ActualDistance = sqrt(DistanceSquared);

			float NormalWeight = clamp(dot(Normal, surfel.Normal.xyz), 0.0f, 1.0f);
			float PositionWeight = DistanceSquared;
			float Total = smoothstep(0.0f, 1.0f, clamp(NormalWeight * PositionWeight, 0.0f, 1.0f));
			PixelCoverage += Total;
			CellSurfelsUsed += 1;
		}
	}

	barrier();

	if (CellSurfelsUsed < LIST_SIZE)
	{
		int WriteIndex = SurfelCellIndex + CellSurfelsUsed ;
		float Probability = pow(1.0f - LinearDepthNormalzed, 6.0f);

		float Random = hash2().x; 

		if (Random > 0.4)
		{
			// Spawn surfel in 

			Surfel WriteSurfel;

			WriteSurfel.Position = vec4(WorldPosition, 0.05f);
			WriteSurfel.Normal = vec4(Normal, 1.0f);
			WriteSurfel.Radiance = vec4(1.0f);
			WriteSurfel.Extra = vec4(5.0f);

			SurfelCellVolume[WriteIndex] = WriteSurfel;
		}
	}

}