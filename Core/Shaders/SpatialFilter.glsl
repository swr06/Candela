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
uniform sampler2D u_FrameCounters;
uniform float u_Time;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

float GaussianVariance(ivec2 Pixel) {
	
	float VarianceSum = 0.0f;

	const float Kernel[3] = float[3](1.0 / 4.0, 1.0 / 8.0, 1.0 / 16.0);
	const float Gaussian[2] = float[2](0.60283f, 0.198585f); // gaussian kernel
	float TotalKernel = 0.0f;

	for (int x = -1 ; x <= 1 ; x++)
	{
		for (int y = -1 ; y <= 1 ; y++)
		{
			ivec2 SampleCoord = Pixel + ivec2(x,y);
			
			float KernelValue = Gaussian[abs(x)] * Gaussian[abs(y)];
			float V = texelFetch(u_Variance, SampleCoord, 0).r;

			VarianceSum += V * KernelValue;
			TotalKernel += KernelValue;
		}
	}

	return VarianceSum / max(TotalKernel, 0.0000000000001f);
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
	ivec2 Jitter = ivec2((GradientNoise() - 0.5f) * float(float(u_StepSize)/4.));
	ivec2 HighResPixel = Pixel * 2;

	int Frames = int(texelFetch(u_FrameCounters, Pixel, 0).x * 255.0f);

	vec4 Diffuse = texelFetch(u_Diffuse, Pixel, 0);
	float CenterLuma = Luminance(Diffuse.xyz);
	float Variance = texelFetch(u_Variance, Pixel, 0).x;
	float CenterDepth = LinearizeDepth(texelFetch(u_Depth, Pixel * 2, 0).x);
	vec3 CenterNormal = texelFetch(u_Normals, Pixel * 2, 0).xyz;

	float VarianceGaussian = GaussianVariance(Pixel);
	float SqrtVar = sqrt(max(0.00000001f, VarianceGaussian));
	SqrtVar /= 1.0f;
	 
	float TotalWeight = 1.0f;

	ivec2 Size = ivec2(textureSize(u_Diffuse, 0).xy);

	float FrameFactor = clamp(8.0f / float(Frames), 0.05f, 8.0f);
	float PhiLFactor = exp(-pow(max(0.00000001f, VarianceGaussian), 1.0f / 3.0f) * 800.0f * mix(1.0f, 1.004f, FrameFactor));
	float PhiL = (SqrtVar / 1.0f); // * pow(FrameFactor, 1.0f / 4.0f); //PhiLFactor * mix(sqrt(VarianceGaussian), 1.0f, 0.9f);

	for (int x = -Kernel ; x <= Kernel ; x++) 
	{
		for (int y = -Kernel ; y <= Kernel ; y++) 
		{
			if (x == 0 && y == 0) { continue; }

			ivec2 SamplePixel = Pixel + (ivec2(x,y) * u_StepSize) + Jitter;

			if (SamplePixel.x < 0 || SamplePixel.x > Size.x || SamplePixel.y < 0 || SamplePixel.y > Size.y) {
					continue;
			}

			ivec2 HighResPixel = SamplePixel * 2;

			vec4 SampleDiffuse = texelFetch(u_Diffuse, SamplePixel, 0);
			float SampleVariance = texelFetch(u_Variance, SamplePixel, 0).x;
			float SampleDepth = LinearizeDepth(texelFetch(u_Depth, HighResPixel, 0).x);
            vec3 SampleNormals = texelFetch(u_Normals, HighResPixel, 0).xyz;

			float DepthWeight = clamp(pow(exp(-abs(SampleDepth - CenterDepth)), DEPTH_EXPONENT), 0.0f, 1.0f);
			float NormalWeight = clamp(pow(max(dot(SampleNormals, CenterNormal), 0.0f), NORMAL_EXPONENT), 0.0f, 1.0f);

			float LumaError = abs(CenterLuma - Luminance(SampleDiffuse.xyz));
			float LumaWeight = pow(clamp(exp(-LumaError / PhiL), 0.0f, 1.0f), 1.0f);

			float KernelWeight = WaveletKernel[abs(x)] * WaveletKernel[abs(y)];

			float Weight = clamp(DepthWeight * NormalWeight * KernelWeight * LumaWeight, 0.0f, 1.0f);

			Diffuse += SampleDiffuse * Weight;
			Variance += SampleVariance * (Weight * Weight);

			TotalWeight += Weight;
		}
	}

	Variance /= TotalWeight * TotalWeight;
	Diffuse /= TotalWeight;

	o_Diffuse = Diffuse;
	o_Variance = Variance;
}