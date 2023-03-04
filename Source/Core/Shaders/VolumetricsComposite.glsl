#version 330 core 

layout (location = 0) out vec3 o_Color;

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