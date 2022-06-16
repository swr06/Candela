#version 330 core 

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out float o_Variance;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;

uniform sampler2D u_Diffuse;
uniform sampler2D u_Variance;

uniform float u_zNear;
uniform float u_zFar;

uniform int u_StepSize;
uniform float u_SqrtStepSize;
uniform sampler2D u_FrameCounters;
uniform float u_Time;

uniform int u_Pass;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
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
	ivec2 HighResPixel = Pixel * 2;

	int Frames = int(texelFetch(u_FrameCounters, Pixel, 0).x * 255.0f);

	vec4 Diffuse = texelFetch(u_Diffuse, Pixel, 0);
	vec4 CenterDiffuse = Diffuse;
	float Variance = texelFetch(u_Variance, Pixel, 0).x;

	if (false) {
		o_Diffuse = Diffuse;
		o_Variance = Variance;
		return;
	}

	float CenterAO = Diffuse.w;
	float CenterLuma = Luminance(Diffuse.xyz);
	float CenterDepth = LinearizeDepth(texelFetch(u_Depth, Pixel * 2, 0).x);
	vec3 CenterNormal = texelFetch(u_Normals, Pixel * 2, 0).xyz;

	float VarianceGaussian = GaussianVariance(Pixel);
	 
	float TotalWeight = 1.0f;
	float TotalAOWeight = 1.0f;

	ivec2 Size = ivec2(textureSize(u_Diffuse, 0).xy);

	const float PhiLMult = 1.0f; //0.0000001f;
	float FrameFactor = clamp(8.0f / float(Frames), 0.05f, 8.0f);
	//float DepthFactor = mix(4.0f, 15.0f, clamp(pow(abs(CenterDepth) / 15.0f, 1.0f),0.0f,1.0f));
	float PhiLFrameFactor = 6.25f; //mix(6.5f,3.75f,clamp(float(Frames)/20.0f,0.0f,1.0f));
	float PhiL = PhiLMult * PhiLFrameFactor * sqrt(max(0.0f, 0.00000001f + VarianceGaussian));

	for (int x = -Kernel ; x <= Kernel ; x++) 
	{
		for (int y = -Kernel ; y <= Kernel ; y++) 
		{
			if (x == 0 && y == 0) { continue; }

			ivec2 SamplePixel = Pixel + (ivec2(x,y) * u_StepSize) + Jitter;

			if (SamplePixel.x <= 0 || SamplePixel.x >= Size.x - 1 || SamplePixel.y <= 0 || SamplePixel.y >= Size.y - 1) {
					continue;
			}

			ivec2 HighResPixel = SamplePixel * 2;

			vec4 SampleDiffuse = texelFetch(u_Diffuse, SamplePixel, 0);
			float SampleVariance = texelFetch(u_Variance, SamplePixel, 0).x;
			float SampleDepth = LinearizeDepth(texelFetch(u_Depth, HighResPixel, 0).x);
            vec3 SampleNormals = texelFetch(u_Normals, HighResPixel, 0).xyz;

			float DepthWeight = clamp(pow(exp(-abs(SampleDepth - CenterDepth)*float(u_SqrtStepSize)), DEPTH_EXPONENT), 0.0f, 1.0f);
			float NormalWeight = clamp(pow(max(dot(SampleNormals, CenterNormal), 0.0f), NORMAL_EXPONENT), 0.0f, 1.0f);

			float LumaError = abs(CenterLuma - Luminance(SampleDiffuse.xyz));
			float AOError = abs(CenterAO - SampleDiffuse.w);

			float LumaWeight = pow(clamp(exp(-LumaError / (1.0f * PhiL + 0.0000001f)), 0.0f, 1.0f), 1.0f);
			float AOWeightDetail = pow(clamp(exp(-AOError / 0.075f), 0.0f, 1.0f), 1.0f);

			float KernelWeight = WaveletKernel[abs(x)] * WaveletKernel[abs(y)];

			float RawWeight = clamp(DepthWeight * NormalWeight * KernelWeight, 0.0f, 1.0f);
			float Weight = clamp(RawWeight * LumaWeight, 0.0f, 1.0f);
			float AOWeight = clamp(DepthWeight * NormalWeight * KernelWeight * AOWeightDetail, 0.0f, 1.0f);

			Diffuse.xyz += SampleDiffuse.xyz * Weight;
			Diffuse.w += SampleDiffuse.w * AOWeight;
			Variance += SampleVariance * (Weight * Weight);

			TotalWeight += Weight;
			TotalAOWeight += AOWeight;
		}
	}

	Variance /= TotalWeight * TotalWeight;
	Diffuse.xyz /= TotalWeight;
	Diffuse.w /= TotalAOWeight;

	o_Diffuse = Diffuse;
	o_Variance = Variance;
}