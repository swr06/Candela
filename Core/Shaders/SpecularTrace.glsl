#version 430 core 

#define PI 3.14159265359

#include "Include/Utility.glsl"
#include "Include/SpatialUtility.glsl"

layout(local_size_x = 16, local_size_y = 16) in;
layout(rgba16f, binding = 0) uniform image2D o_OutputData;

uniform sampler2D u_Depth;
uniform sampler2D u_HFNormals;
uniform sampler2D u_LFNormals;
uniform sampler2D u_PBR;
uniform sampler2D u_Albedo; 

uniform float u_Time;
uniform int u_Frame;

uniform vec2 u_Dimensions; 

uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_InverseProjection;
uniform mat4 u_InverseView;
uniform mat4 u_ViewProjection;

uniform vec3 u_SunDirection;

uniform float u_zNear;
uniform float u_zFar;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

vec3 ProjectToScreenSpace(vec3 WorldPos) 
{
	vec4 ProjectedPosition = u_ViewProjection * vec4(WorldPos, 1.0f);
	ProjectedPosition.xyz /= ProjectedPosition.w;
	ProjectedPosition.xyz = ProjectedPosition.xyz * 0.5f + 0.5f;
	return ProjectedPosition.xyz;
}

vec3 ProjectToClipSpace(vec3 WorldPos) 
{
	vec4 ProjectedPosition = u_ViewProjection * vec4(WorldPos, 1.0f);
	ProjectedPosition.xyz /= ProjectedPosition.w;
	return ProjectedPosition.xyz;
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

vec3 GGX_VNDF(vec3 N, float roughness, vec2 Xi)
{
    float alpha = roughness * roughness;
    float alpha2 = alpha * alpha;
	
    float phi = 2.0 * PI * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (alpha2 - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
	
    vec3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;
	
    vec3 up = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(up, N));
    vec3 bitangent = cross(N, tangent);
	
    vec3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
} 

vec3 StochasticReflectionDirection(vec3 Incident, vec3 Normal, float Roughness) {
    
    float NearestDot = -100.0f;

    bool FoundValid = false;

    const vec2 TailControl = vec2(0.8f, 0.7f); // <- get the ggx tail under control and reduce variance 

    vec3 Microfacet = Normal;

    for (int i = 0 ; i < 8 ; i++) {
        
        vec3 Sample = GGX_VNDF(Normal, Roughness, hash2() * TailControl);

        if (dot(Sample, Normal) > 0.001f) // <- sampling the vndf can actually generate directions that are away from the normal.
        {
            Microfacet = Sample;
        }
    }

    return reflect(Incident, Microfacet);
}

vec4 ScreenspaceRaytrace(const vec3 Origin, const vec3 Direction, const int Steps, const int BinarySteps) {

    float TraceDistance = 48.0f;

    float StepSize = TraceDistance / Steps;

    vec2 Hash = hash2();

    vec3 RayPosition = Origin + Direction * Hash.x;

    vec3 FinalProjected = vec3(0.0f);
    float FinalDepth = 0.0f;

    bool FoundIntersection = false;

    for (int Step = 0 ; Step < Steps ; Step++) {

        vec3 ProjectedRayScreenspace = ProjectToClipSpace(RayPosition); 
		
		if(abs(ProjectedRayScreenspace.x) > 1.0f || abs(ProjectedRayScreenspace.y) > 1.0f || abs(ProjectedRayScreenspace.z) > 1.0f) 
		{
			return vec4(-1.0f);
		}
		
		ProjectedRayScreenspace.xyz = ProjectedRayScreenspace.xyz * 0.5f + 0.5f; 

        float DepthAt = texture(u_Depth, ProjectedRayScreenspace.xy).x; 
		float CurrentRayDepth = LinearizeDepth(ProjectedRayScreenspace.z); 
		float Error = abs(LinearizeDepth(DepthAt) - CurrentRayDepth);

        if (Error < StepSize * 0.006f && ProjectedRayScreenspace.z > DepthAt) 
		{
            FoundIntersection = true; 

			vec3 BinaryStepVector = (Direction * StepSize) / 2.0f;
            RayPosition -= (Direction * StepSize) / 2.0f; // <- Step back a bit 
			    
            for (int BinaryStep = 0 ; BinaryStep < BinarySteps ; BinaryStep++) {
			    		
			    BinaryStepVector /= 2.0f;

			    vec3 Projected = ProjectToClipSpace(RayPosition); 
			    Projected = Projected * 0.5f + 0.5f;
                FinalProjected = Projected;

                float Fetch = texture(u_Depth, Projected.xy).x;
                FinalDepth = Fetch;

			    float BinaryDepthAt = LinearizeDepth(Fetch); 
			    float BinaryRayDepth = LinearizeDepth(Projected.z); 

			    if (BinaryDepthAt < BinaryRayDepth) 
                {
			    	RayPosition -= BinaryStepVector;
			    }

			    else
                {
			    	RayPosition += BinaryStepVector;
			    }
			}

            break;
        }

        if (ProjectedRayScreenspace.z > DepthAt) {  
            FoundIntersection = false;
            break;
        }

        RayPosition += StepSize * Direction;
    }

    if (!FoundIntersection) {
        return vec4(-1.0f);
    }

    return vec4(FinalProjected.xy, distance(RayPosition, Origin), FinalDepth);
}

void main() {
    
    ivec2 Pixel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 WritePixel = ivec2(gl_GlobalInvocationID.xy);

	if (Pixel.x < 0 || Pixel.y < 0 || Pixel.x > int(u_Dimensions.x) || Pixel.y > int(u_Dimensions.y)) {
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
    vec2 HighResUV = vec2(HighResPixel) / textureSize(u_Depth, 0).xy;

	// Fetch 
    float Depth = texelFetch(u_Depth, HighResPixel, 0).x;

	if (Depth > 0.999999f || Depth == 1.0f) {
		imageStore(o_OutputData, WritePixel, vec4(0.0f));
        return;
    }

    vec3 PBR = texelFetch(u_PBR, HighResPixel, 0).xyz;

	vec2 TexCoords = HighResUV;
	HASH2SEED = (TexCoords.x * TexCoords.y) * 64.0 * u_Time;

	const vec3 Player = u_InverseView[3].xyz;

	vec3 WorldPosition = WorldPosFromDepth(Depth, TexCoords);
	vec3 Normal = normalize(texelFetch(u_LFNormals, HighResPixel, 0).xyz);
	vec3 NormalHF = texelFetch(u_HFNormals, HighResPixel, 0).xyz;

	vec3 Incident = normalize(WorldPosition - Player);

    vec3 RayOrigin = WorldPosition + Normal * 0.05f;
    vec3 RayDirection = StochasticReflectionDirection(Incident, NormalHF, PBR.x * 0.0f);

    vec3 FinalRadiance = vec3(0.0f);
    float FinalTransversal = -1.0f;

    vec4 Screentrace = ScreenspaceRaytrace(RayOrigin, RayDirection, 20, 8);

    if (IsInScreenspace(Screentrace.xy) && Screentrace.z > 0.0f) {
        
        vec3 IntersectionPosition = RayOrigin + RayDirection * Screentrace.z;
        FinalTransversal = Screentrace.z;
        FinalRadiance = texture(u_Albedo, Screentrace.xy).xyz;
    }

    imageStore(o_OutputData, WritePixel, vec4(FinalRadiance, FinalTransversal));
}