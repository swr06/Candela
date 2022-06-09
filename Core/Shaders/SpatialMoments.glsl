#version 330 core 

#include "Include/Utility.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out float o_Variance;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;

uniform sampler2D u_Diffuse;
uniform sampler2D u_FrameCounters;

uniform sampler2D u_TemporalMoments;

uniform float u_zNear;
uniform float u_zFar;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

void main() {
	
	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	int Frames = int(texelFetch(u_FrameCounters, Pixel, 0).x * 255.0f);

	vec4 Diffuse = texelFetch(u_Diffuse, Pixel, 0);
	vec2 Moments = vec2(0.0f); 

	if (Frames < 4) {
		
		// Calculate variance spatially 
		Moments = vec2(Luminance(Diffuse.xyz));
		Moments = vec2(Moments.x, Moments.x * Moments.x); 

		float CenterDepth = LinearizeDepth(texelFetch(u_Depth, Pixel, 0).x);
		vec3 CenterNormal = texelFetch(u_Normals, Pixel, 0).xyz;

		const float Atrous[3] = float[3]( 1.0f, 2.0f / 3.0f, 1.0f / 6.0f );
		float TotalWeight = 1.0f;
		int Kernel = 1;

		for (int x = -Kernel ; x <= Kernel ; x++) {
			
			for (int y = -Kernel ; y <= Kernel ; y++) {
				
				if (x == 0 && y == 0) { continue; }

				ivec2 SamplePixel = Pixel + ivec2(x,y);

				vec4 SampleDiffuse = texelFetch(u_Diffuse, SamplePixel, 0);

				float SampleDepth = LinearizeDepth(texelFetch(u_Depth, SamplePixel, 0).x);
                vec3 SampleNormals = texelFetch(u_Normals, SamplePixel, 0).xyz;

				float DepthWeight = clamp(pow(exp(-abs(SampleDepth - CenterDepth)), 2.0f), 0.0f, 1.0f);
				float NormalWeight = clamp(pow(max(dot(SampleNormals, CenterNormal), 0.0f), 8.0f), 0.0f, 1.0f);
				float KernelWeight = Atrous[abs(x)] * Atrous[abs(y)];

				float Weight = clamp(DepthWeight * NormalWeight * KernelWeight, 0.0f, 1.0f);

				Diffuse += SampleDiffuse * Weight;

				vec2 CurrentMoments = vec2(Luminance(SampleDiffuse.xyz));
				CurrentMoments = vec2(CurrentMoments.x, CurrentMoments.x * CurrentMoments.x);

				Moments += CurrentMoments * Weight;
				TotalWeight += Weight;
			}

		}

		Moments /= TotalWeight;
		Diffuse /= TotalWeight;
	}

	else {
		
		vec2 TemporalMoments = texelFetch(u_TemporalMoments, Pixel, 0).xy;
		Moments = TemporalMoments;
	}

	o_Diffuse = Diffuse;
	o_Variance = Moments.y - (Moments.x * Moments.x);
}


