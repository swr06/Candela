#version 430 core

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out vec4 o_Specular;
layout (location = 2) out vec4 o_Volumetrics;

layout (std430, binding = 12) restrict buffer CommonUniformData 
{
	float u_Time;
	int u_Frame;
	int u_CurrentFrame;

	mat4 u_ViewProjection;
	mat4 u_Projection;
	mat4 u_View;
	mat4 u_InverseProjection;
	mat4 u_InverseView;
	mat4 u_PrevProjection;
	mat4 u_PrevView;
	mat4 u_PrevInverseProjection;
	mat4 u_PrevInverseView;
	mat4 u_InversePrevProjection;
	mat4 u_InversePrevView;

	vec3 u_ViewerPosition;
	vec3 u_Incident;
	vec3 u_SunDirection;
	vec3 u_LightDirection;

	float u_zNear;
	float u_zFar;
};


in vec2 v_TexCoords;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;
uniform sampler2D u_NormalsHF;
uniform sampler2D u_PBR;

uniform sampler2D u_Diffuse;
uniform sampler2D u_Specular;
uniform sampler2D u_Volumetrics;

uniform bool u_Enabled;

bool ENABLED = u_Enabled;

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

float GradientNoise()
{
	vec2 coord = gl_FragCoord.xy + mod(u_Time * 100.493850275f, 500.0f);
	float noise = fract(52.9829189f * fract(0.06711056f * coord.x + 0.00583715f * coord.y));
	return noise;
}

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

void SpatialUpscale(float Depth, vec3 Normal, vec3 NormalHF, float Roughness, vec3 Incident, out vec4 Diffuse, out vec4 Specular, out vec4 Volumetrics) {

	const float Atrous[3] = float[3]( 1.0f, 2.0f / 3.0f, 1.0f / 6.0f );
	const ivec2 Kernel = ivec2(1, 1); // <- Kernel size 

	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	ivec2 PixelDownscaled = Pixel / 2;

	if (!ENABLED) {

		Diffuse = texelFetch(u_Diffuse, PixelDownscaled, 0).xyzw;
		Specular = texelFetch(u_Specular, PixelDownscaled, 0);
		Volumetrics = texelFetch(u_Volumetrics, PixelDownscaled, 0).xyzw;
		return;
	}

	float TotalWeight = 1.0f;
	float TotalWeightS = 1.0f;
	float TotalWeightV = 1.0f;

	//SG CenterRSG = RoughnessLobe(Roughness, Normal, Incident);

	Diffuse = texelFetch(u_Diffuse, PixelDownscaled, 0).xyzw;
	Specular = texelFetch(u_Specular, PixelDownscaled, 0);
	Volumetrics = texelFetch(u_Volumetrics, PixelDownscaled, 0).xyzw;

	vec2 HashV = hash2() * 2.0f - 1.0f;

	for (int x = -Kernel.x ; x <= Kernel.x ; x++) {

		for (int y = -Kernel.y ; y <= Kernel.y ; y++) {
			
			if (x == 0 && y == 0) { continue ; }

			float KernelWeight = 1.0f; //Atrous[abs(x)] * Atrous[abs(y)];

			ivec2 SampleCoord = ivec2(PixelDownscaled) + ivec2(x, y);
			ivec2 SampleCoordHighRes = SampleCoord * 2;

			vec2 SampleUV = vec2(SampleCoord) / textureSize(u_Diffuse, 0).xy;

			float SampleDepthNL = texelFetch(u_Depth, SampleCoordHighRes, 0).x;
			float SampleDepth = LinearizeDepth(SampleDepthNL);
			vec3 SampleNormal = texelFetch(u_Normals, SampleCoordHighRes, 0).xyz;
			vec3 SampleNormalHF = texelFetch(u_NormalsHF, SampleCoordHighRes, 0).xyz;
			vec3 SamplePBR = texelFetch(u_PBR, SampleCoordHighRes, 0).xyz;

			float DepthWeight = pow(exp(-abs(Depth - SampleDepth)), 256.0f);
			float NormalWeight = pow(max(dot(SampleNormal, Normal), 0.0f), 16.0f);
			float NormalWeightHF = pow(max(dot(SampleNormalHF, NormalHF), 0.0f), 16.0f);
			float RoughnessWeight = pow(clamp(1.0f-(abs(SamplePBR.x-Roughness)/4.0f), 0.0f, 1.0f), 24.0f);
			float Weight = clamp(DepthWeight * NormalWeight * KernelWeight, 0.0f, 1.0f);
			float WeightS = clamp(DepthWeight * NormalWeight * NormalWeightHF * KernelWeight * RoughnessWeight, 0.0f, 1.0f);
			float WeightV = clamp(DepthWeight * NormalWeight * KernelWeight, 0.0f, 1.0f);

			if (SampleDepthNL > 0.99999f) {
				WeightV = clamp(KernelWeight, 0.0f, 1.0f);
			}

			Diffuse += texelFetch(u_Diffuse, SampleCoord, 0) * Weight;
			Specular += texelFetch(u_Specular, SampleCoord, 0) * WeightS;
			Volumetrics += texelFetch(u_Volumetrics, SampleCoord, 0) * WeightV;

			TotalWeight += Weight;
			TotalWeightS += WeightS;
			TotalWeightV += WeightV;
		}
	}

	Specular /= TotalWeightS;
	Diffuse /= TotalWeight;
	Volumetrics /= TotalWeightV;
}

vec3 SampleIncidentRayDirection(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return normalize(vec3(u_InverseView * eye));
}

void main() {

	ivec2 Pixel = ivec2(gl_FragCoord.xy);

	vec2 UV = (vec2(Pixel) / textureSize(u_Depth, 0).xy);

	HASH2SEED = UV.x * UV.y * 64.0 * u_Time;
	
	float Depth = texelFetch(u_Depth, Pixel, 0).x;
	vec3 Normal = texelFetch(u_Normals, Pixel, 0).xyz;
	vec3 NormalHF = texelFetch(u_NormalsHF, Pixel, 0).xyz;
	vec3 PBR = texelFetch(u_PBR, Pixel, 0).xyz;

	vec3 Incident = SampleIncidentRayDirection(v_TexCoords);

    SpatialUpscale(LinearizeDepth(Depth), Normal, NormalHF, PBR.x, Incident, o_Diffuse, o_Specular, o_Volumetrics);

}