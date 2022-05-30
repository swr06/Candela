#version 330 core 

layout (location = 0) out vec4 o_Diffuse;

in vec2 v_TexCoords;

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_PrevProjection;
uniform mat4 u_PrevView;

uniform sampler2D u_DiffuseCurrent;
uniform sampler2D u_DiffuseHistory;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;

vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

vec3 Reprojection(vec3 WorldPos) 
{
	vec4 ProjectedPosition = u_PrevProjection * u_PrevView * vec4(WorldPos, 1.0f);
	ProjectedPosition.xyz /= ProjectedPosition.w;
	ProjectedPosition.xyz = ProjectedPosition.xyz * 0.5f + 0.5f;
	return ProjectedPosition.xyz;

}

void main() {

	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	ivec2 HighResPixel = Pixel * 2;

	float Depth = texelFetch(u_Depth, HighResPixel, 0).x;
	vec3 Normals = texelFetch(u_Normals, HighResPixel, 0).xyz;

	vec3 WorldPosition = WorldPosFromDepth(Depth, v_TexCoords).xyz;

	vec3 Reprojected = Reprojection(WorldPosition);

	vec4 Current = texelFetch(u_DiffuseCurrent, Pixel, 0);

	o_Diffuse = Current;

	if (Reprojected.xy == clamp(Reprojected.xy, 0.01f, 0.99f)) 
	{
		ivec2 ReprojectedPixel = ivec2(Reprojected.xy * textureSize(u_DiffuseHistory,0).xy);
		vec4 History = texelFetch(u_DiffuseHistory, ReprojectedPixel,0);
		o_Diffuse = mix(Current, History, 0.95f);
	}

}