#version 450 core 

layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba16f, binding = 0) uniform image2D o_OutputData;

#include "TraverseBVH.glsl"

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform vec2 u_Dims;

uniform sampler2D u_DepthTexture;
uniform sampler2D u_NormalTexture;
uniform samplerCube u_Skymap;

vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

vec3 GetRayDirectionAt(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}

void main() {

	ivec2 Pixel = ivec2(gl_GlobalInvocationID.xy);

	if (Pixel.x < 0 || Pixel.y < 0 || Pixel.x > int(u_Dims.x) || Pixel.y > int(u_Dims.y)) {
		return;
	}

	vec2 TexCoords = vec2(Pixel) / u_Dims;

	vec3 rO = u_InverseView[3].xyz;
	vec3 rD = normalize(GetRayDirectionAt(TexCoords).xyz);

	float Depth = texture(u_DepthTexture, TexCoords).x;

	if (Depth > 0.999999f) {
		imageStore(o_OutputData, Pixel, vec4(texture(u_Skymap, rD).xyz, 1.0f));
		return;
	}

	vec3 WorldPosition = WorldPosFromDepth(Depth, TexCoords);

	vec3 Normal = normalize(texture(u_NormalTexture, TexCoords).xyz);

	vec3 Reflected = reflect(rD, Normal);

	float s = 1.0f;

    int IntersectedMesh = -1;
    int IntersectedTri = -1;
	vec4 TUVW = vec4(-1.0f);
	vec3 Albedo = vec3(0.0f);
	vec3 iNormal = vec3(-1.0f);
	
	IntersectRay(WorldPosition + Normal * 0.1, Reflected, TUVW, IntersectedMesh, IntersectedTri, Albedo, iNormal);

	if (TUVW.x < 0.0f) {
		Albedo = texture(u_Skymap,-Reflected).xyz;
	}

	imageStore(o_OutputData, Pixel, vec4(Albedo, 1.0f));
}
