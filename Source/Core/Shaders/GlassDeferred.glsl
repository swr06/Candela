#version 450 core

#include "Include/Utility.glsl"

layout (location = 0) out vec4 o_Color;

uniform sampler2D u_AlbedoData;
uniform sampler2D u_NormalData;

uniform vec3 u_ViewerPosition;

uniform vec2 u_Dimensions;

uniform float u_zNear;
uniform float u_zFar;

uniform sampler2D u_RefractionData;
uniform sampler2D u_OpaqueLighting;

uniform sampler2D u_OpaqueDepth;
uniform sampler2D u_TransparentDepth;

in vec2 v_TexCoords;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

void main()
{
	float OpaqueDepth = texture(u_OpaqueDepth, v_TexCoords).x;
	float TransparentDepth = texture(u_TransparentDepth, v_TexCoords).x;

	if (TransparentDepth > OpaqueDepth || TransparentDepth > 0.9999f) {
		discard;
	}

	vec3 RefractionData = texture(u_RefractionData, v_TexCoords).xyz;

	vec3 Refracted = texture(u_OpaqueLighting, RefractionData.xy).xyz ;
	
	vec4 Normal = texture(u_NormalData, v_TexCoords);
	vec4 Albedo = texture(u_AlbedoData, v_TexCoords);

	float Z = LinearizeDepth(Normal.w);

	vec3 FinalColor = Refracted.xyz * mix(Albedo.xyz, vec3(1.0f), Albedo.w);

	o_Color = vec4(FinalColor, 1.);
}
