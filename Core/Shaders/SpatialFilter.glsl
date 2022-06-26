#version 330 core 

#define PI 3.14159265359

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"
#include "Include/SphericalGaussian.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out float o_Variance;
layout (location = 2) out vec4 o_Specular;
layout (location = 3) out vec4 o_Volumetrics;

in vec2 v_TexCoords;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;
uniform sampler2D u_NormalsHF;
uniform sampler2D u_PBR;

uniform sampler2D u_Diffuse;
uniform sampler2D u_Specular;
uniform sampler2D u_Volumetrics;

uniform bool u_FilterVolumetrics;

uniform sampler2D u_Variance; // <- Diffuse variance 

uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;

uniform float u_zNear;
uniform float u_zFar;

uniform vec3 u_ViewerPosition;

uniform int u_StepSize;
uniform float u_SqrtStepSize;
uniform sampler2D u_FrameCounters;
uniform float u_Time;

uniform int u_Pass;

uniform bool u_Enabled;

bool SPATIAL_OFF = !u_Enabled;

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

SG RoughnessLobe(float Roughness, vec3 Normal, vec3 Incident) {
	
	Roughness = max(Roughness, 0.001f);
	float a = Roughness * Roughness;
	float a2 = a * a;

	float NDotV = clamp(abs(dot(Incident, Normal)) + 0.00001f, 0.0f, 1.0f);
	vec3 SGAxis = 2.0f * NDotV * Normal - Incident;

	SG ReturnValue;
	ReturnValue.Axis = SGAxis;
	ReturnValue.Sharpness = 0.5f / (a2 * max(NDotV, 0.1f));
	ReturnValue.Amplitude = 1.0f / (PI * a2);

	return ReturnValue;
}

float GetLobeWeight(float CenterRoughness, float SampleRoughness, vec3 CenterNormal, vec3 SampleNormal, vec2 Transversals, const vec3 Incident) {
	
	const float Beta = 32.0f;

	float LobeSimilarity = 1.0f;
	float AxisSimilarity = 1.0f;

	SG CenterLobe = RoughnessLobe(CenterRoughness, CenterNormal, Incident); 
	SG SampleLobe = RoughnessLobe(SampleRoughness, SampleNormal, Incident); 

	float OneOverSharpnessSum = 1.0f / (CenterLobe.Sharpness + SampleLobe.Sharpness);

	LobeSimilarity = pow(2.0f * sqrt(CenterLobe.Sharpness * SampleLobe.Sharpness) * OneOverSharpnessSum, Beta);
	AxisSimilarity = exp(-(Beta * (CenterLobe.Sharpness * SampleLobe.Sharpness) * OneOverSharpnessSum) * clamp(1.0f - dot(CenterLobe.Axis, SampleLobe.Axis), 0.0f, 1.0f));

	return LobeSimilarity * AxisSimilarity;
}

float GetLobeWeight(in SG CenterLobe, float SampleRoughness, vec3 SampleNormal, const vec3 Incident) {
	
	const float Beta = 128.0f;

	float LobeSimilarity = 1.0f;
	float AxisSimilarity = 1.0f;

	SG SampleLobe = RoughnessLobe(SampleRoughness, SampleNormal, Incident);

	float OneOverSharpnessSum = 1.0f / (CenterLobe.Sharpness + SampleLobe.Sharpness);

	LobeSimilarity = pow(2.0f * sqrt(CenterLobe.Sharpness * SampleLobe.Sharpness) * OneOverSharpnessSum, Beta);
	AxisSimilarity = exp(-(Beta * (CenterLobe.Sharpness * SampleLobe.Sharpness) * OneOverSharpnessSum) * clamp(1.0f - dot(CenterLobe.Axis, SampleLobe.Axis), 0.0f, 1.0f));

	return LobeSimilarity * AxisSimilarity;
}

#define LARGE_VARIANCE_KERNEL

