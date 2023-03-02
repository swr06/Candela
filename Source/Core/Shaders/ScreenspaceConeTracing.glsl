#version 330 core

// Rough reflections without noise? 
// Reference paper : https://www.tobias-franke.eu/publications/hermanns14ssct/

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_Depth;
uniform sampler2D u_LFNormals;
uniform sampler2D u_PBR;
uniform sampler2D u_Input;

uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_InverseProjection;
uniform mat4 u_InverseView;

uniform vec3 u_Incident;

uniform float u_Time;
uniform int u_Frame;

const float kMaxSpecularExponent = 16.0;
const float kSpecularBias = 1.0;

float SpecularPowerToConeAngle(float specularPower)
{
    if(specularPower >= exp2(kMaxSpecularExponent)) 
    {
        return 0.0f;
    }

    const float xi = 0.244f;
    float exponent = 1.0f / (specularPower + 1.0f);
    return acos(pow(xi, exponent));
}

float RoughnessToSpecularPower(float roughness) 
{
    float gloss = 1.0f - roughness;
    return exp2(kMaxSpecularExponent * gloss + kSpecularBias);
}

float IsoscelesTriangleOpposite(float adjacentLength, float coneTheta) 
{
    return 2.0f * tan(coneTheta) * adjacentLength;
}

float IsoscelesTriangleInscribedCircleRadius(float a, float h) 
{
    float a2 = a * a;
    float fh2 = 4.0f * h * h;
    return (a * (sqrt(a2 + fh2) - a)) / (4.0f * h);
}

vec4 ConeSampleWeightedColor(vec2 samplePos, float mipChannel, float gloss) 
{
    vec3 sampleColor = textureLod(u_Input, samplePos, mipChannel).rgb;
    return vec4(sampleColor, gloss);
}

float IsoscelesTriangleNextAdjacent(float adjacentLength, float incircleRadius)
{
    return adjacentLength - (incircleRadius * 2.0f);
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

vec3 Project(vec3 WorldPos) 
{
	vec4 ProjectedPosition = u_Projection * u_View * vec4(WorldPos, 1.0f);
	ProjectedPosition.xyz /= ProjectedPosition.w;
	ProjectedPosition.xy = ProjectedPosition.xy * 0.5f + 0.5f;
	return ProjectedPosition.xyz;
}

void main() {
    float Depth = texture(u_Depth, v_TexCoords).x;
	vec3 WorldPosition = WorldPosFromDepth(Depth, v_TexCoords);
    vec3 LFNormal = texture(u_LFNormals, v_TexCoords).xyz; 
    vec3 PBR = texture(u_PBR, v_TexCoords).xyz;


    vec3 ViewDirection = normalize(WorldPosition - u_Incident);
    vec3 ReflectionVector = normalize(reflect(ViewDirection, LFNormal)); 

    vec4 BaseSample = texture(u_Input, v_TexCoords);

    float Transversal = BaseSample.w;//texture(u_Transversals, v_TexCoords).x;

    vec3 Total = vec3(0.0f);

    float RemainingAlpha = 1.0f;

    vec2 Dimensions = textureSize(u_Input, 0).xy;
    vec2 TexelSize = 1.0f / Dimensions;

    float Roughness = clamp(PBR.x, 0.0f, 1.0f);
    float SpecularPower = RoughnessToSpecularPower(Roughness);
    float ConeTheta = SpecularPowerToConeAngle(SpecularPower) * 0.5f;
    
    float AdjacentLength = pow(Transversal, 1.5f);
    float GlossMultiplier = 1.0f - Roughness;

    vec2 CurrentVector = Project(WorldPosition).xy;
    vec2 ProjectedReflectedVector = Project(WorldPosition + ReflectionVector * 2.0f).xy;

    vec2 AdjacentUnit = normalize(CurrentVector - ProjectedReflectedVector);
    
    float TotalWeight = 0.0f;


    for (int i = 0 ; i < 7 ; i++) {
        float OppositeLength = IsoscelesTriangleOpposite(AdjacentLength, ConeTheta);
        float InscribedCircleSize = IsoscelesTriangleInscribedCircleRadius(OppositeLength, AdjacentLength);
        vec2 SampleUV = v_TexCoords.xy + AdjacentUnit * 0.0f * (AdjacentLength - InscribedCircleSize);
        float MipNumber = clamp(log2(InscribedCircleSize * max(Dimensions.x, Dimensions.y)), 0.0, 6.0f);
        float Weight = 1.0f;
        Total += ConeSampleWeightedColor(SampleUV, MipNumber * 0.6f, GlossMultiplier).xyz * Weight;
        AdjacentLength = IsoscelesTriangleNextAdjacent(AdjacentLength, InscribedCircleSize);
        TotalWeight += Weight;
    }

    Total /= max(TotalWeight, 0.0001f);
    o_Color = Total;
}