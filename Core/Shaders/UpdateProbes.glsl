#version 450 core 

#define PI 3.1415926535

#include "TraverseBVH.glsl"

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

	vec3 SamplePoint = (WorldPosition - u_BoxOrigin) / u_Size; 
	SamplePoint = SamplePoint * 0.5 + 0.5; 
	
	return texture(u_History, SamplePoint).xyz;
}

void main() {

	ivec3 Pixel = ivec3(gl_GlobalInvocationID.xyz);

	vec3 TexCoords = vec3(Pixel) / u_Resolution;

    HASH2SEED = ((TexCoords.x * TexCoords.y * TexCoords.z) * 64.0 * u_Time) + (TexCoords.z * TexCoords.y); hash2();

	vec3 Clip = TexCoords * 2.0f - 1.0f;
	vec3 RayOrigin = u_BoxOrigin + Clip * u_Size;

    vec3 Hash = vec3(hash2(), hash2().x);
    vec3 LambertSample = LambertBRDF(Hash);

    LambertSample = normalize(LambertSample);

    // Outputs 
    int IntersectedMesh = -1;
    int IntersectedTri = -1;
	vec4 TUVW = vec4(-1.0f);
	vec3 Albedo = vec3(0.0f);
	vec3 iNormal = vec3(-1.0f);
	
	// Intersect ray 
	IntersectRay(RayOrigin, LambertSample, TUVW, IntersectedMesh, IntersectedTri, Albedo, iNormal);

	vec3 iWorldPos = (RayOrigin + LambertSample * TUVW.x);

	vec3 FinalRadiance = TUVW.x < 0.0f ? vec3(0.2f,0.2f,1.0f) * 2.0f : GetDirect(iWorldPos, iNormal, Albedo);

	float Packed = 1.0f;

	if (TUVW.x > 0.0f && true) {
		vec3 Bounce = SampleProbes(iWorldPos);
		FinalRadiance += Bounce * 0.7f;
	}

	FinalRadiance = mix(FinalRadiance, texelFetch(u_History, Pixel, 0).xyz, 0.99f);

	imageStore(o_OutputData, Pixel, vec4(FinalRadiance, Packed));
}


