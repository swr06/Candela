#version 430 core

layout (location = 0) in vec3 a_Position;
layout (location = 1) in uvec3 a_NormalTangentData;
layout (location = 2) in uint a_TexCoords;

uniform mat4 u_ModelMatrix;
uniform mat3 u_NormalMatrix;

out mat3 v_TBNMatrix;
out vec2 v_TexCoords;
out vec3 v_FragPosition;
out vec3 v_Normal;

uniform mat4 u_ViewProjection;

void main()
{
	gl_Position = u_ModelMatrix * vec4(a_Position, 1.0f);
	v_FragPosition = gl_Position.xyz;
	gl_Position = u_ViewProjection * gl_Position;
	v_TexCoords = unpackHalf2x16(a_TexCoords);
	vec2 Data_0 = unpackHalf2x16(a_NormalTangentData.x);
	vec2 Data_1 = unpackHalf2x16(a_NormalTangentData.y);
	vec2 Data_2 = unpackHalf2x16(a_NormalTangentData.z);
	vec3 Normal = vec3(Data_0.x, Data_0.y, Data_1.x);
	vec3 Tangent = vec3(Data_1.y, Data_2.x, Data_2.y);

	v_Normal = mat3(u_NormalMatrix) * Normal;  

	vec3 T = (vec3(u_ModelMatrix * vec4(Tangent, 0.0)));
	vec3 N = (vec3(u_ModelMatrix * vec4(Normal, 0.0)));
	vec3 B = (vec3(u_ModelMatrix * vec4(cross(N, T), 0.0)));
	v_TBNMatrix = mat3(T, B, N);
}