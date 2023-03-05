#version 450 core

#include "Include/Utility.glsl"

layout (location = 0) out vec4 o_Blend;
layout (location = 1) out float o_Revealage;

uniform sampler2D u_AlbedoMap;
uniform sampler2D u_NormalMap;

uniform bool u_UsesNormalMap;

uniform vec3 u_EmissiveColor;
uniform bool u_UsesAlbedoTexture;
uniform vec3 u_ModelColor;

uniform float u_Transparency;

uniform vec3 u_ViewerPosition;

uniform int u_EntityNumber;
uniform vec2 u_Dimensions;

uniform float u_zNear;
uniform float u_zFar;

uniform sampler2D u_RefractionData;
uniform sampler2D u_OpaqueLighting;


in vec2 v_TexCoords;
in vec3 v_FragPosition;
in vec3 v_Normal;
in mat3 v_TBNMatrix;

vec3 CreateNormalMap(in vec3 Albedo, vec2 Size) {
	float L = pow(Luminance(Albedo), 4.0f);
	return vec3(-vec2(dFdxFine(L), dFdxFine(L)), 1.0f);
}

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

void main()
{
	const float LODBias = -1.0f;
	const bool GenerateNormals = false;

	vec2 ScreenspaceUV = vec2(gl_FragCoord.xy) / u_Dimensions;

	//vec3 RefractionData = texture(u_RefractionData, ScreenspaceUV).xyz;
	//vec3 Refracted = texture(u_OpaqueLighting, RefractionData.xy).xyz;
	//
	vec3 Incident = normalize(v_FragPosition - u_ViewerPosition);

	vec3 AlbedoColor = (u_UsesAlbedoTexture ? texture(u_AlbedoMap, v_TexCoords, LODBias).xyz : u_ModelColor);

	vec3 LFN = normalize(v_Normal);

	vec3 HQN = u_UsesNormalMap ? normalize(v_TBNMatrix * (texture(u_NormalMap, v_TexCoords).xyz * 2.0f - 1.0f)) : LFN;

	if (dot(LFN, Incident) > 0.0001f) {
		LFN = -LFN;
	}

	if (dot(HQN, Incident) > 0.0001f) {
		HQN = -HQN;
	}

	float Z = LinearizeDepth(gl_FragCoord.z);

	vec3 Color = AlbedoColor;
	
	float Alpha = clamp((1.0f - u_Transparency), 0.0f, 1.0f);

	float InversePers = abs(1.0f / max(gl_FragCoord.w, 0.0000000001f));
	float Factor = 1.0 / 200.0f; 
	float ZFactor = Factor * InversePers;
    float Weight = clamp((0.03 / (1e-5 + pow(ZFactor, 4.0))), 1e-4, 3e3);

	//float a = 58.3765228;
    //float b = 1.45434782;
    //float c = 0.00630901288;
    //float fz = a * exp(-b * InversePers) + c;
    //float Weight = clamp(fz, 1e-2, 3e3);

	//float Weight = max(min(1.0, max(max(Color.r, Color.g), Color.b) * Alpha), Alpha) * clamp(0.03 / (1e-5 + pow(Z / 192.0f, 4.0)), 1e-2, 3e3);

	//float Weight = clamp(pow(min(1.0, Alpha * 10.0) + 0.01, 3.0) * 1e8 * pow(1.0 - gl_FragCoord.z * 0.9, 3.0), 1e-2, 3e3);


	o_Blend = vec4(Color.xyz * Alpha, Alpha) * Weight;
	o_Revealage = Alpha;

}
