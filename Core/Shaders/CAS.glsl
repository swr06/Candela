#version 330 core

#define EPSILON 0.01f

#include "Include/Utility.glsl"

layout (location = 0) out vec3 o_Color;

uniform sampler2D u_Texture; // <- Tonemapped input

uniform bool u_Enabled;

float GetSat(vec3 x) { 
    return length(x); 
}

float CASWeight(vec3 x) {
    return max(x.g, EPSILON);
}

vec3 ContrastAdaptiveSharpening(sampler2D Texture, ivec2 Pixel, float SharpeningAmount)
{
    // Samples 
    vec3 a = texelFetch(Texture, Pixel + ivec2(0, -1), 0).rgb;
    vec3 b = texelFetch(Texture, Pixel + ivec2(-1, 0), 0).rgb;
    vec3 c = texelFetch(Texture, Pixel + ivec2(0, 0), 0).rgb;
    vec3 d = texelFetch(Texture, Pixel + ivec2(1, 0), 0).rgb;
    vec3 e = texelFetch(Texture, Pixel + ivec2(0, 1), 0).rgb;

    // Weight by luminance 
    float WeightA = CASWeight(a.xyz);
    float WeightB = CASWeight(b.xyz);
    float WeightC = CASWeight(c.xyz);
    float WeightD = CASWeight(d.xyz);
    float WeightE = CASWeight(e.xyz);

    // Calculate bounds :
    float MinWeighter = min(WeightA, min(WeightB, min(WeightC, min(WeightD, WeightE))));
    float MaxWeighter = max(WeightA, max(WeightB, max(WeightC, max(WeightD, WeightE))));

    // Apply weights :
    float FinalSharpenAmount = sqrt(min(1.0f - MaxWeighter, MinWeighter) / MaxWeighter);
    float w = FinalSharpenAmount * mix(-0.125f, -0.2f, SharpeningAmount);
    return (w * (a + b + d + e) + c) / (4.0f * w + 1.0f);
}

void BasicColorDither(inout vec3 color)
{
	const vec2 LestynCoefficients = vec2(171.0f, 231.0f);
    vec3 Lestyn = vec3(dot(LestynCoefficients, gl_FragCoord.xy));
    Lestyn = fract(Lestyn.rgb / vec3(103.0f, 71.0f, 97.0f));
    color += Lestyn.rgb / 255.0f;
}

void main() 
{
    ivec2 Pixel = ivec2(gl_FragCoord.xy);
    vec3 OriginalColor = texelFetch(u_Texture, Pixel, 0).xyz;

    float SharpeningAmount = 0.425f;
    vec3 Processed = u_Enabled ? ContrastAdaptiveSharpening(u_Texture, Pixel, SharpeningAmount) : OriginalColor;
    
    o_Color = LinearToSRGB(Processed);
    o_Color = clamp(o_Color, 0.0f, 1.0f);
	BasicColorDither(o_Color);
}
