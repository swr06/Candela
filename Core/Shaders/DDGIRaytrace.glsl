#version 450 core 

layout(local_size_x = 256) in;

#include "TraverseBVH.glsl"
#include "Include/Octahedral.glsl"

struct Ray {
	vec4 RayOrigin;
	vec4 RayDirection;
};

layout (std430, binding = 0) readonly buffer InputRays {
	Ray Rays[];
};

layout (std430, binding = 1) writeonly buffer ProbeData {
	vec4 Pixels[];
};

uniform mat4 u_ShadowMatrices[5]; // <- shadow matrices 
uniform sampler2D u_ShadowTextures[5]; // <- the shadowmaps themselves 
uniform float u_ShadowClipPlanes[5]; // <- world space clip distances 

uniform samplerCube u_Skymap;
uniform int u_RayCount;

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
	
		ProjectionCoordinates = u_ShadowMatrices[Cascade] * vec4(WorldPosition + N * 0.05f, 1.0f);

		if (ProjectionCoordinates.z < 1.0f && abs(ProjectionCoordinates.x) < 1.0f && abs(ProjectionCoordinates.y) < 1.0f)
		{
			ProjectionCoordinates = ProjectionCoordinates * 0.5f + 0.5f;
			ClosestCascade = Cascade;
			break;
		}
	}

	if (ClosestCascade < 0) {
		return 0.0f;
	}
	
	float Bias = 0.001f;
	vec2 SampleUV = ProjectionCoordinates.xy;
	Shadow = float(ProjectionCoordinates.z - Bias > SampleShadowMap(SampleUV, ClosestCascade)); 
	return 1.0f - Shadow;
}

vec3 GetDirect(in vec3 WorldPosition, in vec3 Normal, in vec3 Albedo) {

	float Shadow = GetDirectShadow(WorldPosition, Normal);
	return vec3(Albedo) * 10.0f * Shadow;

}

void main() {

	int Invocation = int(gl_GlobalInvocationID.x);

	Ray ray = Rays[Invocation];

	if (Invocation >= u_RayCount) {
		return;
	}

    int IntersectedMesh = -1;
    int IntersectedTri = -1;
	vec4 TUVW = vec4(-1.0f);
	vec3 Albedo = vec3(0.0f);
	vec3 iNormal = vec3(-1.0f);
	
	IntersectRay(ray.RayOrigin.xyz, ray.RayDirection.xyz, TUVW, IntersectedMesh, IntersectedTri, Albedo, iNormal);

	// Compute radiance 
	vec3 FinalRadiance = TUVW.x < 0.0f ? texture(u_Skymap, vec3(0.0f, 1.0f, 0.0f)).xyz * 3.0f : GetDirect((ray.RayOrigin.xyz + ray.RayDirection.xyz * TUVW.x), iNormal, Albedo);

	int Probe = floatBitsToInt(ray.RayDirection.w);

	int PixelIndex = Probe * (12 * 12);
	vec2 Octahedral = OctahedralEncode(ray.RayDirection.xyz);
	ivec2 LocalPixel = ivec2(Octahedral * vec2(11, 11));
	int Flattened = LocalPixel.x * 12 + LocalPixel.y;

	int WriteIndex = PixelIndex + Flattened;

	Pixels[WriteIndex] = vec4(FinalRadiance, 1.0f);
}

