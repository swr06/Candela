#version 430 core

#include "Include/Utility.glsl"
#include "FXAA311.glsl"

in vec2 v_TexCoords;
layout(location = 0) out vec4 o_Color;

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

uniform sampler2D u_MainTexture;
uniform sampler2D u_Depth;

uniform sampler2D u_BlueNoise; 

uniform bool u_FXAAEnabled;
uniform float u_FXAAAmt;

uniform vec2 u_SunScreenPosition;

uniform float u_PlayerShadow;

uniform sampler2D u_BloomMips[5];
uniform sampler2D u_BloomBrightTexture;

uniform float u_CAScale;

uniform bool u_BloomEnabled;

uniform float u_LensFlareStrength;

uniform float u_InternalRenderResolution;

// Noise functions 
float Fnoise(float t)
{
	return texture(u_BlueNoise, vec2(t, 0.0f) / vec2(256).xy).x;
}

float Fnoise(vec2 t)
{
	return texture(u_BlueNoise, t / vec2(256).xy).x;
}

// Credits : mu6k
vec3 LensFlare(vec2 uv, vec2 pos)
{
	vec2 main = uv - pos;
	vec2 uvd = uv * (length(uv));
	float ang = atan(main.x,main.y);
	float dist = length(main); 
	dist = pow(dist, 0.1f);
	float n = Fnoise(vec2(ang * 16.0f, dist * 32.0f));
	float f0 = 1.0 / (length(uv - pos) * 16.0f + 1.0f);
	f0 = f0 + f0 * (sin(Fnoise(sin(ang * 2.0f + pos.x) * 4.0f - cos(ang * 3.0f + pos.y)) * 16.0f) * 0.1 + dist * 0.1f + 0.8f);
	float f1 = max(0.01f - pow(length(uv + 1.2f * pos), 1.9f), 0.0f) * 7.0f;
	float f2 = max(1.0f / (1.0f + 32.0f * pow(length(uvd + 0.8f * pos), 2.0f)), 0.0f) * 0.25f;
	float f22 = max(1.0f / (1.0f + 32.0f * pow(length(uvd + 0.85f * pos), 2.0f)), 0.0f) * 0.23f;
	float f23 = max(1.0f / (1.0f + 32.0f * pow(length(uvd + 0.9f * pos), 2.0f)), 0.0f) * 0.21f;
	vec2 uvx = mix(uv, uvd, -0.5f);
	float f4 = max(0.01f - pow(length(uvx + 0.4f * pos), 2.4f), 0.0f) * 6.0f;
	float f42 = max(0.01f - pow(length(uvx + 0.45f * pos), 2.4f), 0.0f) * 5.0f;
	float f43 = max(0.01f - pow(length(uvx + 0.5f *pos), 2.4f), 0.0f) * 3.0f;
	uvx = mix(uv, uvd, -0.4f);
	float f5 = max(0.01f - pow(length(uvx + 0.2f * pos), 5.5f), 0.0f) * 2.0f;
	float f52 = max(0.01f - pow(length(uvx + 0.4f * pos), 5.5f), 0.0f) * 2.0f;
	float f53 = max(0.01f - pow(length(uvx + 0.6f * pos), 5.5f), 0.0f) * 2.0f;
	uvx = mix(uv, uvd, -0.5f);
	float f6 = max(0.01f - pow(length(uvx - 0.3f * pos), 1.6f), 0.0f) * 6.0f;
	float f62 = max(0.01f - pow(length(uvx - 0.325f * pos), 1.6f), 0.0f) * 3.0f;
	float f63 = max(0.01f - pow(length(uvx - 0.35f * pos), 1.6f), 0.0f) * 5.0f;
	vec3 c = vec3(0.0f);
	c.r += f2 + f4 + f5 + f6; 
	c.g += f22 + f42 + f52 + f62;
	c.b += f23 + f43 + f53 + f63;
	c = c * 1.3f - vec3(length(uvd) * 0.05f);
	return c;
}


vec3 ChromaticAberation()
{
	const float ChannelCount = 3.0f;
	float AberationScale = mix(0.0f, 0.5f, u_CAScale);
	vec2 DistanceWeight = v_TexCoords - 0.5f;
    vec2 Aberrated = AberationScale * pow(DistanceWeight, vec2(3.0f, 3.0f));
    vec3 Final = vec3(0.0f);
	float TotalWeight = 0.01f;

    int Samples = 7;

	//vec3 FXAA311(sampler2D tex, vec2 texCoord, float scale_, vec3 color)
	vec3 CenterSampleA = texture(u_MainTexture, v_TexCoords).xyz;
	vec3 CenterSample = u_FXAAEnabled ? FXAA311(u_MainTexture, v_TexCoords, u_InternalRenderResolution, CenterSampleA, u_FXAAAmt) : CenterSampleA;
    
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
	Final.g = CenterSample.g;
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
	
    vec3 Sample = u_CAScale > 0.000001f ? ChromaticAberation() : 
				(u_FXAAEnabled ? FXAA311(u_MainTexture, v_TexCoords, u_InternalRenderResolution, texelFetch(u_MainTexture, Pixel, 0).xyz, u_FXAAAmt) : texelFetch(u_MainTexture, Pixel, 0).xyz);
	float Depth = texelFetch(u_Depth, ivec2(u_InternalRenderResolution * vec2(Pixel)), 0).x;
	vec2 Dims = textureSize(u_Depth, 0);

	vec2 AspectCorrectCoord = v_TexCoords - 0.5f;
	AspectCorrectCoord.x *= Dims.x / Dims.y;
	vec3 Flare = u_LensFlareStrength > 0.001f ? vec3(1.6f, 1.2f, 1.0f) * u_LensFlareStrength * clamp(LensFlare(AspectCorrectCoord, u_SunScreenPosition), 0.0f, 1.0f) * 1.0f * u_PlayerShadow : vec3(0.0f);
    o_Color.xyz = Sample.xyz + UpscaleBloom(v_TexCoords) + Flare;
	o_Color.w = Depth; // <- DOF
}