float GaussianVariance(ivec2 Pixel) {
	
	float VarianceSum = 0.0f;

	const float Wavelet[3] = float[3](1.0 / 4.0, 1.0 / 8.0, 1.0 / 16.0);
	const float Gaussian[2] = float[2](0.60283f, 0.198585f); 
	float TotalWeight = 0.0f;

	ivec2 SmallKernelOffsets[5] = ivec2[5](ivec2(0), ivec2(0,1), ivec2(0,-1), ivec2(1,0), ivec2(-1,0));

#ifdef LARGE_VARIANCE_KERNEL
	for (int x = -1 ; x <= 1 ; x++)
	{
		for (int y = -1 ; y <= 1 ; y++)
		{
			ivec2 SampleCoord = Pixel + ivec2(x,y);
			
			float KernelValue = Gaussian[abs(x)] * Gaussian[abs(y)];
			float V = texelFetch(u_Variance, SampleCoord, 0).r;

			VarianceSum += V * KernelValue;
			TotalWeight += KernelValue;
		}
	}
#else 
	for (int Sample = 0 ; Sample < 5 ; Sample++)
	{
		ivec2 S = SmallKernelOffsets[Sample];
		ivec2 SampleCoord = Pixel + ivec2(S.x,S.y);
			
		float KernelValue = Gaussian[abs(S.x)] * Gaussian[abs(S.y)];
		float V = texelFetch(u_Variance, SampleCoord, 0).r;

		VarianceSum += V * KernelValue;
		TotalWeight += KernelValue;
	}
#endif

	return VarianceSum / max(TotalWeight, 0.000000001f);
}

float GradientNoise()
{
	vec2 coord = gl_FragCoord.xy + mod(u_Time * 100.493850275f, 500.0f);
	float noise = fract(52.9829189f * fract(0.06711056f * coord.x + 0.00583715f * coord.y));
	return noise;
}

const float WaveletKernel[3] = float[3]( 1.0f, 2.0f / 3.0f, 1.0f / 6.0f );
const int Kernel = 1;

