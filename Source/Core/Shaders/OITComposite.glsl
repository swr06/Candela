#version 430 core 

layout (location = 0) out vec4 o_Color;

layout (std430, binding = 12) restrict buffer CommonUniformData 
{
	float u_Time;
	int u_Frame;
	int u_CurrentFrame;

	mat4 u_ViewProjection;
	mat4 u_Projection;
	mat4 u_View;
	mat4 u_InverseProjection;
	mat4 u_InverseView;
	mat4 u_PrevProjection;
	mat4 u_PrevView;
	mat4 u_PrevInverseProjection;
	mat4 u_PrevInverseView;
	mat4 u_InversePrevProjection;
	mat4 u_InversePrevView;

	vec3 u_ViewerPosition;
	vec3 u_Incident;
	vec3 u_SunDirection;
	vec3 u_LightDirection;

	float u_zNear;
	float u_zFar;
};

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