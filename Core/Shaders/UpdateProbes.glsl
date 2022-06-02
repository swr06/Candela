#version 450 core 

#define PI 3.1415926535

#include "TraverseBVH.glsl"
#include "Include/Octahedral.glsl"

layout(local_size_x = 8, local_size_y = 4, local_size_z = 8) in;

layout(rgba16f, binding = 0) uniform image3D o_OutputData;

uniform vec3 u_BoxOrigin;
uniform vec3 u_Resolution;
uniform vec3 u_Size;

uniform mat4 u_ShadowMatrices[5]; // <- shadow matrices 
uniform sampler2D u_ShadowTextures[5]; // <- the shadowmaps themselves 
uniform float u_ShadowClipPlanes[5]; // <- world space clip distances 

uniform vec3 u_SunDirection;
uniform float u_Time;

uniform sampler3D u_History;
uniform vec3 u_PreviousOrigin;

uniform samplerCube u_Skymap;

struct ProbeMapPixel {
	vec2 Packed;
};

layout (std430, binding = 2) buffer SSBO_ProbeMaps {
	ProbeMapPixel MapData[]; // x has luminance data, y has packed depth and depth^2
};

ivec3 Get3DIdx(int idx, ivec3 GridSize)
{
	int z = idx / (GridSize.x * GridSize.y);
	idx -= (z * GridSize.x * GridSize.y);
	int y = idx / GridSize.x;
	int x = idx % GridSize.x;
	return ivec3(x, y, z);
}

int Get1DIdx(ivec3 index, ivec3 GridSize)
{
    return (index.z * GridSize.x * GridSize.y) + (index.y * GridSize.x) + GridSize.x;
}

int Get1DIdx(ivec2 Coord, ivec2 GridSize) {
	return (Coord.x * GridSize.x) + Coord.y;
}

float SampleShadowMap(vec2 SampleUV, int Map) {

	switch (Map) {
		
		case 0 :
			return texture(u_ShadowTextures[0], SampleUV).x; break;

		case 1 :
			return texture(u_ShadowTextures[1], SampleUV).x; break;

		case 2 :
			return texture(u_ShadowTextures[2], SampleUV).x; break;

		case 3 :
			return texture(u_ShadowTextures[3], SampleUV).x; break;

		case 4 :
			return texture(u_ShadowTextures[4], SampleUV).x; break;
	}

	return texture(u_ShadowTextures[4], SampleUV).x;
}

bool IsInBox(vec3 point, vec3 Min, vec3 Max) {
  return (point.x >= Min.x && point.x <= Max.x) &&
         (point.y >= Min.y && point.y <= Max.y) &&
         (point.z >= Min.z && point.z <= Max.z);
}

float GetDirectShadow(vec3 WorldPosition, vec3 N)
{
	int ClosestCascade = -1;
	float Shadow = 0.0;
	float VogelScales[5] = float[5](0.001f, 0.0015f, 0.002f, 0.00275f, 0.00325f);
	
	vec2 TexelSize = 1.0 / textureSize(u_ShadowTextures[ClosestCascade], 0);

	vec4 ProjectionCoordinates;

	float HashBorder = 1.0f; 

	for (int Cascade = 0 ; Cascade < 4; Cascade++) {
	
		ProjectionCoordinates = u_ShadowMatrices[Cascade] * vec4(WorldPosition + N * 0.0275f, 1.0f);

		if (ProjectionCoordinates.z < 1.0f && abs(ProjectionCoordinates.x) < 1.0f && abs(ProjectionCoordinates.y) < 1.0f)
		{
			{
				ProjectionCoordinates = ProjectionCoordinates * 0.5f + 0.5f;
				ClosestCascade = Cascade;
				break;
			}
		}
	}

	if (ClosestCascade < 0) {
		return 0.0f;
	}
	
	float Bias = 0.00f;
	vec2 SampleUV = ProjectionCoordinates.xy;
	Shadow = float(ProjectionCoordinates.z - Bias > SampleShadowMap(SampleUV, ClosestCascade)); 
	return 1.0f - Shadow;
}

