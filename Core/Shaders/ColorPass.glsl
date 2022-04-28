#version 430 core
#define PI 3.14159265359

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_AlbedoTexture;
uniform sampler2D u_NormalTexture;
uniform sampler2D u_PBRTexture;
uniform sampler2D u_DepthTexture;
uniform sampler2D u_ShadowTexture;
uniform sampler2D u_BlueNoise;
uniform samplerCube u_Skymap;

uniform vec3 u_ViewerPosition;
uniform vec3 u_LightDirection;
uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_LightVP;
uniform vec2 u_Dims;

uniform bool u_Mode;



struct FlattenedNode {
	vec4 Min;
	vec4 Max;
	uint StartIdx;
	uint TriangleCount;
	uint Axis;
	uint Padding0;
};

struct Triangle {
	vec4 Position[3];
};

layout (std430, binding = 1) buffer SSBO_BVHTriangles {
	Triangle BVHTriangles[];
};

layout (std430, binding = 2) buffer SSBO_BVHNodes {
	FlattenedNode BVHNodes[];
};







vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

vec3 GetRayDirectionAt(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}

void main() 
{	
	float depth = texture(u_DepthTexture, v_TexCoords).r;
	vec3 rD = GetRayDirectionAt(v_TexCoords).xyz;

	if (depth > 0.99995f) {
		vec3 Sample = texture(u_Skymap, normalize(rD)).xyz;
		o_Color = Sample*Sample;
		return;
	}

	vec3 NormalizedSunDir = normalize(u_LightDirection);

	vec3 WorldPosition = WorldPosFromDepth(depth,v_TexCoords);
	vec3 Normal = normalize(texture(u_NormalTexture, v_TexCoords).xyz);
	vec3 Albedo = texture(u_AlbedoTexture, v_TexCoords).xyz;
	vec2 RoughnessMetalness = texture(u_PBRTexture, v_TexCoords).xy;

	vec3 AmbientTerm = (texture(u_Skymap, vec3(0.0f, 1.0f, 0.0f)).xyz * 0.225f) * Albedo;
	o_Color = AmbientTerm; //DirectLighting + AmbientTerm;//Reflected * 0.6f;// DirectLighting + AmbientTerm;
}

