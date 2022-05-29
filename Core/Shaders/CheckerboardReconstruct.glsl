#version 330 core 

layout (location = 0) out vec4 o_Color;

uniform sampler2D u_Depth;
uniform sampler2D u_Normals;
uniform sampler2D u_CurrentFrameTexture;
uniform sampler2D u_PreviousFrameTexture;

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_PrevProjection;
uniform mat4 u_PrevView;

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

vec3 Reprojection(vec3 WorldPos) 
{
	vec4 ProjectedPosition = u_PrevProjection * u_PrevView * vec4(WorldPos, 1.0f);
	ProjectedPosition.xyz /= ProjectedPosition.w;
	ProjectedPosition.xyz = ProjectedPosition.xyz * 0.5f + 0.5f;
	return ProjectedPosition.xyz;

}

float linearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

void main() {
	
	bool OutputRaw = false;

	if (OutputRaw) {
		
		o_Color = texelFetch(u_CurrentFrameTexture, ivec2(gl_FragCoord.xy), 0);

		return;
	}

	
	ivec2 Pixel = ivec2(gl_FragCoord.xy);

	ivec2 HighResPixel = Pixel * 2;

	vec2 UV = vec2(HighResPixel) / vec2(u_Dimensions);

	bool IsCheckerStep = Pixel.x % 2 == int(Pixel.y % 2 == (u_Frame % 2));

	if (IsCheckerStep) {

		bool SpatialUpscale = false;
		
		if (true) {
			ivec2 ReprojectedPixel = Pixel;

			float Depth = texelFetch(u_Depth, HighResPixel, 0).x;
			vec3 WorldPosition = WorldPosFromDepth(Depth, UV).xyz;
			vec3 Reprojected = Reprojection(WorldPosition);

			ivec2 PixelHalvedX = ReprojectedPixel;
			PixelHalvedX.x /= 2;
			o_Color = texelFetch(u_PreviousFrameTexture, PixelHalvedX, 0).xyzw;
		}

		if (SpatialUpscale) {

			ivec2 PixelHalvedX = Pixel;
			PixelHalvedX.x /= 2;

			float BaseDepth = linearizeDepth(texelFetch(u_Depth, HighResPixel, 0).x);
			vec3 BaseNormal = texelFetch(u_Normals, HighResPixel, 0).xyz;

			float TotalWeight = 0.0f;
			vec4 Total = vec4(0.0f);

			for (int i = 0 ; i < 4 ; i++) {
				
				ivec2 Offset = UpscaleOffsets[i];
				ivec2 Coord = PixelHalvedX + Offset;
				ivec2 HighResCoord = HighResPixel + Offset;

				float SampleDepth = linearizeDepth(texelFetch(u_Depth, HighResCoord, 0).x);
				vec3 SampleNormal = texelFetch(u_Normals, HighResCoord, 0).xyz;

				vec4 SampleDiffuse = texelFetch(u_CurrentFrameTexture, Coord, 0).xyzw;

				float CurrentWeight = pow(exp(-(abs(SampleDepth - BaseDepth))), 48.0f) * pow(max(dot(SampleNormal, BaseNormal), 0.0f), 12.0f);
				CurrentWeight = clamp(CurrentWeight, 0.0000000001f, 1.0f);

				Total += SampleDiffuse * CurrentWeight;
				TotalWeight += CurrentWeight;
			}

			Total /= max(TotalWeight, 0.000001f);
			o_Color = Total;
		}
	}

	else {

		ivec2 PixelHalvedX = Pixel;
		PixelHalvedX.x /= 2;
		o_Color = texelFetch(u_CurrentFrameTexture, PixelHalvedX, 0).xyzw;

	}
}