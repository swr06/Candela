#version 330 core 

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out float o_Utility;
layout (location = 2) out vec2 o_Moments;

in vec2 v_TexCoords;

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_PrevProjection;
uniform mat4 u_PrevView;
uniform mat4 u_PrevInverseProjection;
uniform mat4 u_PrevInverseView;

uniform sampler2D u_DiffuseCurrent;
uniform sampler2D u_DiffuseHistory;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;

uniform sampler2D u_PreviousDepth;
uniform sampler2D u_PreviousNormals;

uniform sampler2D u_MotionVectors;
uniform sampler2D u_Utility;

uniform sampler2D u_MomentsHistory;

uniform float u_zNear;
uniform float u_zFar;

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

void main() {

	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	ivec2 HighResPixel = Pixel * 2;
	ivec2 Dimensions = textureSize(u_DiffuseHistory,0).xy;

	float Depth = texelFetch(u_Depth, HighResPixel, 0).x;
	vec3 Normals = texelFetch(u_Normals, HighResPixel, 0).xyz;

	float LinearDepth = LinearizeDepth(Depth);
	vec2 DepthGradient = vec2(dFdx(LinearDepth), dFdy(LinearDepth));

	vec3 WorldPosition = WorldPosFromDepth(Depth, v_TexCoords).xyz;

	vec2 MotionVector = texelFetch(u_MotionVectors, HighResPixel, 0).xy;

	vec2 Reprojected = MotionVector + v_TexCoords;

	vec4 Current = texelFetch(u_DiffuseCurrent, Pixel, 0);

	float L = Luminance(Current.xyz);

	vec2 Moments;
	Moments = vec2(L, L * L);

	float Frames = 1.0f;

	o_Diffuse = Current;
	o_Moments = max(Moments, 0.0f);

	if (IsInScreenspace(Reprojected)) 
	{
		ivec2 ReprojectedPixel = ivec2(Reprojected.xy * vec2(Dimensions));
		float ReprojectedDepth = texture(u_PreviousDepth, Reprojected.xy).x;

		vec3 ReprojectedPosition = PrevWorldPosFromDepth(ReprojectedDepth, Reprojected.xy);
		
		float DistanceRelaxFactor = abs(length(DepthGradient)) * 50.0f;
		float Error = distance(ReprojectedPosition, WorldPosition); // exp(-distance(ReprojectedPosition, WorldPosition) / DistanceRelaxFactor);

		float BlendFactor = 0.0f;

		float MotionLength = length(MotionVector);

		float Tolerance = MotionLength <= 0.000001f ? 32.0f : (MotionLength > 0.001f ? 1.0f : 3.0f);

		if (Error < Tolerance)
		{
			Frames = min((texelFetch(u_Utility, ReprojectedPixel.xy, 0).x * 255.0f), 128.0f) + 1.0f;
			BlendFactor = 1.0f - (1.0f / Frames);

			vec4 History = CatmullRom(u_DiffuseHistory, Reprojected.xy);
			o_Diffuse.xyz = mix(Current.xyz, History.xyz, BlendFactor);

			vec2 HistoryMoments = texture(u_MomentsHistory, Reprojected.xy).xy;
			o_Moments = mix(Moments, HistoryMoments, BlendFactor);

			if (Error < Tolerance * 0.8f) {
				float MotionWeight = MotionLength > 0.001f ? clamp(exp(-length(MotionVector * vec2(Dimensions))) * 0.6f + 0.75f, 0.0f, 1.0f) : 1.0f;
				o_Diffuse.w = mix(Current.w, History.w, min(BlendFactor * MotionWeight, 0.93f));
			}
		}

	}

	
	o_Utility = Frames / 255.0f;
}