#version 330 core 

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out vec2 o_Utility;
layout (location = 2) out vec2 o_Moments;
layout (location = 3) out vec4 o_Specular;

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

uniform sampler2D u_SpecularCurrent;
uniform sampler2D u_SpecularHistory;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;

uniform sampler2D u_PreviousDepth;
uniform sampler2D u_PreviousNormals;

uniform sampler2D u_MotionVectors;
uniform sampler2D u_Utility;

uniform sampler2D u_MomentsHistory;

uniform sampler2D u_PBR;

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

void GatherMinMax(ivec2 Pixel, out vec4 Min, out vec4 Max, out vec4 Mean, out vec4 Moments) {
	
	Min = vec4(10000.0f);
	Max = vec4(-10000.0f);
	Mean = vec4(0.0f);
	float TotalWeight = 1.0f;

	for (int x = -1 ; x <= 1 ; x++) {
		
		for (int y = -1 ; y <= 1 ; y++) {
			
			vec4 Fetch = texelFetch(u_SpecularCurrent, Pixel + ivec2(x, y), 0);
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

void main() {

	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	ivec2 HighResPixel = Pixel * 2;
	ivec2 Dimensions = textureSize(u_DiffuseHistory,0).xy;

	float Depth = texelFetch(u_Depth, HighResPixel, 0).x;
	vec3 Normals = texelFetch(u_Normals, HighResPixel, 0).xyz;
	vec3 PBR = texelFetch(u_PBR, HighResPixel, 0).xyz;

	float LinearDepth = LinearizeDepth(Depth);
	vec2 DepthGradient = vec2(dFdx(LinearDepth), dFdy(LinearDepth));

	vec3 WorldPosition = WorldPosFromDepth(Depth, v_TexCoords).xyz;

	vec2 MotionVector = texelFetch(u_MotionVectors, HighResPixel, 0).xy;
	float MotionLength = length(MotionVector);

	vec2 Reprojected = MotionVector + v_TexCoords;

	vec4 Current = texelFetch(u_DiffuseCurrent, Pixel, 0);

	float L = Luminance(Current.xyz);

	vec2 Moments;
	Moments = vec2(L, L * L);

	float DiffuseFrames = 1.0f;

	o_Diffuse = Current;
	o_Moments = max(Moments, 0.0f);

	bool DisocclusionSurface = true;

	if (IsInScreenspaceBiased(Reprojected)) 
	{
		ivec2 ReprojectedPixel = ivec2(Reprojected.xy * vec2(Dimensions));
		float ReprojectedDepth = texture(u_PreviousDepth, Reprojected.xy).x;

		vec3 ReprojectedPosition = PrevWorldPosFromDepth(ReprojectedDepth, Reprojected.xy);
		
		float DistanceRelaxFactor = abs(length(DepthGradient)) * 50.0f;
		float Error = distance(ReprojectedPosition, WorldPosition); // exp(-distance(ReprojectedPosition, WorldPosition) / DistanceRelaxFactor);

		float BlendFactor = 0.0f;


		float Tolerance = MotionLength <= 0.000001f ? 32.0f : (MotionLength > 0.001f ? 1.0f : 3.0f);

		if (Error < Tolerance)
		{
			DisocclusionSurface = false;

			DiffuseFrames = min((texelFetch(u_Utility, ReprojectedPixel.xy, 0).x * 255.0f), 128.0f) + 1.0f;
			BlendFactor = 1.0f - (1.0f / DiffuseFrames);

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

	vec4 CurrentSpecular = texelFetch(u_SpecularCurrent, Pixel, 0);
	o_Specular = CurrentSpecular;

	float SpecularFrames = 1.0f;

	if (!DisocclusionSurface)
	{
		vec4 MinSpec, MaxSpec, MeanSpec, MomentsSpec;

		GatherMinMax(Pixel, MinSpec, MaxSpec, MeanSpec, MomentsSpec);

		vec4 Variance = sqrt(abs(MomentsSpec - MeanSpec * MeanSpec));
		float Transversal = UntransformReflectionTransversal(MeanSpec.w);

		if (Transversal < 0.0f) {
			Transversal = 10.0f;
		}

		vec3 Incident = normalize(u_ViewerPosition - WorldPosition.xyz);
		vec3 ReflectedPosition = (WorldPosition.xyz) - Incident * Transversal;
		vec3 ReprojectedReflection = Reprojection(ReflectedPosition).xyz;

		if (IsInScreenspaceBiased(ReprojectedReflection.xy)) {
			vec4 HistorySpecular = CatmullRom(u_SpecularHistory, ReprojectedReflection.xy);

			float ClipStrength = max(mix(1.0f, 6.0f, pow(PBR.x,1.5f)) * (MotionLength > 0.0001f ? 0.4f : 5.0f), 1.0f);
			HistorySpecular.xyz = ClipToAABB(HistorySpecular.xyz, MeanSpec.xyz - Variance.xyz * ClipStrength, MeanSpec.xyz + Variance.xyz * ClipStrength);

			float TransversalError = abs(HistorySpecular.w - Transversal);

			SpecularFrames = min((texture(u_Utility,ReprojectedReflection.xy).y * 255.0f), 20.0f) + 1.0f;
			float SpecBlendFactor = 1.0f - (1.0f / SpecularFrames);

			if (true)
			{
				o_Specular.xyz = InverseReinhard(mix(Reinhard(CurrentSpecular.xyz), Reinhard(HistorySpecular.xyz), SpecBlendFactor));
				o_Specular.w = mix(Transversal, HistorySpecular.w, SpecBlendFactor);
			}
		}

		if (!IsValid(o_Specular)) {
			o_Specular = vec4(0.0f);
		}
	}
	
	o_Utility.x = DiffuseFrames / 255.0f;
	o_Utility.y = SpecularFrames / 255.0f;
}