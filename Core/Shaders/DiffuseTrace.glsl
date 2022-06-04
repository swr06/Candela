#version 450 core 

#define PI 3.141592653

layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba16f, binding = 0) uniform image2D o_OutputData;

#include "TraverseBVH.glsl"
#include "Include/SphericalHarmonics.glsl"
#include "Include/Utility.glsl"

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;

uniform vec2 u_Dims;
uniform vec3 u_SunDirection;

uniform sampler2D u_DepthTexture;
uniform sampler2D u_NormalTexture;
uniform samplerCube u_Skymap;

uniform int u_Frame;
uniform float u_Time;

uniform mat4 u_ShadowMatrices[5]; // <- shadow matrices 
uniform sampler2D u_ShadowTextures[5]; // <- the shadowmaps themselves 
uniform float u_ShadowClipPlanes[5]; // <- world space clip distances 

uniform vec3 u_ProbeBoxSize;
uniform vec3 u_ProbeGridResolution;
uniform vec3 u_ProbeBoxOrigin;

uniform usampler3D u_SHDataA;
uniform usampler3D u_SHDataB;

float[8] Trilinear(vec3 BoxMin, vec3 BoxMax, vec3 p) {
    float Weights[8];
    vec3 Extent = BoxMax - BoxMin;
    float InverseVolume = 1.0 / (Extent.x * Extent.y * Extent.z);
    Weights[0] = (BoxMax.x - p.x) * (BoxMax.y - p.y) * (BoxMax.z - p.z) * InverseVolume;
    Weights[1] = (BoxMax.x - p.x) * (p.y - BoxMin.y) * (BoxMax.z - p.z) * InverseVolume;
    Weights[2] = (p.x - BoxMin.x) * (p.y - BoxMin.y) * (BoxMax.z - p.z) * InverseVolume;
    Weights[3] = (p.x - BoxMin.x) * (BoxMax.y - p.y) * (BoxMax.z - p.z) * InverseVolume;
    Weights[4] = (BoxMax.x - p.x) * (BoxMax.y - p.y) * (p.z - BoxMin.z) * InverseVolume;
    Weights[5] = (BoxMax.x - p.x) * (p.y - BoxMin.y) * (p.z - BoxMin.z) * InverseVolume;
    Weights[6] = (p.x - BoxMin.x) * (p.y - BoxMin.y) * (p.z - BoxMin.z) * InverseVolume;
    Weights[7] = (p.x - BoxMin.x) * (BoxMax.y - p.y) * (p.z - BoxMin.z) * InverseVolume;
    return Weights;
}

SH GetSH(ivec3 Texel) {
	uvec4 A = texelFetch(u_SHDataA, Texel, 0);
	uvec4 B = texelFetch(u_SHDataB, Texel, 0);
	return UnpackSH(A,B);
}

float GetVisibility(ivec3 Texel, vec3 WorldPosition, vec3 Normal) {
	
	vec3 TexCoords = vec3(Texel) / u_ProbeGridResolution;
	vec3 Clip = TexCoords * 2.0f - 1.0f;
	vec3 ProbePosition = u_ProbeBoxOrigin + Clip * u_ProbeBoxSize;

	vec3 Vector = ProbePosition - WorldPosition;
	float Length = length(Vector);
	Vector /= Length;

	float Weight = pow(clamp(dot(Normal, Vector), 0.0f, 1.0f), 1.75f);
	return Weight;
}

