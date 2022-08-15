#version 330 core

layout (location = 0) in vec2 a_Position;
layout (location = 1) in vec2 a_TexCoords;

out vec2 v_TexCoords;

void main()
{
	gl_Position = vec4(a_Position, 0.0f, 1.0f);
	v_TexCoords = a_TexCoords;
}