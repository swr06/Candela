#version 400 core 
#define PI 3.14159265359 

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"
#include "Include/Sampling.glsl"
#include "Include/3DNoise.glsl"

layout (location = 0) out vec4 o_Volumetrics; // w -> Transmittance 

in vec2 v_TexCoords;

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

uniform int u_Steps;
uniform float u_Strength;
uniform float u_DStrength;
uniform float u_IStrength;

uniform mat4 u_ShadowMatrices[5]; // <- shadow matrices 
uniform sampler2D u_ShadowTextures[5]; // <- the shadowmaps themselves 
uniform float u_ShadowClipPlanes[5]; // <- world space clip distances 

uniform vec3 u_ProbeBoxSize;
uniform vec3 u_ProbeGridResolution;
uniform vec3 u_ProbeBoxOrigin;

uniform sampler3D u_ProbeRadiance;

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

bool RayBoxIntersect(vec3 origin, vec3 direction, vec3 mins, vec3 maxs, out float tIn, out float tOut)
{
	vec3 t1 = (mins - origin) / direction;
	vec3 t2 = (maxs - origin) / direction;
	tIn = vmax(min(t1, t2));
	tOut = vmin(max(t1, t2));
	return tIn < tOut && tOut > 0;
}

float SampleDensity(vec3 p)
{
	const float AltitudeMin = -1.4f;
	const float Thickness = 48.0f;
	const float Coverage = 2.0f;
	const float DensityMultiplier = 1.2f;

    float Altitude = ((p.y - AltitudeMin) / Thickness);
    float AltitudeAttenuation = remap(Altitude, 0.0f, 0.2f, 0.0f, 1.0f) * remap(Altitude, 0.9f, 1.0f, 1.0f, 0.0f);
    float FinalDensity = AltitudeAttenuation * Coverage - (2.0f * AltitudeAttenuation * Altitude * 0.5f + 0.5f);
	FinalDensity *= exp2(-max(p.y - AltitudeMin, 0.0f) * 0.35f);
    return clamp(FinalDensity, 0.0f, 1.0f) * DensityMultiplier;
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
			return TexelFetchNormalized(u_ShadowTextures[0], SampleUV).x; break;

		case 1 :
			return TexelFetchNormalized(u_ShadowTextures[1], SampleUV).x; break;

		case 2 :
			return TexelFetchNormalized(u_ShadowTextures[2], SampleUV).x; break;

		case 3 :
			return TexelFetchNormalized(u_ShadowTextures[3], SampleUV).x; break;

		case 4 :
			return TexelFetchNormalized(u_ShadowTextures[4], SampleUV).x; break;
	}

	return TexelFetchNormalized(u_ShadowTextures[4], SampleUV).x;
}

bool IsInBox(vec3 point, vec3 Min, vec3 Max) {
  return (point.x >= Min.x && point.x <= Max.x) &&
         (point.y >= Min.y && point.y <= Max.y) &&
         (point.z >= Min.z && point.z <= Max.z);
}

