#version 430 core 

layout (location = 0) out vec3 o_Color;

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

uniform sampler2D u_Lighting;
uniform sampler2D u_Volumetrics;

uniform bool u_VolumetricsEnabled;

uniform float u_InternalRenderResolution;

void main() {
	
	ivec2 Pixel = ivec2(gl_FragCoord.xy);

	vec4 Lighting = texelFetch(u_Lighting, Pixel, 0);

	o_Color = Lighting.xyz;

	if (u_VolumetricsEnabled) {
		vec4 Volumetrics = texture(u_Volumetrics, v_TexCoords);
		o_Color = o_Color.xyz * Volumetrics.w + Volumetrics.xyz;
	}
}