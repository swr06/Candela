#version 330 core 

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out vec4 o_Specular;
layout (location = 2) out vec4 o_Volumetrics;

layout (std430, binding = 12) buffer CommonUniformData 
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

uniform sampler2D u_Depth;
uniform sampler2D u_PreviousDepth;
uniform sampler2D u_Normals;
uniform sampler2D u_PreviousNormals;
uniform sampler2D u_CurrentFrameTexture;
uniform sampler2D u_PreviousFrameTexture;

uniform sampler2D u_CurrentFrameSpecular;
uniform sampler2D u_PreviousFrameSpecular;

uniform sampler2D u_CurrentFrameVolumetrics;
uniform sampler2D u_PreviousFrameVolumetrics;

uniform sampler2D u_MotionVectors;

uniform vec2 u_Dimensions;

uniform bool u_Enabled;

const ivec2 UpscaleOffsets[4] = ivec2[](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1));

float CDEPTH_EXP = 256.0f;
float CNORMAL_EXP = 16.0f;

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

float DistanceSquared(vec3 A, vec3 B)
{
    return dot(A-B, A-B);
}

float linearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

vec3 SearchBestPixel(vec3 WorldPosition, vec2 Reprojected) {
	
	vec2 InverseDimensions = 1.0f / u_Dimensions;
    Reprojected *= u_Dimensions;
    Reprojected = floor(Reprojected) + 0.5;

	ivec2 Pixel = ivec2(Reprojected);

	vec4 BestWorldPos = vec4(vec3(-1.), 1000000.0f);
	ivec2 BestPixel = ivec2(-1);

	int Kernel = 1;

	for (int x = -Kernel ; x <= Kernel ; x++) {

		for (int y = -Kernel ; y <= Kernel ; y++) {
			
			ivec2 SamplePixel = (Pixel + ivec2(x, y));
			ivec2 SampleHighResPixel = SamplePixel * 2;
			float SampleDepth = texelFetch(u_PreviousDepth, SampleHighResPixel, 0).x;

			if (IsSky(SampleDepth)) {
				continue;
			}

			vec3 PrevWorldPos = PrevWorldPosFromDepth(SampleDepth, vec2(SampleHighResPixel) / textureSize(u_PreviousDepth,0).xy);

			if (DistanceSquared(PrevWorldPos, WorldPosition) < BestWorldPos.w) {
				BestWorldPos = vec4(PrevWorldPos,DistanceSquared(PrevWorldPos, WorldPosition)); 
				BestPixel = ivec2(x,y);
			}
		}

	}

	return vec3(vec2(Pixel+BestPixel),BestWorldPos.w);
}

