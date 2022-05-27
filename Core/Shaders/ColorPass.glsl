#version 430 core
#define PI 3.14159265359

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_AlbedoTexture;
uniform sampler2D u_NormalTexture;
uniform sampler2D u_PBRTexture;
uniform sampler2D u_DepthTexture;
uniform sampler2D u_ShadowTexture;
uniform sampler2D u_BlueNoise;
uniform samplerCube u_Skymap;

uniform sampler2D u_Trace;

uniform vec3 u_ViewerPosition;
uniform vec3 u_LightDirection;
uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_LightVP;
uniform vec2 u_Dims;

uniform bool u_Mode;
uniform int u_x;

vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

vec3 GetRayDirectionAt(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}

float FilterShadows(vec3 WorldPosition, vec3 N)
{
	const vec2 PoissonDisk[32] = vec2[] ( vec2(-0.613392, 0.617481), vec2(0.751946, 0.453352), vec2(0.170019, -0.040254), vec2(0.078707, -0.715323), vec2(-0.299417, 0.791925), vec2(-0.075838, -0.529344), vec2(0.645680, 0.493210), vec2(0.724479, -0.580798), vec2(-0.651784, 0.717887), vec2(0.222999, -0.215125), vec2(0.421003, 0.027070), vec2(-0.467574, -0.405438), vec2(-0.817194, -0.271096), vec2(-0.248268, -0.814753), vec2(-0.705374, -0.668203), vec2(0.354411, -0.887570), vec2(0.977050, -0.108615), vec2(0.175817, 0.382366), vec2(0.063326, 0.142369), vec2(0.487472, -0.063082), vec2(0.203528, 0.214331), vec2(-0.084078, 0.898312), vec2(-0.667531, 0.326090), vec2(0.488876, -0.783441), vec2(-0.098422, -0.295755), vec2(0.470016, 0.217933), vec2(-0.885922, 0.215369), vec2(-0.696890, -0.549791), vec2(0.566637, 0.605213), vec2(-0.149693, 0.605762), vec2(0.039766, -0.396100), vec2(0.034211, 0.979980) );
	vec4 ProjectionCoordinates = u_LightVP * vec4(WorldPosition + N * 0.001f, 1.0f);
	ProjectionCoordinates.xyz = ProjectionCoordinates.xyz / ProjectionCoordinates.w; // Perspective division is not really needed for orthagonal projection but whatever
    ProjectionCoordinates.xyz = ProjectionCoordinates.xyz * 0.5f + 0.5f;
	float shadow = 0.0;

	if (ProjectionCoordinates.z > 1.0)
	{
		return 0.0f;
	}

    float ClosestDepth = texture(u_ShadowTexture, ProjectionCoordinates.xy).r; 
    float Depth = ProjectionCoordinates.z;
	float Bias = 0.0007f;//clamp(max(0.00025f * (1.0f - dot(N, u_LightDirection)), 0.0005f), 0.0001f, 0.005f);  
	vec2 TexelSize = 1.0 / textureSize(u_ShadowTexture, 0);
	float noise = texture(u_BlueNoise, v_TexCoords * (u_Dims / textureSize(u_BlueNoise, 0).xy)).r;
	float scale = 0.4;

    int Samples = 8;

	for(int x = 0; x < Samples; x++)
	{
		float theta = noise * (2.0f*PI);
		float cosTheta = cos(theta);
		float sinTheta = sin(theta);
		mat2 dither = mat2(vec2(cosTheta, -sinTheta), vec2(sinTheta, cosTheta));
		vec2 jitter_value;
		jitter_value = PoissonDisk[x] * dither;
		float pcf = texture(u_ShadowTexture, ProjectionCoordinates.xy + (jitter_value * scale * TexelSize)).r;  
		shadow += ProjectionCoordinates.z - 0.0001 > pcf ? 1.0f : 0.0f;
	}

	shadow /= float(Samples);
    return 1.-clamp(shadow,0.,1.);
}



void main() 
{	
	

	vec3 rD = normalize(GetRayDirectionAt(v_TexCoords).xyz);
	vec3 rO = u_InverseView[3].xyz;

	float Depth = texture(u_DepthTexture, v_TexCoords).x;

	if (Depth > 0.999999f) {
		o_Color = texture(u_Skymap, rD).xyz;
		return;
	}

	vec3 WorldPosition = WorldPosFromDepth(Depth,v_TexCoords).xyz;
	vec3 Normal = normalize(texture(u_NormalTexture, v_TexCoords).xyz);
	
	vec3 Reflection = texture(u_Trace, v_TexCoords).xyz;;
	vec3 Albedo = texture(u_AlbedoTexture, v_TexCoords).xyz;

	o_Color = (Albedo * 1.5f * FilterShadows(WorldPosition, Normal)) + (Albedo * mix(texture(u_Skymap, vec3(0.,1.,0.)).xyz,vec3(1.),0.5f) * 0.3f) + Reflection * 0.05;
	//o_Color = texture(u_Trace, v_TexCoords).xyz;
}