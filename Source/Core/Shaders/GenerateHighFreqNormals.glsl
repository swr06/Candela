#version 430 core 

#include "Include/Utility.glsl"

#define TSample(x,y) (TexelFetchNormalized(x,y))
//#define TSample(x,y) (texture(x,y))
//#define TSample(x,y) (CatmullRom(x,y))

layout (location = 1) out vec4 o_HighFrequencyNormal;

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

in vec2 v_TexCoords;

uniform sampler2D u_AlbedoTexture;
uniform sampler2D u_LowFrequencyNormals;

uniform float u_Strength;

float WeightingFunction(vec3 x) {
	return mix(0.0f, pow(Luminance(x), 0.9f), u_Strength);
}

void main() {

	float DeltaX = 0.0f;
    float DeltaY = 0.0f;

	vec2 SampleCoord = v_TexCoords;
	vec2 TexelSize = 1.0f / textureSize(u_AlbedoTexture, 0);
    
	// Calculate deltas along x and y axes 

	// X axis 
    DeltaX -= WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x - TexelSize.x, SampleCoord.y - TexelSize.y)).rgb) * 1.0;
	DeltaX -= WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x - TexelSize.x, SampleCoord.y              )).rgb) * 2.0;
	DeltaX -= WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x - TexelSize.x, SampleCoord.y + TexelSize.y)).rgb) * 1.0;
	DeltaX += WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x + TexelSize.x, SampleCoord.y - TexelSize.y)).rgb) * 1.0;
	DeltaX += WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x + TexelSize.x, SampleCoord.y              )).rgb) * 2.0;
	DeltaX += WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x + TexelSize.x, SampleCoord.y + TexelSize.y)).rgb) * 1.0;
    
	// Y axis 
    DeltaY -= WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x - TexelSize.x, SampleCoord.y - TexelSize.y)).rgb) * 1.0;
	DeltaY -= WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x              , SampleCoord.y - TexelSize.y)).rgb) * 2.0;
	DeltaY -= WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x + TexelSize.x, SampleCoord.y - TexelSize.y)).rgb) * 1.0;
	DeltaY += WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x - TexelSize.x, SampleCoord.y + TexelSize.y)).rgb) * 1.0;
	DeltaY += WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x              , SampleCoord.y + TexelSize.y)).rgb) * 2.0;
	DeltaY += WeightingFunction(TSample(u_AlbedoTexture, vec2(SampleCoord.x + TexelSize.x, SampleCoord.y + TexelSize.y)).rgb) * 1.0;
    
    float NormalX = DeltaX;
    float NormalY = DeltaY;
	float NormalZ = sqrt(1.0 - NormalX*NormalX - NormalY * NormalY);
    vec3 Normal = vec3(NormalX, NormalY, NormalZ);

	vec3 LowFrequencyNormal = texture(u_LowFrequencyNormals, v_TexCoords).xyz;
	float Length = length(LowFrequencyNormal);
	LowFrequencyNormal /= Length;

	// Generate TBN Matrix 
	vec3 UpVector = abs(LowFrequencyNormal.z) < 0.999f ? vec3(0.0f, 0.0f, 1.0f) : vec3(1.0f, 0.0f, 0.0f);
    vec3 TangentVector = normalize(cross(UpVector, LowFrequencyNormal));
    vec3 Bitangent = cross(LowFrequencyNormal, TangentVector);

    vec3 AlignedNormal = TangentVector * Normal.x + Bitangent * Normal.y + LowFrequencyNormal * Normal.z;
	o_HighFrequencyNormal = vec4(AlignedNormal, 1.0f);
}