vec3 GetDirect(in vec3 WorldPosition, in vec3 Normal, in vec3 Albedo) {

	float Shadow = GetDirectShadow(WorldPosition, Normal);
	return vec3(Albedo) * 16.0f * Shadow * clamp(dot(Normal, -u_SunDirection), 0.0f, 1.0f);
}

vec3 LambertBRDF(vec3 Hash)
{
    float phi = 2.0 * PI * Hash.x;
    float cosTheta = 2.0 * Hash.y - 1.0;
    float u = Hash.z;
    float theta = acos(cosTheta);
    float r = pow(u, 1.0 / 3.0);
    float x = r * sin(theta) * cos(phi);
    float y = r * sin(theta) * sin(phi);
    float z = r * cos(theta);
    return vec3(x, y, z);
}

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

vec3 SampleProbes(vec3 WorldPosition) {

	vec3 SamplePoint = (WorldPosition - u_PreviousOrigin) / u_Size; 
	SamplePoint = SamplePoint * 0.5 + 0.5;
	
	if (SamplePoint.x > 0.0f && SamplePoint.x < 1.0f &&
		SamplePoint.y > 0.0f && SamplePoint.y < 1.0f &&
		SamplePoint.z > 0.0f && SamplePoint.z < 1.0f) {
	
		SamplePoint *= u_Resolution;
		SamplePoint = SamplePoint + 0.5f;
		SamplePoint /= u_Resolution;

		return texture(u_History, SamplePoint).xyz;
	}

	return vec3(0.0f);
	
}

vec4 Reproject(vec3 WorldPosition) {

	vec3 SamplePoint = (WorldPosition - u_PreviousOrigin) / u_Size; 
	SamplePoint = SamplePoint * 0.5 + 0.5;
	
	if (SamplePoint.x > 0.0f && SamplePoint.x < 1.0f &&
		SamplePoint.y > 0.0f && SamplePoint.y < 1.0f &&
		SamplePoint.z > 0.0f && SamplePoint.z < 1.0f) {
	
		SamplePoint *= u_Resolution;
		SamplePoint = SamplePoint + 0.5f;

		return vec4(SamplePoint, 5.0f);
	}

	return vec4(-10.0f);
}

float Luminance(vec3 rgb)
{
    const vec3 W = vec3(0.2125, 0.7154, 0.0721);
    return dot(rgb, W);
}

vec3 SampleCone(vec2 Xi, float CosThetaMax) 
{
    float CosTheta = (1.0f - Xi.x) + Xi.x * CosThetaMax;
    float SinTheta = sqrt(1.0f - CosTheta * CosTheta);
    float phi = Xi.y * PI * 2.0f;
    vec3 L;
    L.x = SinTheta * cos(phi);
    L.y = SinTheta * sin(phi);
    L.z = CosTheta;
    return L;
}

vec3 SampleDirectionCone(vec3 L) {

	const vec3 Basis = vec3(0.0f, 1.0f, 1.0f);
	vec3 T = normalize(cross(L, Basis));
	vec3 B = cross(T, L);
	mat3 TBN = mat3(T, B, L);
	const float CosTheta = 0.987525f; 
	vec3 ConeSample = TBN * SampleCone(hash2(), CosTheta);
	return normalize(ConeSample);
}

vec3 CosWeightedHemisphere(const vec3 n, vec2 r) 
{
	float PI2 = 2.0f * 3.1415926f;
	vec3  uu = normalize(cross(n, vec3(0.0,1.0,1.0)));
	vec3  vv = cross(uu, n);
	float ra = sqrt(r.y);
	float rx = ra * cos(PI2 * r.x); 
	float ry = ra * sin(PI2 * r.x);
	float rz = sqrt(1.0 - r.y);
	vec3  rr = vec3(rx * uu + ry * vv + rz * n );
    return normalize(rr);
}

