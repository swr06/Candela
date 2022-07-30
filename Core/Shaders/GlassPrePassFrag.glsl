#version 450 core

#include "Include/Utility.glsl"

layout (location = 0) out vec4 o_Data;

uniform sampler2D u_NormalMap;

uniform float u_GlassFactor;

uniform vec3 u_ViewerPosition;

uniform int u_EntityNumber;
uniform vec2 u_Dimensions;

uniform bool u_UsesNormalMap;

in vec2 v_TexCoords;
in vec3 v_FragPosition;
in vec3 v_Normal;
in mat3 v_TBNMatrix;

void main()
{
	const float LODBias = -1.0f;
	const bool Whiteworld = false;

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
	
	float Depth = gl_FragDepth;
	o_Data = vec4(HQN, Depth);
}
