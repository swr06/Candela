#version 330 core

layout (location = 0) in vec2 a_Position;
layout (location = 1) in vec2 a_TexCoords;

out vec2 v_TexCoords;
out float v_FocusDepth;

uniform sampler2D u_DepthTexture;
uniform vec2 u_FocusPoint;

uniform float u_zVNear;
uniform float u_zVFar;

void main()
{
	gl_Position = vec4(a_Position, 0.0f, 1.0f);
	v_TexCoords = a_TexCoords;

	float Depth = texture(u_DepthTexture, u_FocusPoint).x;

	v_FocusDepth = (2.0 * u_zVNear) / (u_zVFar + u_zVNear - Depth * (u_zVFar - u_zVNear));
}