#version 430 core
#define PI 3.14159265359

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
	float VogelScales[5] = float[5](0.001f, 0.0015f, 0.002f, 0.00275f, 0.00325f);
	
	vec2 Hash = texture(u_BlueNoise, v_TexCoords * (u_Dims / textureSize(u_BlueNoise, 0).xy)).rg;

	vec2 TexelSize = 1.0 / textureSize(u_ShadowTextures[ClosestCascade], 0);

	vec4 ProjectionCoordinates;

	float HashBorder = 0.95f - Hash.y * 0.0125f; 

	//float Distance = distance(WorldPosition, u_InverseView[3].xyz);

	for (int Cascade = 0 ; Cascade < 4; Cascade++) {
	
		ProjectionCoordinates = u_ShadowMatrices[Cascade] * vec4(WorldPosition + N * 0.025f, 1.0f);

		if (abs(ProjectionCoordinates.x) < HashBorder && abs(ProjectionCoordinates.y) < HashBorder && ProjectionCoordinates.z < 1.0f 
		    && abs(ProjectionCoordinates.x) < 1.0f && abs(ProjectionCoordinates.y) < 1.0f)
		{
			bool BoxCheck = IsInBox(WorldPosition, 
									u_InverseView[3].xyz-(u_ShadowClipPlanes[Cascade]-Hash.x*0.55f),
									u_InverseView[3].xyz+(u_ShadowClipPlanes[Cascade]+Hash.x*0.5f));

			if (BoxCheck) 
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
	
	float Bias = 0.001f;

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

	return 1.0f - clamp(pow(Shadow, 1.44f), 0.0f, 1.0f);
}



void main() 
{	
	

	vec3 rO = u_InverseView[3].xyz;

	float Depth = texture(u_DepthTexture, v_TexCoords).x;

	if (Depth > 0.999999f) {
		o_Color = texture(u_Skymap, vec3(0.,1.,0.)).xyz;
		return;
	}

	vec3 WorldPosition = WorldPosFromDepth(Depth,v_TexCoords).xyz;
	vec3 Normal = normalize(texture(u_NormalTexture, v_TexCoords).xyz);
	
	vec3 GI = texture(u_Trace, v_TexCoords).xyz;;
	vec3 Albedo = texture(u_AlbedoTexture, v_TexCoords).xyz;

	vec3 Direct = Albedo * 8.0 * max(dot(Normal, -u_LightDirection),0.) * FilterShadows(WorldPosition, Normal);

	o_Color = Direct + GI * Albedo;
}