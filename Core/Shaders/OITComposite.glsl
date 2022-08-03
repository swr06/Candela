#version 330 core 

layout (location = 0) out vec4 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_Blend;
uniform sampler2D u_Revealage;

uniform sampler2D u_OpaqueDepth;
uniform sampler2D u_TransparentDepth;

void main() {

	float OpaqueDepth = texture(u_OpaqueDepth, v_TexCoords).x;
	float TransparentDepth = texture(u_TransparentDepth, v_TexCoords).x;

	if (TransparentDepth > OpaqueDepth) {
		discard;
	}

	vec4 Blend = texture(u_Blend, v_TexCoords);
	vec3 Color = Blend.xyz / max(Blend.w, 0.00001f);
	float Alpha = 1.0f - texture(u_Revealage, v_TexCoords).x;
	o_Color = vec4(Color, Alpha);
}