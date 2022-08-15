#version 330 core

layout (location = 0) out vec4 o_Color;

uniform sampler2D u_Input;

in vec2 v_TexCoords;

void main() {

	o_Color = texture(u_Input, v_TexCoords).xyzw;
}