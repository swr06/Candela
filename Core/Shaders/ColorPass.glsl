#version 430 core
#define PI 3.14159265359

#define DO_INDIRECT 

#include "Include/Octahedral.glsl"
#include "Include/SphericalHarmonics.glsl"
#include "Include/DebugIrradianceCache.glsl" 
#include "Include/CookTorranceBRDF.glsl"
#include "Include/SpatialUtility.glsl"
#include "Include/Karis.glsl"
#include "Include/Utility.glsl"

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_AlbedoTexture;
uniform sampler2D u_NormalTexture;
uniform sampler2D u_PBRTexture;
uniform sampler2D u_DepthTexture;
uniform sampler2D u_BlueNoise;
uniform samplerCube u_Skymap;

uniform sampler2D u_IndirectDiffuse;
uniform sampler2D u_IndirectSpecular;

uniform sampler2D u_Volumetrics;

uniform vec3 u_ViewerPosition;
uniform vec3 u_LightDirection;
uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform vec2 u_Dims;

uniform int u_Frame;

uniform mat4 u_ShadowMatrices[5]; // <- shadow matrices 
uniform sampler2D u_ShadowTextures[5]; // <- the shadowmaps themselves 
uniform float u_ShadowClipPlanes[5]; // <- world space clip distances 

struct ProbeMapPixel {
	vec2 Packed;
};

layout (std430, binding = 4) buffer SSBO_ProbeMaps {
	ProbeMapPixel MapData[]; // x has luminance data, y has packed depth and depth^2
};

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
	float VogelScales[5] = float[5](0.003f, 0.0015f, 0.0015f, 0.0015f, 0.002f);
	
	vec2 Hash = texture(u_BlueNoise, v_TexCoords * (u_Dims / textureSize(u_BlueNoise, 0).xy)).rg;

	Hash.xy = mod(Hash.xy + 1.61803398874f * (u_Frame % 100), 1.0f);

	vec2 TexelSize = 1.0 / textureSize(u_ShadowTextures[ClosestCascade], 0);

	vec4 ProjectionCoordinates;

	float HashBorder = 0.95f - Hash.y * 0.03f; 

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

	int SampleCount = 5;
    
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

const vec3 SunColor = vec3(16.0f);

void main() 
{	
	vec3 rO = u_InverseView[3].xyz;

	ivec2 Pixel = ivec2(gl_FragCoord.xy);

	//vec4 Volumetrics = texelFetch(u_Volumetrics, Pixel / 2, 0);
	vec4 Volumetrics = texture(u_Volumetrics, v_TexCoords);

	float Depth = texelFetch(u_DepthTexture, Pixel, 0).x;

	if (Depth > 0.999999f) {
		vec3 rD = normalize(SampleIncidentRayDirection(v_TexCoords));
		o_Color = pow(texture(u_Skymap, rD).xyz,vec3(2.)) * 1.0f; // <----- pow2 done here 
		o_Color = o_Color * Volumetrics.w + Volumetrics.xyz * 0.2f;
		return;
	}

	vec3 WorldPosition = WorldPosFromDepth(Depth,v_TexCoords).xyz;
	vec3 Normal = normalize(texelFetch(u_NormalTexture, Pixel, 0).xyz);
	vec3 Albedo = texelFetch(u_AlbedoTexture, Pixel, 0).xyz;
	vec3 PBR = texelFetch(u_PBRTexture, Pixel, 0).xyz;

	vec3 Incident = normalize(u_ViewerPosition - WorldPosition);

	vec3 F0 = mix(vec3(0.04f), Albedo, PBR.y);

	vec3 SpecularIndirect = vec3(0.0f);
	vec3 DiffuseIndirect = vec3(0.0f);

	#ifdef DO_INDIRECT
		const vec2 IndirectStrength = vec2(1.125f, 1.0f); // x : diffuse strength, y : specular strength

		// Sample GI
		vec4 GI = texture(u_IndirectDiffuse, v_TexCoords).xyzw; 
		vec4 SpecGI = texture(u_IndirectSpecular, v_TexCoords).xyzw; 

		vec3 FresnelTerm = FresnelSchlickRoughness(max(dot(Incident, Normal.xyz), 0.000001f), vec3(F0), PBR.x); 
		FresnelTerm = clamp(FresnelTerm, 0.0f, 1.0f);

		vec3 kS = FresnelTerm;
		vec3 kD = 1.0f - kS;
		kD *= 1.0f - PBR.y;
					
		vec2 BRDFCoord = vec2(max(dot(Incident, Normal.xyz), 0.000001f), PBR.x);
		BRDFCoord = clamp(BRDFCoord, 0.0f, 1.0f);
		vec2 BRDF = Karis(BRDFCoord.x, BRDFCoord.y);

		SpecularIndirect = SpecGI.xyz * (FresnelTerm * BRDF.x + BRDF.y) * IndirectStrength.y * (PBR.y > 0.04f ? 1.75f : 1.05f);
		DiffuseIndirect = kD * GI.xyz * Albedo * pow(GI.w, 3.0f) * IndirectStrength.x;

		mat4 ColorTweakMatrix = mat4(1.0f); //SaturationMatrix(1.1f);
		DiffuseIndirect = vec3(ColorTweakMatrix * vec4(DiffuseIndirect, 1.0f));

	#endif

	vec3 Direct = CookTorranceBRDF(u_ViewerPosition, WorldPosition, u_LightDirection, SunColor, Albedo, Normal, vec2(PBR.x, PBR.y), FilterShadows(WorldPosition, Normal)) * 0.5f;
	
	vec3 Combined = Direct + SpecularIndirect + DiffuseIndirect;

	o_Color = Combined * Volumetrics.w + Volumetrics.xyz;
}