vec3 SampleProbes(vec3 WorldPosition, vec3 N) {

	WorldPosition += N * 0.35f;

	vec3 SamplePoint = (WorldPosition - u_ProbeBoxOrigin) / u_ProbeBoxSize; 
	SamplePoint = SamplePoint * 0.5 + 0.5; 

	if (SamplePoint == clamp(SamplePoint, 0.0f, 1.0f)) {
		
		vec3 VolumeCoords = SamplePoint * (u_ProbeGridResolution);
		
		vec3 MinSampleBox = floor(VolumeCoords);
		vec3 MaxSampleBox = ceil(VolumeCoords);

		float Alpha = 0.0f;
		float Trilinear[8] = Trilinear(MinSampleBox, MaxSampleBox, VolumeCoords);
		ivec3 TexelCoordinates[8];
		SH sh[8];

		TexelCoordinates[0] = ivec3(vec3(MinSampleBox.x, MinSampleBox.y, MinSampleBox.z)); 
		TexelCoordinates[1] = ivec3(vec3(MinSampleBox.x, MaxSampleBox.y, MinSampleBox.z));
		TexelCoordinates[2] = ivec3(vec3(MaxSampleBox.x, MaxSampleBox.y, MinSampleBox.z)); 
		TexelCoordinates[3] = ivec3(vec3(MaxSampleBox.x, MinSampleBox.y, MinSampleBox.z));
		TexelCoordinates[4] = ivec3(vec3(MinSampleBox.x, MinSampleBox.y, MaxSampleBox.z));
		TexelCoordinates[5] = ivec3(vec3(MinSampleBox.x, MaxSampleBox.y, MaxSampleBox.z));
		TexelCoordinates[6] = ivec3(vec3(MaxSampleBox.x, MaxSampleBox.y, MaxSampleBox.z)); 
		TexelCoordinates[7] = ivec3(vec3(MaxSampleBox.x, MinSampleBox.y, MaxSampleBox.z));

		for (int i = 0 ; i < 8 ; i++) {
			sh[i] = GetSH(TexelCoordinates[i]);
			float ProbeVisibility = GetVisibility(TexelCoordinates[i], WorldPosition, N);
			Alpha += Trilinear[i] * (1.0f - ProbeVisibility);
			Trilinear[i] *= ProbeVisibility;
		}

		float WeightSum = 1.0f - Alpha;

		SH FinalSH = GenerateEmptySH();

		for (int i = 0 ; i < 8 ; i++) {
			ScaleSH(sh[i], vec3(Trilinear[i] / max(WeightSum, 0.000001f)));
			FinalSH = AddSH(FinalSH, sh[i]);
		}

		return max(SampleSH(FinalSH, N), 0.0f);
	}

	return vec3(0.0f);
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

float SampleShadowMap(vec2 SampleUV, int Map) {

	switch (Map) {
		
		case 0 :
			return texture(u_ShadowTextures[0], SampleUV).x; break;

		case 1 :
			return texture(u_ShadowTextures[1], SampleUV).x; break;

		case 2 :
			return texture(u_ShadowTextures[2], SampleUV).x; break;

		case 3 :
			return texture(u_ShadowTextures[3], SampleUV).x; break;

		case 4 :
			return texture(u_ShadowTextures[4], SampleUV).x; break;
	}

	return texture(u_ShadowTextures[4], SampleUV).x;
}

bool IsInBox(vec3 point, vec3 Min, vec3 Max) {
  return (point.x >= Min.x && point.x <= Max.x) &&
         (point.y >= Min.y && point.y <= Max.y) &&
         (point.z >= Min.z && point.z <= Max.z);
}

float GetDirectShadow(vec3 WorldPosition, vec3 N)
{
	int ClosestCascade = -1;
	float Shadow = 0.0;
	float VogelScales[5] = float[5](0.001f, 0.0015f, 0.002f, 0.00275f, 0.00325f);
	
	vec2 TexelSize = 1.0 / textureSize(u_ShadowTextures[ClosestCascade], 0);

	vec4 ProjectionCoordinates;

	float HashBorder = 1.0f; 

	for (int Cascade = 0 ; Cascade < 4; Cascade++) {
	
		ProjectionCoordinates = u_ShadowMatrices[Cascade] * vec4(WorldPosition + N * 0.0275f, 1.0f);

		if (ProjectionCoordinates.z < 1.0f && abs(ProjectionCoordinates.x) < 1.0f && abs(ProjectionCoordinates.y) < 1.0f)
		{
			bool BoxCheck = IsInBox(WorldPosition, 
									u_InverseView[3].xyz-(u_ShadowClipPlanes[Cascade]),
									u_InverseView[3].xyz+(u_ShadowClipPlanes[Cascade]));

			//if (BoxCheck) 
			{
				ProjectionCoordinates = ProjectionCoordinates * 0.5f + 0.5f;
				ClosestCascade = Cascade;
				break;
			}
		}
	}

	if (ClosestCascade < 0) {
		return 0.0f;
	}
	
	float Bias = 0.00f;
	vec2 SampleUV = ProjectionCoordinates.xy;
	Shadow = float(ProjectionCoordinates.z - Bias > SampleShadowMap(SampleUV, ClosestCascade)); 
	return 1.0f - Shadow;
}

vec3 GetDirect(in vec3 WorldPosition, in vec3 Normal, in vec3 Albedo) {

	float Shadow = GetDirectShadow(WorldPosition, Normal);
	return vec3(Albedo) * 16.0f * Shadow * clamp(dot(Normal, -u_SunDirection), 0.0f, 1.0f);
}

vec3 CosWeightedHemisphere(const vec3 n, vec2 r) 
{
	float PI2 = 2.0f * 3.1415926f;
	vec3  uu = normalize(cross(n, vec3(0.0,1.0,1.0)));
	vec3  vv = cross(uu, n);
	float ra = sqrt(r.y);
	float rx = ra * cos(PI2 * r.x); 
	float ry = ra * sin(PI2 * r.x);
	float rz = sqrt(1.0 - r.y);
	vec3  rr = vec3(rx * uu + ry * vv + rz * n );
    return normalize(rr);
}


float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

const bool CHECKERBOARD = true;
const bool DO_SECOND_BOUNCE = true;
const bool RT_SECOND_BOUNCE = false;

void main() {

	ivec2 Pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 WritePixel = ivec2(gl_GlobalInvocationID.xy);

	if (Pixel.x < 0 || Pixel.y < 0 || Pixel.x > int(u_Dims.x) || Pixel.y > int(u_Dims.y)) {
		return;
	}

	// Handle checkerboard 
	if (CHECKERBOARD) {
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
	 
	// Outputs 
	int IntersectedMesh = -1;
	int IntersectedTri = -1;
	vec4 TUVW = vec4(-1.0f);
	vec3 Albedo = vec3(0.0f);
	vec3 iNormal = vec3(-1.0f);
		
	// Intersect ray 
	IntersectRay(RayOrigin, RayDirection, TUVW, IntersectedMesh, IntersectedTri, Albedo, iNormal);

	// Compute radiance 
	vec3 FinalRadiance = TUVW.x < 0.0f ? texture(u_Skymap, RayDirection).xyz * 2.0f : GetDirect((RayOrigin + RayDirection * TUVW.x), iNormal, Albedo);

	// Integrate multibounce lighting 
	if (DO_SECOND_BOUNCE) {

		vec3 Bounced = vec3(0.0f);
		vec3 HitPosition = RayOrigin + RayDirection * TUVW.x;

		if (RT_SECOND_BOUNCE) {

			int Samples = 1;

			for (int i = 0 ; i < Samples ; i++) {

				int SecondIntersectedMesh = -1;
				int SecondIntersectedTri = -1;
				vec4 SecondTUVW = vec4(-1.0f);
				vec3 SecondAlbedo = vec3(0.0f);
				vec3 SecondiNormal = vec3(-1.0f);

				vec3 SecondRayOrigin = HitPosition+iNormal*0.02f;
				vec3 SecondRayDirection = CosWeightedHemisphere(iNormal,hash2());
				IntersectRay(SecondRayOrigin, SecondRayDirection, SecondTUVW, SecondIntersectedMesh, SecondIntersectedTri, SecondAlbedo, SecondiNormal);
				Bounced += TUVW.x < 0.0f ? texture(u_Skymap, SecondRayDirection).xyz * 2.0f : GetDirect((SecondRayOrigin + SecondRayDirection * SecondTUVW.x), SecondiNormal, SecondAlbedo);
			}

			Bounced /= float(Samples);
		}

		else {
			const float Strength = 1.9f;
			vec3 InterpolatedRadiance = SampleProbes(HitPosition + iNormal * 0.01f, iNormal);
			Bounced = clamp(InterpolatedRadiance * Strength, 0.0f, 10.0f);
		}

		float RayProbability = 1.0f / (dot(Normal, RayDirection) / PI); 
		vec3 Throughput = Albedo * RayProbability; // <- Lambert throughput
		FinalRadiance += Bounced * Throughput;
	}

	float AO = pow(clamp(TUVW.x / 1.1f, 0.0f, 1.0f), 3.1f);
	imageStore(o_OutputData, WritePixel, vec4(FinalRadiance, AO));
}
