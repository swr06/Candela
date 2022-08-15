#version 430 core

layout (location = 0) in vec3 a_Position;

uniform mat4 u_ModelMatrix;
uniform mat4 u_ViewProjection;

void main()
{
	gl_Position = u_ModelMatrix * vec4(a_Position, 1.0f);
	gl_Position = u_ViewProjection * gl_Position;
}