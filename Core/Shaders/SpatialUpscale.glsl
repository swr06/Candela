#version 330 core

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out vec4 o_Specular;
layout (location = 2) out vec4 o_Volumetrics;

in vec2 v_TexCoords;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;
uniform sampler2D u_NormalsHF;
uniform sampler2D u_PBR;

uniform sampler2D u_Diffuse;
uniform sampler2D u_Specular;
uniform sampler2D u_Volumetrics;

uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;

uniform float u_zNear;
uniform float u_zFar;

uniform vec3 u_ViewerPosition;

vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

void SpatialUpscale(float Depth, vec3 Normal, vec3 NormalHF, float Roughness, vec3 Incident, out vec4 Diffuse, out vec4 Specular, out vec4 Volumetrics) {

	const float Atrous[3] = float[3]( 1.0f, 2.0f / 3.0f, 1.0f / 6.0f );
	const ivec2 Kernel = ivec2(1, 1); // <- Kernel size 
	
	const bool ENABLED = true;

	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	ivec2 PixelDownscaled = Pixel / 2;

	if (!ENABLED) {

		Diffuse = texelFetch(u_Diffuse, PixelDownscaled, 0).xyzw;
		Specular = texelFetch(u_Specular, PixelDownscaled, 0);
		Volumetrics = texelFetch(u_Volumetrics, PixelDownscaled, 0).xyzw;
		return;
	}

	float TotalWeight = 1.0f;

	//SG CenterRSG = RoughnessLobe(Roughness, Normal, Incident);

	Diffuse = texelFetch(u_Diffuse, PixelDownscaled, 0).xyzw;
	Specular = texelFetch(u_Specular, PixelDownscaled, 0);
	Volumetrics = texelFetch(u_Volumetrics, PixelDownscaled, 0).xyzw;

	for (int x = -Kernel.x ; x <= Kernel.x ; x++) {

		for (int y = -Kernel.y ; y <= Kernel.y ; y++) {
			
			if (x == 0 && y == 0) { continue ; }

			float KernelWeight;
			
			KernelWeight = Atrous[abs(x)] * Atrous[abs(y)];

			ivec2 SampleCoord = PixelDownscaled + ivec2(x, y);
			ivec2 SampleCoordHighRes = SampleCoord * 2;

			float SampleDepth = LinearizeDepth(texelFetch(u_Depth, SampleCoordHighRes, 0).x);
			vec3 SampleNormal = texelFetch(u_Normals, SampleCoordHighRes, 0).xyz;
			vec3 SampleNormalHF = texelFetch(u_NormalsHF, SampleCoordHighRes, 0).xyz;
			vec3 SamplePBR = texelFetch(u_PBR, SampleCoordHighRes, 0).xyz;

			float DepthWeight = pow(exp(-abs(Depth - SampleDepth)), 384.0f);
			float NormalWeight = pow(max(dot(SampleNormal, Normal), 0.0f), 32.0f);
			float NormalWeightHF = pow(max(dot(SampleNormalHF, NormalHF), 0.0f), 32.0f);
			float RoughnessWeight = pow(clamp(1.0f-(abs(SamplePBR.x-Roughness)/4.0f), 0.0f, 1.0f), 24.0f);
			float Weight = clamp(DepthWeight * NormalWeight * KernelWeight * NormalWeightHF * RoughnessWeight, 0.0f, 1.0f);

			Diffuse += texelFetch(u_Diffuse, SampleCoord, 0).xyzw * Weight;
			Specular += texelFetch(u_Specular, SampleCoord, 0) * Weight;
			Volumetrics += texelFetch(u_Volumetrics, SampleCoord, 0).xyzw * Weight;
			TotalWeight += Weight;
		}
	}

	Specular /= TotalWeight;
	Diffuse /= TotalWeight;
	Volumetrics /= TotalWeight;
}

vec3 SampleIncidentRayDirection(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}

void main() {

	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	
	float Depth = texelFetch(u_Depth, Pixel, 0).x;
	vec3 Normal = texelFetch(u_Normals, Pixel, 0).xyz;
	vec3 NormalHF = texelFetch(u_NormalsHF, Pixel, 0).xyz;
	vec3 PBR = texelFetch(u_PBR, Pixel, 0).xyz;

	vec3 Incident = SampleIncidentRayDirection(v_TexCoords);

    SpatialUpscale(LinearizeDepth(Depth), Normal, NormalHF, PBR.x, Incident, o_Diffuse, o_Specular, o_Volumetrics);
}