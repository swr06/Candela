#version 440 core

layout (location = 0) out vec4 o_AlbedoRoughness;
layout (location = 1) out float o_Depth;
layout (location = 2) out vec4 o_NormalMetalness;

uniform sampler2D u_AlbedoMap;
uniform sampler2D u_NormalMap;
uniform sampler2D u_MetalnessMap;
uniform sampler2D u_RoughnessMap;
uniform sampler2D u_MetalnessRoughnessMap;

uniform bool u_UsesGLTFPBR;

in vec2 v_TexCoords;
in vec3 v_FragPosition;
in vec3 v_Normal;
in mat3 v_TBNMatrix;

// Remember!
uniform vec3 u_CapturePosition;

void main()
{
	vec3 Albedo, Normal, PBR;
	Albedo = texture(u_AlbedoMap, v_TexCoords).xyz;
	Normal = v_TBNMatrix * (texture(u_NormalMap, v_TexCoords).xyz * 2.0f - 1.0f);

	if (u_UsesGLTFPBR) {
		PBR = vec3(texture(u_MetalnessRoughnessMap, v_TexCoords).yx, 1.0f);
	}

	else {

		PBR = vec3(texture(u_RoughnessMap, v_TexCoords).r, 
						texture(u_MetalnessMap, v_TexCoords).r, 
						1.0f);
	}

	o_AlbedoRoughness.xyz = Albedo;
	o_AlbedoRoughness.w = PBR.x;

	float Depth = length(v_FragPosition - u_CapturePosition);
	Depth /= 128.0f;
	o_Depth = Depth;

	o_NormalMetalness = vec4(Normal, PBR.y);

}
