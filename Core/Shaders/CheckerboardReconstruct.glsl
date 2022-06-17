#version 330 core 

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

layout (location = 0) out vec4 o_Diffuse;
layout (location = 1) out vec4 o_Specular;

in vec2 v_TexCoords;

uniform sampler2D u_Depth;
uniform sampler2D u_PreviousDepth;
uniform sampler2D u_Normals;
uniform sampler2D u_PreviousNormals;
uniform sampler2D u_CurrentFrameTexture;
uniform sampler2D u_PreviousFrameTexture;

uniform sampler2D u_CurrentFrameSpecular;
uniform sampler2D u_PreviousFrameSpecular;

uniform sampler2D u_MotionVectors;

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_PrevProjection;
uniform mat4 u_PrevView;
uniform mat4 u_PrevInverseProjection;
uniform mat4 u_PrevInverseView;

uniform int u_Frame;
uniform float u_zNear;
uniform float u_zFar;

uniform vec2 u_Dimensions;

const ivec2 UpscaleOffsets[4] = ivec2[](ivec2(1, 0), ivec2(-1, 0), ivec2(0, 1), ivec2(0, -1)); 

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
	
	bool OutputRaw = false;

	if (OutputRaw) {
		
		o_Diffuse = texelFetch(u_CurrentFrameTexture, ivec2(gl_FragCoord.xy), 0);
		o_Specular = texelFetch(u_CurrentFrameSpecular, ivec2(gl_FragCoord.xy), 0);
		return;
	}

	
	ivec2 Pixel = ivec2(gl_FragCoord.xy);

	ivec2 HighResPixel = Pixel * 2;

	bool IsCheckerStep = Pixel.x % 2 == int(Pixel.y % 2 == (u_Frame % 2));

	if (IsCheckerStep) {

		bool SpatialUpscaleAll = false;
		bool SpatialUpscaleSpec = false;

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

			if (MotionLength > 0.002f) {
				SpatialUpscaleSpec = true; // <- Spatially resolve specular if motion vector changed, we cant reliably reproject it for the checkerboard 
			}

			else {
				o_Specular = texelFetch(u_PreviousFrameSpecular, ivec2(PixelXHalved), 0).xyzw;
			}
		}

		if (SpatialUpscaleAll) {

			ivec2 PixelHalvedX = Pixel;
			PixelHalvedX.x /= 2;

			float BaseDepth = linearizeDepth(texelFetch(u_Depth, HighResPixel, 0).x);
			vec3 BaseNormal = texelFetch(u_Normals, HighResPixel, 0).xyz;

			float TotalWeight = 0.0f;
			vec4 TotalDiffuse = vec4(0.0f);
			vec4 TotalSpec = vec4(0.0f);

			for (int i = 0 ; i < 4 ; i++) {
				
				ivec2 Offset = UpscaleOffsets[i];
				ivec2 Coord = PixelHalvedX + Offset;
				ivec2 HighResCoord = HighResPixel + Offset;

				float SampleDepth = linearizeDepth(texelFetch(u_Depth, HighResCoord, 0).x);
				vec3 SampleNormal = texelFetch(u_Normals, HighResCoord, 0).xyz;

				vec4 SampleDiffuse = texelFetch(u_CurrentFrameTexture, Coord, 0).xyzw;
				vec4 SampleSpecular = texelFetch(u_CurrentFrameSpecular, Coord, 0).xyzw;

				float CurrentWeight = pow(exp(-(abs(SampleDepth - BaseDepth))), DEPTH_EXPONENT) * pow(max(dot(SampleNormal, BaseNormal), 0.0f), NORMAL_EXPONENT);
				CurrentWeight = clamp(CurrentWeight, 0.0f, 1.0f);

				TotalDiffuse += SampleDiffuse * CurrentWeight;
				TotalSpec += SampleSpecular * CurrentWeight;
				TotalWeight += CurrentWeight;
			}

			TotalDiffuse /= max(TotalWeight, 0.0000001f);
			TotalSpec /= max(TotalWeight, 0.0000001f);
			o_Diffuse = TotalDiffuse;
			o_Specular = TotalSpec;
		}

		else if (SpatialUpscaleSpec) {

			ivec2 PixelHalvedX = Pixel;
			PixelHalvedX.x /= 2;

			float BaseDepth = linearizeDepth(texelFetch(u_Depth, HighResPixel, 0).x);
			vec3 BaseNormal = texelFetch(u_Normals, HighResPixel, 0).xyz;

			float TotalWeight = 0.0f;
			vec4 TotalSpec = vec4(0.0f);

			for (int i = 0 ; i < 4 ; i++) {
				
				ivec2 Offset = UpscaleOffsets[i];
				ivec2 Coord = PixelHalvedX + Offset;
				ivec2 HighResCoord = HighResPixel + Offset;

				float SampleDepth = linearizeDepth(texelFetch(u_Depth, HighResCoord, 0).x);
				vec3 SampleNormal = texelFetch(u_Normals, HighResCoord, 0).xyz;

				vec4 SampleDiffuse = texelFetch(u_CurrentFrameTexture, Coord, 0).xyzw;
				vec4 SampleSpecular = texelFetch(u_CurrentFrameSpecular, Coord, 0).xyzw;

				float CurrentWeight = pow(exp(-(abs(SampleDepth - BaseDepth))), DEPTH_EXPONENT) * pow(max(dot(SampleNormal, BaseNormal), 0.0f), NORMAL_EXPONENT);
				CurrentWeight = clamp(CurrentWeight, 0.0f, 1.0f);

				TotalSpec += SampleSpecular * CurrentWeight;
				TotalWeight += CurrentWeight;
			}

			TotalSpec /= max(TotalWeight, 0.0000001f);
			o_Specular = TotalSpec;
		}
	}

	else {

		ivec2 PixelHalvedX = Pixel;
		PixelHalvedX.x /= 2;
		o_Diffuse = texelFetch(u_CurrentFrameTexture, PixelHalvedX, 0).xyzw;
		o_Specular = texelFetch(u_CurrentFrameSpecular, PixelHalvedX, 0);
	}
}