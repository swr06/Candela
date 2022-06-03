#version 430 core
#define PI 3.14159265359

#include "Include/Octahedral.glsl"
#include "Include/SphericalHarmonics.glsl"

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_AlbedoTexture;
uniform sampler2D u_NormalTexture;
uniform sampler2D u_PBRTexture;
uniform sampler2D u_DepthTexture;
uniform sampler2D u_BlueNoise;
uniform samplerCube u_Skymap;

uniform sampler2D u_Trace;

uniform vec3 u_ViewerPosition;
uniform vec3 u_LightDirection;
uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform vec2 u_Dims;

uniform mat4 u_ShadowMatrices[5]; // <- shadow matrices 
uniform sampler2D u_ShadowTextures[5]; // <- the shadowmaps themselves 
uniform float u_ShadowClipPlanes[5]; // <- world space clip distances 

uniform vec3 u_ProbeBoxSize;
uniform vec3 u_ProbeGridResolution;
uniform vec3 u_ProbeBoxOrigin;
uniform usampler3D u_SHDataA;
uniform usampler3D u_SHDataB;

struct ProbeMapPixel {
	vec2 Packed;
};

layout (std430, binding = 4) buffer SSBO_ProbeMaps {
	ProbeMapPixel MapData[]; // x has luminance data, y has packed depth and depth^2
};

ivec3 Get3DIdx(int idx, ivec3 GridSize)
{
	int z = idx / (GridSize.x * GridSize.y);
	idx -= (z * GridSize.x * GridSize.y);
	int y = idx / GridSize.x;
	int x = idx % GridSize.x;
	return ivec3(x, y, z);
}

int Get1DIdx(ivec3 index, ivec3 GridSize)
{
    return (index.z * GridSize.x * GridSize.y) + (index.y * GridSize.x) + GridSize.x;
}

int Get1DIdx(ivec2 Coord, ivec2 GridSize) {
	return (Coord.x * GridSize.x) + Coord.y;
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

vec2 GetVogelDiskSample(int sampleIndex, int sampleCount, float phi) 
{
    const float goldenAngle = 2.399963f;
    float r = sqrt((float(sampleIndex) + 0.5) / float(sampleCount));  
    float theta = float(sampleIndex) * goldenAngle + phi;
	vec2 sincos;
	sincos.x = sin(theta);
    sincos.y = cos(theta);
    return sincos.xy * r;
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

float FilterShadows(vec3 WorldPosition, vec3 N)
{
	int ClosestCascade = -1;
	float Shadow = 0.0;
	float VogelScales[5] = float[5](0.002f, 0.0015f, 0.0015f, 0.0015f, 0.002f);
	
	vec2 Hash = texture(u_BlueNoise, v_TexCoords * (u_Dims / textureSize(u_BlueNoise, 0).xy)).rg;

	vec2 TexelSize = 1.0 / textureSize(u_ShadowTextures[ClosestCascade], 0);

	vec4 ProjectionCoordinates;

	float HashBorder = 0.95f - Hash.y * 0.03f; 

	//float Distance = distance(WorldPosition, u_InverseView[3].xyz);

	for (int Cascade = 0 ; Cascade < 4; Cascade++) {
	
		ProjectionCoordinates = u_ShadowMatrices[Cascade] * vec4(WorldPosition + N * 0.025f, 1.0f);

		if (abs(ProjectionCoordinates.x) < HashBorder && abs(ProjectionCoordinates.y) < HashBorder && ProjectionCoordinates.z < 1.0f 
		    && abs(ProjectionCoordinates.x) < 1.0f && abs(ProjectionCoordinates.y) < 1.0f)
		{
			bool BoxCheck = IsInBox(WorldPosition, 
									u_InverseView[3].xyz-(u_ShadowClipPlanes[Cascade]-Hash.x*0.55f),
									u_InverseView[3].xyz+(u_ShadowClipPlanes[Cascade]+Hash.x*0.5f));

			//if (BoxCheck) 
			{
				ProjectionCoordinates = ProjectionCoordinates * 0.5f + 0.5f;
				ClosestCascade = Cascade;
				break;
			}
		}
	}

	if (ClosestCascade < 0) {
		return 1.0f;
	}
	
	float Bias = 0.00f;

	int SampleCount = 32;
    
	for (int Sample = 0 ; Sample < SampleCount ; Sample++) {

		vec2 SampleUV = ProjectionCoordinates.xy + VogelScales[ClosestCascade] * GetVogelDiskSample(Sample, SampleCount, Hash.x);
		
		if (SampleUV != clamp(SampleUV, 0.000001f, 0.999999f))
		{ 
			continue;
		}

		Shadow += float(ProjectionCoordinates.z - Bias > SampleShadowMap(SampleUV, ClosestCascade)); 
		
	}

	Shadow /= float(SampleCount);

	return 1.0f - clamp(pow(Shadow, 1.0f), 0.0f, 1.0f);
}

vec3 SampleIncidentRayDirection(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}

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

	float Weight = pow(clamp(dot(Normal, Vector), 0.0f, 1.0f), 4.0f);
	return Weight;
}

vec3 SampleProbes(vec3 WorldPosition, vec3 N) {


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

		return max(SampleSH(FinalSH, N), 0.0f) * 10.0f;
	}

	return vec3(0.0f);
}

void main() 
{	
	vec3 rO = u_InverseView[3].xyz;
	vec3 rD = normalize(SampleIncidentRayDirection(v_TexCoords));

	float Depth = texture(u_DepthTexture, v_TexCoords).x;

	if (Depth > 0.999999f) {
		o_Color = texture(u_Skymap, rD).xyz;
		return;
	}

	vec3 WorldPosition = WorldPosFromDepth(Depth,v_TexCoords).xyz;
	vec3 Normal = normalize(texture(u_NormalTexture, v_TexCoords).xyz);
	vec3 Albedo = texture(u_AlbedoTexture, v_TexCoords).xyz;

	vec4 GI = texture(u_Trace, v_TexCoords).xyzw; 

	vec3 Direct = Albedo * 16.0 * max(dot(Normal, -u_LightDirection),0.) * FilterShadows(WorldPosition, Normal);
	vec3 DiffuseIndirect = GI.xyz * Albedo * GI.w;

	o_Color = DiffuseIndirect + Direct;
	
}