void main() {

	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	ivec2 Jitter = ivec2((GradientNoise() - 0.5f) * float(float(u_StepSize)/sqrt(2.0f)));

	int Frames = int(texelFetch(u_FrameCounters, Pixel, 0).x * 255.0f);

	vec4 Diffuse = texelFetch(u_Diffuse, Pixel, 0);
	vec4 Specular = texelFetch(u_Specular, Pixel, 0);
	vec4 Volumetrics = texelFetch(u_Volumetrics, Pixel, 0);
	vec4 CenterDiffuse = Diffuse;
	vec4 CenterSpec = Specular;
	vec4 CenterVol = Volumetrics;

	float Variance = texelFetch(u_Variance, Pixel, 0).x;

	if (SPATIAL_OFF) {
		o_Diffuse = Diffuse;
		o_Variance = Variance;
		o_Specular = Specular;
		o_Volumetrics = Volumetrics;
		return;
	}

	float DepthFetch = texelFetch(u_Depth, Pixel * 2, 0).x;
	float CenterDepth = LinearizeDepth(DepthFetch);
	vec3 CenterNormal = texelFetch(u_Normals, Pixel * 2, 0).xyz;
	vec3 CenterHFNormal = texelFetch(u_NormalsHF, Pixel * 2, 0).xyz;
	float CenterRoughness = texelFetch(u_PBR, Pixel * 2, 0).x;

	float CenterSTraversal = UntransformReflectionTransversal(CenterSpec.w);

	vec3 WorldPosition = WorldPosFromDepth(DepthFetch, v_TexCoords.xy).xyz;
	vec3 ViewPosition = vec3(u_View * vec4(WorldPosition, 1.0f));
	float PrimaryTransversal = length(ViewPosition);
	vec3 Incident = normalize(u_ViewerPosition - WorldPosition);

	float F = CenterSTraversal / (CenterSTraversal + PrimaryTransversal);
	float SpecularRadius = clamp(mix(0.7f * CenterRoughness, 1.0f, F), 0.0f, 1.0f);

	float CenterAO = Diffuse.w;
	float CenterDiffuseLuma = Luminance(Diffuse.xyz);
	float CenterSpecularLuma = Luminance(Specular.xyz);

	float VarianceGaussian = GaussianVariance(Pixel);
	 
	float TotalDiffuseWeight = 1.0f;
	float TotalSpecularWeight = 1.0f;
	float TotalVolWeight = 1.0f;
	float TotalAOWeight = 1.0f;

	ivec2 Size = ivec2(textureSize(u_Diffuse, 0).xy);

	const float PhiLMult = 5.3f; //0.0000001f;
	float FrameFactor = clamp(8.0f / float(Frames), 0.05f, 8.0f);
	float PhiLFrameFactor = 1.0f; //5.1f; //mix(6.5f,3.75f,clamp(float(Frames)/20.0f,0.0f,1.0f));
	float PhiL = PhiLMult * PhiLFrameFactor * sqrt(max(0.0f, 0.00000001f + VarianceGaussian));

	for (int x = -Kernel ; x <= Kernel ; x++) 
	{
		for (int y = -Kernel ; y <= Kernel ; y++) 
		{
			if (x == 0 && y == 0) { continue; }

			ivec2 SamplePixel = Pixel + ivec2(vec2(x,y) * u_StepSize) + Jitter;

			if (SamplePixel.x <= 1 || SamplePixel.x >= Size.x - 1 || SamplePixel.y <= 1 || SamplePixel.y >= Size.y - 1) {
				continue;
			}

			ivec2 HighResPixel = SamplePixel * 2;

			vec4 SampleDiffuse = texelFetch(u_Diffuse, SamplePixel, 0);
			vec4 SampleSpecular = texelFetch(u_Specular, SamplePixel, 0);
			float SampleVariance = texelFetch(u_Variance, SamplePixel, 0).x;
			float SampleDepth = LinearizeDepth(texelFetch(u_Depth, HighResPixel, 0).x);
            vec3 SampleNormals = texelFetch(u_Normals, HighResPixel, 0).xyz;
			vec3 SampleHFNormal = texelFetch(u_NormalsHF, HighResPixel, 0).xyz;
			float SampleRoughness = texelFetch(u_PBR, HighResPixel, 0).x;

			float SampleSTraversal = UntransformReflectionTransversal(SampleSpecular.w);

			float DepthWeight = clamp(pow(exp(-abs(SampleDepth - CenterDepth)*float(u_SqrtStepSize)), DEPTH_EXPONENT), 0.0f, 1.0f);
			float NormalWeight = clamp(pow(max(dot(SampleNormals, CenterNormal), 0.0f), NORMAL_EXPONENT), 0.0f, 1.0f);

			float LumaError = abs(CenterDiffuseLuma - Luminance(SampleDiffuse.xyz));
			float AOError = abs(CenterAO - SampleDiffuse.w);

			float SpecLumaError = abs(CenterSpecularLuma - Luminance(SampleSpecular.xyz));

			// Diffuse Weights
			float LumaWeight = pow(clamp(exp(-LumaError / (1.0f * PhiL + 0.0000001f)), 0.0f, 1.0f), 1.0f);
			float AOWeightDetail = pow(clamp(exp(-AOError / 0.155f), 0.0f, 1.0f), 1.0f);

			// Specular Weights 
			float SpecLumaWeight = pow((SpecLumaError)/(1.0f+SpecLumaError), pow((SpecularRadius)*0.1f, 1.0f/5.));
			float SpecLobeWeight = pow(GetLobeWeight(CenterRoughness, SampleRoughness, CenterHFNormal, SampleHFNormal, vec2(CenterSpec.w,SampleSpecular.w),Incident), 1.5f);

			// Wavelet 
			float KernelWeight = WaveletKernel[abs(x)] * WaveletKernel[abs(y)];

			float RawWeight = clamp(DepthWeight * NormalWeight * KernelWeight, 0.0f, 1.0f);
			float DiffuseWeight = clamp(RawWeight * LumaWeight, 0.0f, 1.0f);
			float SpecularWeight = clamp(DepthWeight * KernelWeight * pow(SpecLobeWeight, 1.0f), 0.0f, 1.0f);
			float AOWeight = clamp(DepthWeight * NormalWeight * KernelWeight * AOWeightDetail, 0.0f, 1.0f);

			Specular += SampleSpecular * SpecularWeight;
			TotalSpecularWeight += SpecularWeight;

			Diffuse.xyz += SampleDiffuse.xyz * DiffuseWeight;
			Diffuse.w += SampleDiffuse.w * AOWeight;
			Variance += SampleVariance * (DiffuseWeight * DiffuseWeight);

			TotalDiffuseWeight += DiffuseWeight;
			TotalAOWeight += AOWeight;

			if (u_FilterVolumetrics && false) {
				vec4 SampleVolumetrics = texelFetch(u_Volumetrics, SamplePixel, 0);
				float VolumetricsWeight = clamp(DepthWeight * NormalWeight, 0.0f, 1.0f); //RawWeight;
				Volumetrics += VolumetricsWeight * SampleVolumetrics;
				TotalVolWeight += VolumetricsWeight;
			}

		}
	}

	Volumetrics /= TotalVolWeight;
	Variance /= TotalDiffuseWeight * TotalDiffuseWeight;
	Diffuse.xyz /= TotalDiffuseWeight;
	Diffuse.w /= TotalAOWeight;

	Specular /= TotalSpecularWeight;
	Specular.w = CenterSpec.w; 

	o_Diffuse = Diffuse;
	o_Variance = Variance;
	o_Specular = Specular;
	o_Volumetrics = Volumetrics;
}