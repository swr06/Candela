#version 450 core 

#define PI 3.141592653

#include "TraverseBVH.glsl"
#include "Include/SphericalHarmonics.glsl"
#include "Include/Utility.glsl"
#include "Include/Sampling.glsl"

layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba16f, binding = 0) uniform image2D o_OutputData;

uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_InverseProjection;
uniform mat4 u_InverseView;
uniform mat4 u_ViewProjection;

uniform vec2 u_Dims;
uniform vec3 u_SunDirection;

uniform sampler2D u_DepthTexture;
uniform sampler2D u_NormalTexture;

uniform int u_Frame;
uniform float u_Time;

uniform float u_zNear;
uniform float u_zFar;

uniform bool u_Checker;

vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

const bool DO_SECOND_BOUNCE = true;
const bool RT_SECOND_BOUNCE = false;
const bool DO_SCREENTRACE = true;

void main() {

	ivec2 Pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 WritePixel = ivec2(gl_GlobalInvocationID.xy);

	if (Pixel.x < 0 || Pixel.y < 0 || Pixel.x > int(u_Dims.x) || Pixel.y > int(u_Dims.y)) {
		return;
	}

	// Handle checkerboard 
	if (u_Checker) {
		Pixel.x *= 2;
		bool IsCheckerStep = Pixel.x % 2 == int(Pixel.y % 2 == (u_Frame % 2));
		Pixel.x += int(IsCheckerStep);
	}

	// 1/2 res on each axis
    ivec2 HighResPixel = Pixel * 2;
    vec2 HighResUV = vec2(HighResPixel) / textureSize(u_DepthTexture, 0).xy;

	// Fetch 
    float Depth = texelFetch(u_DepthTexture, HighResPixel, 0).x;

	if (Depth > 0.999999f || Depth == 1.0f) {
		imageStore(o_OutputData, WritePixel, vec4(0.0f));
        return;
    }

	vec2 TexCoords = HighResUV;
	HASH2SEED = (TexCoords.x * TexCoords.y) * 64.0 * u_Time;

	const vec3 Player = u_InverseView[3].xyz;

	vec3 WorldPosition = WorldPosFromDepth(Depth, TexCoords);
	vec3 Normal = normalize(texelFetch(u_NormalTexture, HighResPixel, 0).xyz);

	vec3 EyeVector = normalize(WorldPosition - Player);
	vec3 Reflected = reflect(EyeVector, Normal);

	vec3 RayOrigin = WorldPosition + Normal * 0.05f;
	vec3 RayDirection = CosWeightedHemisphere(Normal, hash2());

	imageStore(o_OutputData, WritePixel, vec4(RayDirection, 1.0f));
}
