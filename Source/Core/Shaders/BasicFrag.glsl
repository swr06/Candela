#version 440 core

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;
in vec3 v_FragPosition;
in vec3 v_Normal;
in mat3 v_TBNMatrix;
in flat uint v_TexID;
in flat uint v_TexID2;
uniform vec4 u_Color;

uniform sampler2DArray u_AlbedoMap;
uniform sampler2DArray u_SpecularMap; 
uniform sampler2DArray u_NormalMap;
uniform sampler2DArray u_MetalnessMap;
uniform sampler2DArray u_RoughnessMap;
uniform sampler2DArray u_AOMap;

void main()
{
	uint AlbedoIDX = v_TexID & 0xFF;
	uint NormalIDX = (v_TexID >> 8) & 0xFF;
	o_Color = texture(u_AlbedoMap, vec3(v_TexCoords, float(AlbedoIDX))).xyz;
}
