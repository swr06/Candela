#version 440 core

layout (location = 0) out vec4 o_Albedo;
layout (location = 1) out vec4 o_HFNormal;
layout (location = 2) out vec4 o_PBR;
layout (location = 3) out vec4 o_LFNormal;
layout (location = 4) out int o_EntityNumber;

uniform sampler2D u_AlbedoMap;
uniform sampler2D u_NormalMap;
uniform sampler2D u_MetalnessMap;
uniform sampler2D u_RoughnessMap;
uniform sampler2D u_MetalnessRoughnessMap;

uniform bool u_UsesGLTFPBR;
uniform bool u_UsesNormalMap;
uniform bool u_UsesRoughnessMap;
uniform bool u_UsesMetalnessMap;
uniform float u_ModelEmission;

uniform vec3 u_EmissiveColor;
uniform bool u_UsesAlbedoTexture;
uniform vec3 u_ModelColor;

uniform float u_EntityRoughness;
uniform float u_EntityMetalness;
uniform float u_EmissivityAmount;

uniform vec3 u_ViewerPosition;

uniform int u_EntityNumber;

in vec2 v_TexCoords;
in vec3 v_FragPosition;
in vec3 v_Normal;
in mat3 v_TBNMatrix;


void main()
{
	vec3 Incident = normalize(v_FragPosition - u_ViewerPosition);

	const bool Whiteworld = false;

	const float LODBias = -1.0f;

	o_Albedo.xyz = Whiteworld ? vec3(1.0f) : (u_UsesAlbedoTexture ? texture(u_AlbedoMap, v_TexCoords, LODBias).xyz : u_ModelColor);

	//o_Albedo += o_Albedo * u_EmissiveColor * u_ModelEmission * 8.0f;

	vec3 LFN = normalize(v_Normal);

	vec3 HQN = u_UsesNormalMap ? normalize(v_TBNMatrix * (texture(u_NormalMap, v_TexCoords).xyz * 2.0f - 1.0f)) : LFN;

	if (dot(LFN, Incident) > 0.0001f) {
		LFN = -LFN;
	}

	if (dot(HQN, Incident) > 0.0001f) {
		HQN = -HQN;
	}
	
	o_HFNormal.xyz = HQN;
	o_LFNormal.xyz = LFN;

	// https://www.khronos.org/blog/art-pipeline-for-gltf

	if (u_UsesGLTFPBR) {
		//o_PBR.xyz = vec3(texture(u_MetalnessRoughnessMap, v_TexCoords).yx, 1.0f);
		vec4 mapfetch = texture(u_MetalnessRoughnessMap, v_TexCoords);
		o_PBR.xyz = vec3(mapfetch.yz, mapfetch.x);
	}

	else {

		o_PBR.xyz = vec3(u_UsesRoughnessMap ? texture(u_RoughnessMap, v_TexCoords).r : u_EntityRoughness, 
						u_UsesMetalnessMap ? texture(u_MetalnessMap, v_TexCoords).r : u_EntityMetalness, 
						0.0f);

	}

	o_PBR.x = clamp(o_PBR.x, 0.000001f, 1.0f);

	o_PBR.w = u_ModelEmission;

	o_LFNormal.w = u_EmissivityAmount;

	o_EntityNumber = u_EntityNumber + 2;
}
