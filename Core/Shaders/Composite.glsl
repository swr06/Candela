#version 330 core

#include "Include/Utility.glsl"

in vec2 v_TexCoords;
layout(location = 0) out vec3 o_Color;

uniform sampler2D u_MainTexture;

uniform sampler2D u_BloomMips[5];
uniform sampler2D u_BloomBrightTexture;

// ACES Tonemap operator 
mat3 ACESInputMat = mat3(
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
mat3 ACESOutputMat = mat3(
    1.60475, -0.10208, -0.00327,
    -0.53108, 1.10813, -0.07276,
    -0.07367, -0.00605, 1.07602
);

vec3 RRTAndODTFit(vec3 v)
{
    vec3 a = v * (v + 0.0245786f) - 0.000090537f;
    vec3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

vec4 ACESFitted(vec4 Color, float Exposure)
{
    Color.rgb *= Exposure;
    
    Color.rgb = ACESInputMat * Color.rgb;
    Color.rgb = RRTAndODTFit(Color.rgb);
    Color.rgb = ACESOutputMat * Color.rgb;

    return Color;
}

 vec3 UpscaleBloom(vec2 TexCoords) {
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
    vec3 Sample = texelFetch(u_MainTexture, Pixel, 0).xyz;

    o_Color = Sample + UpscaleBloom(v_TexCoords);
    o_Color.xyz = ACESFitted(vec4(o_Color.xyz, 1.0f), 0.8f).xyz;

    o_Color = clamp(o_Color, 0.0f, 1.0f);
}
