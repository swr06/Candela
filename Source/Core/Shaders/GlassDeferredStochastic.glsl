#version 450 core

#include "Include/SphericalHarmonics.glsl"
#include "Include/Utility.glsl"

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

uniform sampler2D u_AlbedoData;
uniform sampler2D u_NormalData;

uniform sampler3D u_RadianceCache;

uniform vec2 u_Dimensions;

uniform sampler2D u_RefractionData;
uniform sampler2D u_OpaqueLighting;

uniform sampler2D u_OpaqueDepth;
uniform sampler2D u_TransparentDepth;

in vec2 v_TexCoords;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

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

float GetVisibility(ivec3 Texel, vec3 WorldPosition, vec3 Normal, SH sh) {
	
	vec3 TexCoords = vec3(Texel) / u_ProbeGridResolution;
	vec3 Clip = TexCoords * 2.0f - 1.0f;
	vec3 ProbePosition = u_ProbeBoxOrigin + Clip * u_ProbeBoxSize;

	vec3 Vector = ProbePosition - WorldPosition;
	float Length = length(Vector);
	Vector /= Length;

	vec3 ProminentDirection = normalize(GetMostProminentDirection(sh, 2));
	float Weight = pow(clamp(dot(Normal, Vector), 0.0f, 1.0f), 1.25f) * clamp(dot(Normal, ProminentDirection), 0.3f, 1.0f);
	return Weight;
}

vec3 SampleProbes(vec3 WorldPosition, vec3 N, bool Nudge) {

	WorldPosition += N * 0.4f * float(Nudge);
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
			float ProbeVisibility = GetVisibility(TexelCoordinates[i], WorldPosition, N, sh[i]);
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


bool IsInProbeGrid(vec3 P) {
	vec3 SamplePoint = (P - u_ProbeBoxOrigin) / u_ProbeBoxSize; 
	SamplePoint = SamplePoint * 0.5 + 0.5; 
	return SamplePoint == clamp(SamplePoint, 0.0f, 1.0f);
}

vec3 GetCacheGI(vec3 Point, vec3 Hash3D) {

	Point += Hash3D * 2.0f - 1.0f;
	
	vec3 SamplePoint = (Point - u_ProbeBoxOrigin) / u_ProbeBoxSize; 
	SamplePoint = SamplePoint * 0.5 + 0.5; 

	if (SamplePoint == clamp(SamplePoint, 0.0001f, 0.9999f)) {
		return texture(u_RadianceCache, SamplePoint).xyz;
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

void main()
{
	float OpaqueDepth = texture(u_OpaqueDepth, v_TexCoords).x;
	float TransparentDepth = texture(u_TransparentDepth, v_TexCoords).x;

	if (TransparentDepth > OpaqueDepth || TransparentDepth > 0.9999f) {
		discard;
	}

	vec4 Normal = texture(u_NormalData, v_TexCoords);
	vec4 Albedo = texture(u_AlbedoData, v_TexCoords);

	float Z = LinearizeDepth(Normal.w);

	vec3 WorldPosition = WorldPosFromDepth(Normal.w, v_TexCoords);

	int Step = 1;
	vec3 VolumeHash;
	VolumeHash.x = fract(fract(mod(float(u_Frame) + float((Step * 3) + 0) * 2., 384.0f) * (1.0 / 1.6180339)) + bayer32(gl_FragCoord.xy));
	VolumeHash.y = fract(fract(mod(float(u_Frame) + float((Step * 3) + 1) * 2., 384.0f) * (1.0 / 1.6180339)) + bayer32(gl_FragCoord.xy));
	VolumeHash.z = fract(fract(mod(float(u_Frame) + float((Step * 3) + 2) * 2., 384.0f) * (1.0 / 1.6180339)) + bayer32(gl_FragCoord.xy));

	vec3 Lighting = GetCacheGI(WorldPosition,VolumeHash);

	o_Color = vec4(Lighting.xyz * Albedo.xyz, 1.);
}
