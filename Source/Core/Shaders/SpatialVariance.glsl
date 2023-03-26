#version 430 core 

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out float o_Variance;

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


uniform sampler2D u_Depth;
uniform sampler2D u_Normals;

uniform sampler2D u_Diffuse;
uniform sampler2D u_FrameCounters;

uniform sampler2D u_TemporalMoments;

uniform bool u_Enabled;

const bool SPATIAL_OFF = false;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

void main() {
	
	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	int Frames = max(int(texelFetch(u_FrameCounters, Pixel, 0).x * 255.0f), 1);

	vec4 Diffuse = texelFetch(u_Diffuse, Pixel, 0);
	vec4 CenterDiffuse = Diffuse;
	float VarianceBoost = 8.0f / max(float(Frames), 1.0f);

	if (Frames <= 8 && u_Enabled) {
		
		float CenterL = Luminance(Diffuse.xyz);

		float MaxL = -100.0f;
		vec2 Moments = vec2(0.0f); 
		
		// Calculate variance spatially 
		Moments = vec2(Luminance(Diffuse.xyz));
		Moments = vec2(Moments.x, Moments.x * Moments.x); 

		float CenterDepth = LinearizeDepth(texelFetch(u_Depth, Pixel * 2, 0).x);
		vec3 CenterNormal = texelFetch(u_Normals, Pixel * 2, 0).xyz;

		const float Atrous[3] = float[3]( 1.0f, 2.0f / 3.0f, 1.0f / 6.0f );
		float TotalWeight = 1.0f;
		float TotalAOWeight = 1.0f;
		int Kernel = 2;

		ivec2 Size = ivec2(textureSize(u_Diffuse, 0).xy);

		float PhiL = SPATIAL_OFF ? 0.0000001f : 30.0f; // <- Lower to get more detail

		for (int x = -Kernel ; x <= Kernel ; x++) {
			
			for (int y = -Kernel ; y <= Kernel ; y++) {
				
				if (x == 0 && y == 0) { continue; }

				ivec2 SamplePixel = Pixel + ivec2(x,y);

				if (SamplePixel.x <= 0 || SamplePixel.x >= Size.x - 1 || SamplePixel.y <= 0 || SamplePixel.y >= Size.y - 1) {
					continue;
				}

				ivec2 HighResPixel = SamplePixel * 2;

				vec4 SampleDiffuse = texelFetch(u_Diffuse, SamplePixel, 0);

				float SampleDepth = LinearizeDepth(texelFetch(u_Depth, HighResPixel, 0).x);
                vec3 SampleNormals = texelFetch(u_Normals, HighResPixel, 0).xyz;

				float DepthWeight = clamp(pow(exp(-abs(SampleDepth - CenterDepth)), DEPTH_EXPONENT), 0.0f, 1.0f);
				float NormalWeight = clamp(pow(max(dot(SampleNormals, CenterNormal), 0.0f), NORMAL_EXPONENT), 0.0f, 1.0f);
				float LumaWeight = clamp(exp(-abs(Luminance(SampleDiffuse.xyz)-CenterL)/PhiL),0.0,1.0f);
				float KernelWeight = Atrous[abs(x)] * Atrous[abs(y)];

				float AOError = abs(CenterDiffuse.w - SampleDiffuse.w);
				float AOWeightDetail = pow(clamp(exp(-AOError / 0.015f), 0.0f, 1.0f), 1.0f);

				float Weight = clamp(DepthWeight * NormalWeight * LumaWeight, 0.0f, 1.0f);
				float AOWeight = clamp(DepthWeight * NormalWeight, 0.0f, 1.0f); 

				Diffuse.xyz += SampleDiffuse.xyz * Weight;
				Diffuse.w += SampleDiffuse.w * AOWeight;

				vec2 CurrentMoments = vec2(Luminance(SampleDiffuse.xyz));
				CurrentMoments = vec2(CurrentMoments.x, CurrentMoments.x * CurrentMoments.x);
				MaxL = max(CurrentMoments.x, MaxL);

				Moments += CurrentMoments * Weight;
				TotalWeight += Weight;
				TotalAOWeight += AOWeight;
			}

		}

		Moments /= TotalWeight;
		Diffuse.xyz /= TotalWeight;
		Diffuse.w /= TotalAOWeight;

		o_Variance = abs(Moments.y - Moments.x * Moments.x) * 5.0f;
	}

	else {
		
		vec2 TemporalMoments = texelFetch(u_TemporalMoments, Pixel, 0).xy;
		o_Variance = abs(TemporalMoments.y - TemporalMoments.x * TemporalMoments.x);
	}

	o_Variance *= VarianceBoost;

	o_Diffuse = Diffuse;

}


