#version 430 core

#define EPSILON 0.01f

#include "Include/Utility.glsl"
#include "Include/Library/FSR.glsl"

layout (location = 0) out vec3 o_Color;

layout (std430, binding = 12) buffer CommonUniformData 
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

uniform sampler2D u_Texture; // <- Tonemapped input

uniform bool u_Enabled;

uniform float u_GrainStrength;

uniform float u_RenderScale;

uniform float u_DistortionK;
uniform bool u_DoDistortion;

// Hash
float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

float GetSat(vec3 x) { 
    return length(x); 
}

float CASWeight(vec3 x) {
    return clamp(Luminance(x), 0.0f, 1.0f);//min(max(x.g, EPSILON), 1.0f);
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


void FilmGrain(inout vec3 oc) 
{
    if (u_GrainStrength < 0.001f) {
        return;
    }

	float Strength = 0.08;
	vec3 NoiseColor = vec3(0.2001f, 0.804f, 1.02348f);
    vec3 Noise = vec3(hash2().xy, hash2().x);
    vec3 NoiseC = Noise * exp(-oc) * NoiseColor * 0.01f;
	oc += mix(clamp(NoiseC, 0.0f, 1.0f), vec3(0.0f), 1.0f - u_GrainStrength);
    oc *= mix(vec3(1.0f), Noise, u_GrainStrength * u_GrainStrength * exp(-oc));
}

// k should be -ve for barrel distortion and +ve for pincushion distortion
vec3 Distort(vec2 uv, float k) {

    if (!u_DoDistortion) {
        return vec3(v_TexCoords, 1.0f);
    }

    uv -= 0.5f;

    float ArcTanUV = atan(uv.x, uv.y);
    float DistanceFalloff = sqrt(dot(uv, uv));
    
    DistanceFalloff = DistanceFalloff * (1.0f + k * DistanceFalloff * DistanceFalloff);

    vec2 NewCoordinate = vec2(0.5f) + vec2(sin(ArcTanUV), cos(ArcTanUV)) * DistanceFalloff; // + 0.5 because it is subtracted at the start

    vec2 AbsNDC = abs(NewCoordinate * 2.0f - 1.0f);
    vec2 Border = 1.0f - smoothstep(vec2(0.9f), vec2(1.0f), AbsNDC);
    float Falloff = mix(0.1f, 1.0f, Border.x * Border.y);

    return vec3(NewCoordinate, Falloff);
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
    vec2 TexCoord = v_TexCoords;

    vec3 Distorted = Distort(v_TexCoords, clamp(u_DistortionK, -1.0f, 1.0f));
    TexCoord = Distorted.xy;

    //ivec2 Pixel = ivec2(gl_FragCoord.xy); 
    ivec2 Pixel = ivec2(TexCoord * textureSize(u_Texture, 0).xy);

    HASH2SEED = (v_TexCoords.x * v_TexCoords.y) * 489.0 * 20.0f;
	HASH2SEED += fract(u_Time) * 100.0f;

    vec3 OriginalColor = texelFetch(u_Texture, Pixel, 0).xyz;

    float SharpeningAmount = 0.49f;

    if (u_RenderScale < 0.8f) {
        SharpeningAmount += 0.1f;
    }

    if (u_RenderScale < 0.6f) {
        SharpeningAmount += 0.2f;
    }

    vec3 Processed = u_Enabled ? ContrastAdaptiveSharpening(u_Texture, Pixel, SharpeningAmount) : OriginalColor;
    //vec3 Processed = u_Enabled ? FSRCAS(u_Texture, Pixel, SharpeningAmount) : OriginalColor;

    o_Color = LinearToSRGB(Processed);
    o_Color = clamp(o_Color, 0.0f, 1.0f);
 
    o_Color *= Distorted.z;

    FilmGrain(o_Color);
	BasicColorDither(o_Color);

    o_Color = clamp(o_Color, 0.0f, 1.0f);
}
