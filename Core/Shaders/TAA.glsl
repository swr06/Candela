#version 400 core

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

const float PI = 3.1415926f;

layout (location = 0) out vec4 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_CurrentColorTexture;
uniform sampler2D u_DepthTexture;
uniform sampler2D u_PreviousColorTexture;
uniform sampler2D u_PreviousDepthTexture;
uniform sampler2D u_MotionVectors;

uniform vec2 u_CurrentJitter;
uniform bool u_TAAU;
uniform float u_TAAUConfidenceExponent;

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_PrevProjection;
uniform mat4 u_PrevView;
uniform mat4 u_PrevInverseProjection;
uniform mat4 u_PrevInverseView;

uniform float u_zNear;
uniform float u_zFar;


uniform vec3 u_ViewerPosition;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

vec3 PrevWorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_PrevInverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_PrevInverseView * ViewSpacePosition;
    return WorldPos.xyz;
}


vec3 Reprojection(vec3 WorldPos) 
{
	vec4 ProjectedPosition = u_PrevProjection * u_PrevView * vec4(WorldPos, 1.0f);
	ProjectedPosition.xyz /= ProjectedPosition.w;
	ProjectedPosition.xyz = ProjectedPosition.xyz * 0.5f + 0.5f;
	return ProjectedPosition.xyz;
}

vec3 Tonemap(vec3 x) {
    return Reinhard(x);
}

vec3 InverseTonemap(vec3 x) {
    return InverseReinhard(x);
}

void GatherStatistics(sampler2D Texture, ivec2 Pixel, in vec4 Center, out vec4 Min, out vec4 Max, out vec4 Mean, out vec4 Moments) {
	
	Min = vec4(10000.0f);
	Max = vec4(-10000.0f);
	Mean = vec4(0.0f);
	float TotalWeight = 1.0f;

	for (int x = -1 ; x <= 1 ; x++) {
		
		for (int y = -1 ; y <= 1 ; y++) {
			
			vec4 Fetch = (x == 0 && y == 0) ? Center : texelFetch(Texture, Pixel + ivec2(x, y), 0);
			Fetch.xyz = Tonemap(Fetch.xyz);
			Min = min(Min, Fetch);
			Max = max(Max, Fetch);
			Mean += Fetch;
			Moments += Fetch * Fetch;
			TotalWeight += 1.0f;
		}

	}

	Mean /= TotalWeight;
	Moments /= TotalWeight;
}

ivec2 GetNearestFragment(ivec2 Pixel, out float ClosestDepth) {
    
    ivec2 Kernel[5] = ivec2[5](ivec2(0,0), ivec2(1,0), ivec2(-1,0), ivec2(0,1), ivec2(0,-1));

    ivec2 BestTexel = ivec2(Pixel);

    float BestDepth = 100000.0f;

    for (int x = 0 ; x < 5 ; x++) {

        ivec2 SampleTexel = Pixel + Kernel[x];

        float Depth = texelFetch(u_DepthTexture, SampleTexel, 0).x;

        if (Depth < BestDepth) {
            BestTexel = SampleTexel;
            BestDepth = Depth;
        }
    }

    return BestTexel;
}

bool ENABLED = true;

void main() {
    
    ivec2 Pixel = ivec2(gl_FragCoord.xy);

    vec2 Dimensions = textureSize(u_CurrentColorTexture, 0).xy;

	float Depth = texelFetch(u_DepthTexture, Pixel, 0).x;
    
    vec4 Current = texelFetch(u_CurrentColorTexture, Pixel, 0).xyzw;
    //vec4 Current = CatmullRom(u_CurrentColorTexture, v_TexCoords).xyzw;

    o_Color = vec4(Current.xyz, 1.0f);

    if (Depth == 1.0f || !ENABLED) {
        return;
    }

    float ClosestDepth;
    ivec2 ClosestDepthPixel = GetNearestFragment(Pixel, ClosestDepth);

	float LinearDepth = LinearizeDepth(Depth);
	vec2 DepthGradient = vec2(dFdx(LinearDepth), dFdy(LinearDepth));

	vec3 WorldPosition = WorldPosFromDepth(Depth, v_TexCoords).xyz;

	vec2 MotionVector = texelFetch(u_MotionVectors, ClosestDepthPixel, 0).xy;
	float MotionLength = length(MotionVector);

    vec2 Reprojected = MotionVector + v_TexCoords;

    if (IsInScreenspaceBiased(Reprojected)) {

        vec4 Min, Max, Mean, Moments;
        GatherStatistics(u_CurrentColorTexture, Pixel, Current, Min, Max, Mean, Moments);
        
        vec4 History = CatmullRom(u_PreviousColorTexture, Reprojected.xy);

        float Frames = (History.w) + 1.0f;

        Current.xyz = Tonemap(Current.xyz);
        History.xyz = Tonemap(History.xyz);

        float Bias = MotionLength > 0.00008f ? 0.0f : 0.01f;

        History.xyz = ClipToAABB(History.xyz, Min.xyz - Bias, Max.xyz + Bias);

        float BlendFactor = exp(-length((MotionVector * Dimensions))) * 0.9f + 0.7f;

        float FrameBlend = 1.0f - clamp(1.0f / Frames, 0.0f, 1.0f);

        float TemporalBlur = BlendFactor;

        o_Color.xyz = InverseTonemap(mix(Current.xyz, History.xyz, clamp(TemporalBlur, 0.0f, 0.97f)));
        o_Color.w = (Frames * BlendFactor);
    }

    if (!IsValid(o_Color)) {
        o_Color = vec4(0.0f);
    }

}