void main() {
	
	bool OutputRaw = !u_Enabled;

	if (OutputRaw) {
		
		o_Diffuse = texelFetch(u_CurrentFrameTexture, ivec2(gl_FragCoord.xy), 0);
		o_Specular = texelFetch(u_CurrentFrameSpecular, ivec2(gl_FragCoord.xy), 0);
		o_Volumetrics = texelFetch(u_CurrentFrameVolumetrics, ivec2(gl_FragCoord.xy), 0);
		return;
	}

	
	ivec2 Pixel = ivec2(gl_FragCoord.xy);

	ivec2 HighResPixel = Pixel * 2;

	bool IsCheckerStep = Pixel.x % 2 == int(Pixel.y % 2 == (u_Frame % 2));

	if (IsCheckerStep) {

		bool SpatialUpscaleAll = false;
		bool SpatialUpscaleSpecVol = false;

		bool TryTemporalResample = true;
		
		if (TryTemporalResample) {

			ivec2 ReprojectedPixel = ivec2(Pixel.x/2, Pixel.y);
			ivec2 PixelXHalved = ReprojectedPixel;
			
			float Error = 0.0f;

			float Depth = texelFetch(u_Depth, HighResPixel, 0).x;

			vec2 MotionVector = texelFetch(u_MotionVectors, HighResPixel, 0).xy;

			float MotionLength = length(MotionVector);

			if (MotionLength > 0.0015f)
			{
				vec3 WorldPosition = WorldPosFromDepth(Depth, v_TexCoords).xyz;
				vec2 Reprojected = v_TexCoords; // Using the motion vector makes it look worse.. somehow.
				vec3 Search = SearchBestPixel(WorldPosition, Reprojected.xy);

				ReprojectedPixel.xy = ivec2(Search.xy); 
				ReprojectedPixel.x /= 2;

				Error = sqrt(Search.z);
			}

			if (Error >= 2.4f) {
				// Couldn't resolve pixel temporally, spatially upscale.
				SpatialUpscaleAll = true;
			}

			else {
				o_Diffuse = texelFetch(u_PreviousFrameTexture, ivec2(ReprojectedPixel.x,ReprojectedPixel.y), 0).xyzw;
			}

			if (MotionLength > 0.0001f) {
				SpatialUpscaleSpecVol = true; // <- Spatially resolve specular and volumetrics if motion vector changed, we cant reliably reproject it for the checkerboard 
			}

			else {
				o_Specular = texelFetch(u_PreviousFrameSpecular, ivec2(PixelXHalved), 0).xyzw;
				o_Volumetrics = texelFetch(u_PreviousFrameVolumetrics, ivec2(PixelXHalved), 0);
			}
		}

		if (SpatialUpscaleAll) {

			ivec2 PixelHalvedX = Pixel;
			PixelHalvedX.x /= 2;

			float BaseDepthN = texelFetch(u_Depth, HighResPixel, 0).x;
			bool BaseIsSky = IsSky(BaseDepthN);
			float BaseDepth = linearizeDepth(BaseDepthN);
			vec3 BaseNormal = texelFetch(u_Normals, HighResPixel, 0).xyz;

			float TotalWeight = 0.0f;
			vec4 TotalDiffuse = vec4(0.0f);
			vec4 TotalSpec = vec4(0.0f);
			vec4 TotalVolumetrics = vec4(0.0f);

			for (int i = 0 ; i < 4 ; i++) {
				
				ivec2 Offset = UpscaleOffsets[i];
				ivec2 Coord = PixelHalvedX + Offset;
				ivec2 HighResCoord = HighResPixel + Offset;

				float SampleDepthN = texelFetch(u_Depth, HighResCoord, 0).x;
				bool SampleIsSky = IsSky(SampleDepthN);
				float SampleDepth = linearizeDepth(SampleDepthN);
				vec3 SampleNormal = texelFetch(u_Normals, HighResCoord, 0).xyz;

				vec4 SampleDiffuse = texelFetch(u_CurrentFrameTexture, Coord, 0).xyzw;
				vec4 SampleSpecular = texelFetch(u_CurrentFrameSpecular, Coord, 0).xyzw;
				vec4 SampleVol = texelFetch(u_CurrentFrameVolumetrics, Coord, 0).xyzw;

				float CurrentWeight = ((SampleIsSky ? float(SampleIsSky == BaseIsSky) : pow(exp(-(abs(SampleDepth - BaseDepth))), CDEPTH_EXP))) * (SampleIsSky ? 1.0f : pow(max(dot(SampleNormal, BaseNormal), 0.0f), CNORMAL_EXP));
				CurrentWeight = clamp(CurrentWeight, 0.0f, 1.0f);

				TotalDiffuse += SampleDiffuse * CurrentWeight;
				TotalSpec += SampleSpecular * CurrentWeight;
				TotalVolumetrics += SampleVol * CurrentWeight;
				TotalWeight += CurrentWeight;
			}

			TotalDiffuse /= max(TotalWeight, 0.0000001f);
			TotalSpec /= max(TotalWeight, 0.0000001f);
			TotalVolumetrics /= max(TotalWeight, 0.0000001f);
			o_Diffuse = TotalDiffuse;
			o_Specular = TotalSpec;
			o_Volumetrics = TotalVolumetrics;
		}

		else if (SpatialUpscaleSpecVol) {

			ivec2 PixelHalvedX = Pixel;
			PixelHalvedX.x /= 2;

			float BaseDepthN = texelFetch(u_Depth, HighResPixel, 0).x;
			bool BaseIsSky = IsSky(BaseDepthN);
			float BaseDepth = linearizeDepth(BaseDepthN);
			vec3 BaseNormal = texelFetch(u_Normals, HighResPixel, 0).xyz;

			float TotalWeight = 0.0f;
			vec4 TotalSpec = vec4(0.0f);
			vec4 TotalVolumetrics = vec4(0.0f);

			for (int i = 0 ; i < 4 ; i++) {
				
				ivec2 Offset = UpscaleOffsets[i];
				ivec2 Coord = PixelHalvedX + Offset;
				ivec2 HighResCoord = HighResPixel + Offset;

				float SampleDepthN = texelFetch(u_Depth, HighResCoord, 0).x;
				bool SampleIsSky = IsSky(SampleDepthN);
				float SampleDepth = linearizeDepth(SampleDepthN);
				vec3 SampleNormal = texelFetch(u_Normals, HighResCoord, 0).xyz;

				vec4 SampleDiffuse = texelFetch(u_CurrentFrameTexture, Coord, 0).xyzw;
				vec4 SampleSpecular = texelFetch(u_CurrentFrameSpecular, Coord, 0).xyzw;
				vec4 SampleVol = texelFetch(u_CurrentFrameVolumetrics, Coord, 0).xyzw;

				float CurrentWeight = ((SampleIsSky ? float(SampleIsSky == BaseIsSky) : pow(exp(-(abs(SampleDepth - BaseDepth))), CDEPTH_EXP))) * (SampleIsSky ? 1.0f : pow(max(dot(SampleNormal, BaseNormal), 0.0f), CNORMAL_EXP));
				CurrentWeight = clamp(CurrentWeight, 0.0f, 1.0f);

				TotalSpec += SampleSpecular * CurrentWeight;
				TotalVolumetrics += SampleVol * CurrentWeight;
				TotalWeight += CurrentWeight;
			}

			TotalSpec /= max(TotalWeight, 0.0000001f);
			TotalVolumetrics /= max(TotalWeight, 0.0000001f);
			o_Specular = TotalSpec;
			o_Volumetrics = TotalVolumetrics;
		}
	}

	else {

		ivec2 PixelHalvedX = Pixel;
		PixelHalvedX.x /= 2;
		o_Diffuse = texelFetch(u_CurrentFrameTexture, PixelHalvedX, 0).xyzw;
		o_Specular = texelFetch(u_CurrentFrameSpecular, PixelHalvedX, 0);
		o_Volumetrics = texelFetch(u_CurrentFrameVolumetrics, PixelHalvedX, 0);
	}
}