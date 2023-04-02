#version 450 core

#include "Include/Utility.glsl"

layout (location = 0) out vec4 o_Data;
layout (location = 1) out vec4 o_Albedo;

uniform sampler2D u_AlbedoMap;

uniform bool u_UsesAlbedoTexture;
uniform vec3 u_ModelColor;

uniform sampler2D u_NormalMap;

uniform float u_GlassFactor;

uniform bool u_Stochastic;

uniform int u_Frame;

uniform vec3 u_ViewerPosition;

uniform int u_EntityNumber;
uniform vec2 u_Dimensions;

uniform bool u_UsesNormalMap;
uniform float u_Time;

in vec2 v_TexCoords;
in vec3 v_FragPosition;
in vec3 v_Normal;
in mat3 v_TBNMatrix;

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

void main()
{
	const float LODBias = -1.0f;
	const bool Whiteworld = false;

	vec2 TexCoords = vec2(gl_FragCoord.xy) / u_Dimensions;
	HASH2SEED = u_Time;
	HASH2SEED *= (TexCoords.x * TexCoords.y) * 64.0;

	if (u_Stochastic) {
		// white noise 
		//float Hash = hash2().x;

		// bayer hash
		float Hash = fract(fract(mod(float(u_Frame) + float((0 * 3) + 0) * 2., 384.0f) * (1.0 / 1.6180339)) + bayer32(gl_FragCoord.xy));

		// 3D permute 
		//float Hash = snoise(vec4(v_FragPosition * 150.0f + u_Time, 1.0f));

		if (Hash < u_GlassFactor) {
			discard;
		}
	}

	vec3 Incident = normalize(v_FragPosition - u_ViewerPosition);

	vec3 LFN = normalize(v_Normal);

	vec3 HQN = u_UsesNormalMap ? normalize(v_TBNMatrix * (texture(u_NormalMap, v_TexCoords).xyz * 2.0f - 1.0f)) 
			 : (LFN);

	if (dot(LFN, Incident) > 0.0001f) {
		LFN = -LFN;
	}

	if (dot(HQN, Incident) > 0.0001f) {
		HQN = -HQN;
	}
	
	o_Data = vec4(HQN.xyz, float(u_EntityNumber + 2));
	o_Albedo = vec4(u_UsesAlbedoTexture ? texture(u_AlbedoMap, v_TexCoords).xyz : u_ModelColor, u_GlassFactor);
}
