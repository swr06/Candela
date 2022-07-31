#version 330 core

#include "Include/Utility.glsl"

in vec2 v_TexCoords;
layout(location = 0) out vec4 o_Color;

uniform sampler2D u_MainTexture;
uniform sampler2D u_Depth;

uniform sampler2D u_BloomMips[5];
uniform sampler2D u_BloomBrightTexture;

uniform float u_CAScale;

uniform bool u_BloomEnabled;

vec3 ChromaticAberation()
{
	const float ChannelCount = 3.0f;
	float AberationScale = mix(0.0f, 0.5f, u_CAScale);
	vec2 DistanceWeight = v_TexCoords - 0.5f;
    vec2 Aberrated = AberationScale * pow(DistanceWeight, vec2(3.0f, 3.0f));
    vec3 Final = vec3(0.0f);
	float TotalWeight = 0.01f;

    int Samples = 8;

	vec3 CenterSample = texture(u_MainTexture, v_TexCoords).xyz;
    
    for (int i = 1; i <= Samples; i++)
    {
        float wg = 1.0f / pow(2.0f, float(i));

		float x = 0.0f;

		if (v_TexCoords - float(i) * Aberrated == clamp(v_TexCoords - float(i) * Aberrated, 0.0001f, 0.9999f)) {
			Final.r += texture(u_MainTexture, v_TexCoords - float(i) * Aberrated).r * wg;
		}

		else {
			Final.r += CenterSample.x * wg;
		}

		if (v_TexCoords + float(i) * Aberrated == clamp(v_TexCoords + float(i) * Aberrated, 0.0001f, 0.9999f)) {
			Final.b += texture(u_MainTexture, v_TexCoords + float(i) * Aberrated).b * wg;
		}

		else {
			Final.b += CenterSample.y * wg;
		}

		TotalWeight += wg;

    }
    
	TotalWeight = 0.9961f; //(1.0 / pow(2.0f, float(i)) i = 1 -> 8 
	Final.g = texture(u_MainTexture, v_TexCoords).g;
	return max(Final,0.0f);
}


vec3 UpscaleBloom(vec2 TexCoords) {

	if (!u_BloomEnabled) {
		return vec3(0.0f);
	}

	vec3 UpscaledBloom = vec3(0.0f);
    vec3 BaseBrightTex = Bicubic(u_BloomBrightTexture, TexCoords).xyz;

	vec3 Bloom[5] = vec3[](vec3(0.0f), vec3(0.0f), vec3(0.0f), vec3(0.0f), vec3(0.0f));
	Bloom[0] += Bicubic(u_BloomMips[0], TexCoords).xyz;
	Bloom[1] += Bicubic(u_BloomMips[1], TexCoords).xyz; 
	Bloom[2] += Bicubic(u_BloomMips[2], TexCoords).xyz; 
	Bloom[3] += Bicubic(u_BloomMips[3], TexCoords).xyz; 
	Bloom[4] += Bicubic(u_BloomMips[4], TexCoords).xyz; 

    float Weights[5] = float[5](7.5f, 6.95f, 6.9f, 6.8f, 6.75f);
	const float DetailWeight = 10.2f;

	UpscaledBloom = (BaseBrightTex * DetailWeight * 1.0f) + UpscaledBloom;
	UpscaledBloom = (pow(Bloom[0], vec3(1.0f / 1.1f)) * Weights[0]) + UpscaledBloom;
	UpscaledBloom = (pow(Bloom[1], vec3(1.0f / 1.1f)) * Weights[1]) + UpscaledBloom;
	UpscaledBloom = (pow(Bloom[2], vec3(1.0f / 1.05f)) * Weights[2]) + UpscaledBloom;
	UpscaledBloom = (pow(Bloom[3], vec3(1.0f / 1.05f)) * Weights[3]) + UpscaledBloom;
	UpscaledBloom = (pow(Bloom[4], vec3(1.0f / 1.05f)) * Weights[4]) + UpscaledBloom;

	float TotalWeights = DetailWeight + Weights[0] + Weights[1] + Weights[2] + Weights[3] + Weights[4];
	UpscaledBloom /= TotalWeights;
    return UpscaledBloom * 0.8f;
}

void main()
{
    ivec2 Pixel = ivec2(gl_FragCoord.xy);
    vec3 Sample = u_CAScale > 0.000001f ? ChromaticAberation() : texelFetch(u_MainTexture, Pixel, 0).xyz;
	float Depth = texelFetch(u_Depth, Pixel, 0).x;

    o_Color.xyz = Sample + UpscaleBloom(v_TexCoords);
	o_Color.w = Depth; // <- DOF
}