vec3 ImportanceSample(int PixelStartOffset) {

	bool ShouldImportanceSample = false;

	if (!ShouldImportanceSample) {
		vec3 HashL = vec3(hash2(), hash2().x);
		vec3 LambertSample = LambertBRDF(HashL);
		LambertSample = normalize(LambertSample);

		return LambertSample;
	}

	float Hash = hash2().x * 4.0f;

	float Sum = 0.0f;

	for (int x = 0 ; x < 8 ; x++) {
		
		for (int y = 0 ; y < 8 ; y++) {

			int SamplePixelOffset = Get1DIdx(ivec2(x,y), ivec2(8)) + PixelStartOffset;
			vec2 Packed = MapData[SamplePixelOffset].Packed;

			Sum += Packed.x;

			if (Sum >= Hash) {
					
				vec2 UV = vec2(x,y) / vec2(8.0f);

				vec3 ImportantDirection = normalize(OctahedronToUnitVector(UV));

				return SampleDirectionCone(ImportantDirection);
			}
		}

	}

	vec3 HashL = vec3(hash2(), hash2().x);
    vec3 LambertSample = LambertBRDF(HashL);
    LambertSample = normalize(LambertSample);

	return LambertSample;
}

void main() {

	ivec3 Pixel = ivec3(gl_GlobalInvocationID.xyz);

	vec3 TexCoords = vec3(Pixel) / u_Resolution;

    HASH2SEED = ((TexCoords.x * TexCoords.y * TexCoords.z) * 128.0 * u_Time) + (TexCoords.z * TexCoords.y); hash2();

	vec3 Clip = TexCoords * 2.0f - 1.0f;
	vec3 RayOrigin = u_BoxOrigin + Clip * u_Size;
	const int PerProbePixelCount = 8 * 8;
	int ProbeMapPixelStartOffset = (Get1DIdx(Pixel,ivec3(u_Resolution)) * PerProbePixelCount);

	vec3 Unjittered = RayOrigin;

	RayOrigin += vec3(hash2(), hash2().x) * 0.125f;

	vec4 Reprojected = Reproject(Unjittered);
	vec4 History = texelFetch(u_History, ivec3(Reprojected.xyz), 0).xyzw;

	vec3 DiffuseDirection = ImportanceSample(ProbeMapPixelStartOffset);
    
	// Intersect ray 

    // Outputs 
    int IntersectedMesh = -1;
    int IntersectedTri = -1;
	vec4 TUVW = vec4(-1.0f);
	vec3 Albedo = vec3(0.0f);
	vec3 iNormal = vec3(-1.0f);
	
	IntersectRay(RayOrigin, DiffuseDirection, TUVW, IntersectedMesh, IntersectedTri, Albedo, iNormal);

	// Integrate radiance for point 
	vec3 iWorldPos = (RayOrigin + DiffuseDirection * TUVW.x);

	vec3 FinalRadiance = TUVW.x < 0.0f ? texture(u_Skymap, DiffuseDirection).xyz * 2.0f : GetDirect(iWorldPos, iNormal, Albedo);

	float Packed = 1.0f;

	if (TUVW.x > 0.0f) {
		vec3 Dither = vec3(hash2(), hash2().x);
		vec3 Bounce = SampleProbes((iWorldPos + iNormal * 0.03f));
		const float AttenuationBounce = 0.75f; 
		FinalRadiance += AttenuationBounce * Bounce;
	}

	// Write map data 
	vec2 Octahedral = UnitVectorToHemiOctahedron(DiffuseDirection);
	ivec2 OctahedralMapPixel = ivec2((Octahedral * vec2(7.0f)));
	int PixelOffset = ProbeMapPixelStartOffset + Get1DIdx(OctahedralMapPixel, ivec2(8));
	MapData[PixelOffset] = ProbeMapPixel(vec2(Luminance(FinalRadiance.xyz), 1.0f));

	if (Reprojected.w > 1.01f)
	{
		FinalRadiance = mix(FinalRadiance, History.xyz, 0.99f);
	}

	imageStore(o_OutputData, Pixel, vec4(FinalRadiance, 1.0f));
}


