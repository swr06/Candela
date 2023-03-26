#version 430 core

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"
#include "Include/Library/FSR.glsl"

const float PI = 3.1415926f;

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

uniform sampler2D u_CurrentColorTexture;
uniform sampler2D u_DepthTexture;
uniform sampler2D u_PreviousColorTexture;
uniform sampler2D u_PreviousDepthTexture;
uniform sampler2D u_MotionVectors;

uniform vec2 u_CurrentJitter;
uniform bool u_TAAU;
uniform float u_TAAUConfidenceExponent;

uniform float u_InternalRenderResolution;

uniform bool u_Enabled;
uniform bool u_FSRU;

float ScaleMultiplier = 1.0f;

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
			
			vec4 Fetch = (x == 0 && y == 0) ? Center : texelFetch(Texture, ivec2((Pixel + ivec2(x, y))), 0);
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

        ivec2 SampleTexel = ivec2((Pixel + Kernel[x]) * ScaleMultiplier);

        float Depth = texelFetch(u_DepthTexture, SampleTexel, 0).x;

        if (Depth < BestDepth) {
            BestTexel = SampleTexel;
            BestDepth = Depth;
        }
    }

    return BestTexel;
}

bool ENABLED = u_Enabled;

void main() {
    
    ivec2 Pixel = ivec2(gl_FragCoord.xy);

    ScaleMultiplier = u_InternalRenderResolution;

    vec2 Dimensions = textureSize(u_CurrentColorTexture, 0).xy;

    vec2 FullDimensions = Dimensions / u_InternalRenderResolution;

	float Depth = texelFetch(u_DepthTexture, ivec2(Pixel * ScaleMultiplier), 0).x;
    
    vec4 Current;

    if (!ENABLED) {
        o_Color = texelFetch(u_CurrentColorTexture, ivec2(Pixel * ScaleMultiplier), 0).xyzw;
        return;
    }
    
    // 1x 
    if (abs(u_InternalRenderResolution - 1.0f) < 0.001f) {
        Current = texelFetch(u_CurrentColorTexture, ivec2(Pixel * ScaleMultiplier), 0).xyzw;
    }

    else {


        if (u_FSRU) {
            Current = vec4(FSRUpscaleEASU(u_CurrentColorTexture, Pixel, FullDimensions), 1.0f);
        }

        else {
            Current = CatmullRom(u_CurrentColorTexture, v_TexCoords);
        }


    }

    o_Color = vec4(Current.xyz, 1.0f);

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
        GatherStatistics(u_CurrentColorTexture, ivec2(Pixel * ScaleMultiplier), Current, Min, Max, Mean, Moments);
        
        vec2 Offset = 1.0 - abs(2.0 * fract(textureSize(u_CurrentColorTexture,0) * (Reprojected + u_CurrentJitter / textureSize(u_CurrentColorTexture,0)) ) - 1.0);
	    float JitteredBlend = sqrt(Offset.x * Offset.y) * 0.25f + (1.0 - 0.25f);
        JitteredBlend = pow(JitteredBlend, 2.0f);

        vec4 History = CatmullRom(u_PreviousColorTexture, Reprojected.xy);

        float Frames = (History.w) + 1.0f;

        Current.xyz = Tonemap(Current.xyz);
        History.xyz = Tonemap(History.xyz);

        float Bias = MotionLength > 0.00008f ? 0.0f : 0.003f;

        History.xyz = ClipToAABB(History.xyz, Min.xyz - Bias, Max.xyz + Bias);

        //float BlendFactor = clamp(exp(-length(MotionVector * FullDimensions) * 0.5f) + 0.5f, 0.0f, 1.0f);
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