float GetDirectShadow(vec3 WorldPosition)
{
	int ClosestCascade = -1;
	float Shadow = 0.0;
	float VogelScales[5] = float[5](0.001f, 0.0015f, 0.002f, 0.00275f, 0.00325f);
	
	vec2 TexelSize = 1.0 / textureSize(u_ShadowTextures[ClosestCascade], 0);

	vec4 ProjectionCoordinates;

	float HashBorder = 1.0f; 

	for (int Cascade = 0 ; Cascade < 4; Cascade++) {
	
		ProjectionCoordinates = u_ShadowMatrices[Cascade] * vec4(WorldPosition, 1.0f);

		if (ProjectionCoordinates.z < 1.0f && abs(ProjectionCoordinates.x) < 1.0f && abs(ProjectionCoordinates.y) < 1.0f)
		{
			bool BoxCheck = IsInBox(WorldPosition, 
									u_InverseView[3].xyz-(u_ShadowClipPlanes[Cascade]),
									u_InverseView[3].xyz+(u_ShadowClipPlanes[Cascade]));

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
	
	float Bias = 0.000166f;
	vec2 SampleUV = ProjectionCoordinates.xy;
	Shadow = float(ProjectionCoordinates.z - Bias > SampleShadowMap(SampleUV, ClosestCascade)); 
	return 1.0f - Shadow;
}

vec3 GetVolumeGI(vec3 Point, vec3 Hash3D) {

	Point += Hash3D * 2.0f - 1.0f;
	
	vec3 SamplePoint = (Point - u_ProbeBoxOrigin) / u_ProbeBoxSize; 
	SamplePoint = SamplePoint * 0.5 + 0.5; 

	if (SamplePoint == clamp(SamplePoint, 0.0001f, 0.9999f)) {
		return texture(u_ProbeRadiance, SamplePoint).xyz * 1.95f;
	}

	return vec3(0.0f);
}

vec3 Incident(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return normalize(vec3(u_InverseView * eye));
}

void main() {
	
	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	ivec2 WritePixel = ivec2(gl_FragCoord.xy);

	if (Pixel.x < 0 || Pixel.y < 0 || Pixel.x > int(u_Dims.x) || Pixel.y > int(u_Dims.y)) {
		return;
	}

	// Handle checkerboard 
	if (true) {
		Pixel.x *= 2;
		bool IsCheckerStep = Pixel.x % 2 == int(Pixel.y % 2 == (u_Frame % 2));
		Pixel.x += int(IsCheckerStep);
	}

	// 1/2 res on each axis
    ivec2 HighResPixel = Pixel * 2;
    vec2 HighResUV = vec2(HighResPixel) / textureSize(u_DepthTexture, 0).xy;

	// Fetch 
    float Depth = texelFetch(u_DepthTexture, HighResPixel, 0).x;

	float Distance = 40.0f;

	vec2 TexCoords = HighResUV;
	HASH2SEED = (TexCoords.x * TexCoords.y) * 64.0 * u_Time;

	vec3 Player = u_InverseView[3].xyz;

	vec3 Normal = texelFetch(u_NormalTexture, HighResPixel, 0).xyz;
	vec3 WorldPosition = WorldPosFromDepth(Depth, TexCoords) + Normal * 0.3f;

	if (Depth != 1.0f) {
		Distance = distance(WorldPosition, Player);
    }

	vec3 Direction = (Incident(v_TexCoords));

	int Steps = u_Steps + 1;
	float StepSize = Distance / float(Steps);

	float HashAnimated = fract(fract(mod(float(u_Frame) + float(0.) * 2., 384.0f) * (1.0 / 1.6180339)) + bayer16(gl_FragCoord.xy));

	vec3 RayPosition = Player + Direction * HashAnimated * 1.0f; 

    const float G = 0.7f;

    float CosTheta = dot(-Direction, normalize(u_SunDirection));

    float DirectPhase = 0.25f / PI;
	float IndirectPhase = 0.25f / PI; // Isotropic 

    float Transmittance = 1.0f;

    vec3 TotalScattering = vec3(0.0f);

    float SigmaE = 0.04f; 

    vec3 SunColor = (vec3(253.,184.,100.)/255.0f) * 0.12f * 2.0f * 0.3333f;

	float LightingStrength = u_Strength * 0.182f;

    for (int Step = 0 ; Step < Steps ; Step++) {

        float Density = SampleDensity(RayPosition);

        if (Density <= 0.0f) {
			RayPosition += Direction * StepSize;
            continue;
        }

		if (Transmittance < 0.00125f) {
			break;
		}

		vec3 VolumeHash;
		
		if (false) {
			VolumeHash = vec3(hash2(), hash2().x);
		}

		else {
			VolumeHash.x = fract(fract(mod(float(u_Frame) + float((Step * 3) + 0) * 2., 384.0f) * (1.0 / 1.6180339)) + bayer32(gl_FragCoord.xy));
			VolumeHash.y = fract(fract(mod(float(u_Frame) + float((Step * 3) + 1) * 2., 384.0f) * (1.0 / 1.6180339)) + bayer64(gl_FragCoord.xy));
			VolumeHash.z = fract(fract(mod(float(u_Frame) + float((Step * 3) + 2) * 2., 384.0f) * (1.0 / 1.6180339)) + bayer16(gl_FragCoord.xy));
		}

        float DirectVisibility = GetDirectShadow(RayPosition);
        vec3 Direct = DirectVisibility * DirectPhase * SunColor * 26.0f * u_DStrength;
        vec3 Indirect = GetVolumeGI(RayPosition, VolumeHash) * IndirectPhase * u_IStrength;
        vec3 S = (Direct + Indirect) * LightingStrength * StepSize * Density * Transmittance;

        TotalScattering += S;
        Transmittance *= exp(-(StepSize * Density * SigmaE));

        RayPosition += Direction * StepSize; 
    }

    vec4 Data = vec4(vec3(TotalScattering), Transmittance);

	if (!IsValid(Data)) {
		Data = vec4(vec3(0.0f), 1.0f);
	}

	o_Volumetrics = Data;
}