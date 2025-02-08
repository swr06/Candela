#version 430 core

#define TAU 1.570796326
#define PI (TAU*2.)
#define GOLDEN_R (0.61803398875)

#include "Include/Utility.glsl"

layout (location = 0) out float o_AO;

in vec2 v_TexCoords;

uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_InverseProjection;
uniform mat4 u_InverseView;
uniform mat4 u_ViewProjection;

uniform float u_zNear;
uniform float u_zFar;

uniform float u_Time;

uniform sampler2D u_DepthTexture;
uniform sampler2D u_NormalTexture;
uniform sampler2D u_BlueNoise;


uniform float u_Aspect;

uniform int u_Width;
uniform int u_Height;

uniform int u_Frame;

uniform mat4 u_ShadowMatrices[5]; // <- shadow matrices 
uniform sampler2D u_ShadowTextures[5]; // <- the shadowmaps themselves 
uniform float u_ShadowClipPlanes[5]; // <- world space clip distances 


// Settings 
const float RADIUS = 1.5f; // Radius of affecting 
const float MULTIPLIER = 0.2f; 
const float DEPTH_TOLERANCE = 0.6f; // Adjust for thin geometry 
const float MAX_ITERATIONS = 2.0f;
const int HORIZON_STEPS = 6;
const float STEP_VECTOR_MUL = 0.9f ;
const float COSINE = 0.1f;



vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

vec3 ViewPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    return ViewSpacePosition.xyz;
}

vec3 GetViewPositionUV(vec2 txc) {
    float depth = texture(u_DepthTexture, txc).x;
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    return ViewSpacePosition.xyz;
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

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

float ACosFit(float x)
{
    float res = -0.156583 * abs(x) + TAU;
    res *= sqrt(1.0 - abs(x));
    return x >= 0 ? res : PI - res;
}

float HASH2SEED = 0.0f;
vec2 hash2() 
{
	return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

float IntegrateArc(float NDotV, float h, float NAngle) {
    return 0.25f*(NDotV+2.0f*h*sin(NAngle)-cos(2.0f*h-NAngle));
}



float Bayer(ivec2 pxx, uint level) // level = 5 since 2^5 -> max no of bits in uint
{
    uvec2 p = uvec2(pxx);
    p = (p ^ (p << 8)) & 0x00ff00ffu;
    p = (p ^ (p << 4)) & 0x0f0f0f0fu;
    p = (p ^ (p << 2)) & 0x33333333u;
    p = (p ^ (p << 1)) & 0x55555555u; 
    uint i = (p.x ^ p.y) | (p.x << 1u);    
    i = ((i & 0xaaaaaaaau) >> 1) | ((i & 0x55555555u) << 1);
    i = ((i & 0xccccccccu) >> 2) | ((i & 0x33333333u) << 2);
    i = ((i & 0xf0f0f0f0u) >> 4) | ((i & 0x0f0f0f0fu) << 4);
    i = ((i & 0xff00ff00u) >> 8) | ((i & 0x00ff00ffu) << 8);
    i = (i >> 16) | (i << 16);
    return float(i >> (32u - (2u * level))) / float(1 << (2u * level));
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

float GetDirectShadow(vec3 WorldPosition, vec3 N)
{
	int ClosestCascade = -1;
	float Shadow = 0.0;
	float VogelScales[5] = float[5](0.001f, 0.0015f, 0.002f, 0.00275f, 0.00325f);
	
	vec2 TexelSize = 1.0 / textureSize(u_ShadowTextures[ClosestCascade], 0);

	vec4 ProjectionCoordinates;

	float HashBorder = 1.0f; 

	for (int Cascade = 0 ; Cascade < 4; Cascade++) {
	 
		ProjectionCoordinates = u_ShadowMatrices[Cascade] * vec4(WorldPosition + N * 0.035f, 1.0f);

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
	
	float Bias = 0.00001f;
	vec2 SampleUV = ProjectionCoordinates.xy;
	Shadow = float(ProjectionCoordinates.z - Bias > SampleShadowMap(SampleUV, ClosestCascade)); 
	return 1.0f - Shadow;
}

vec3 GetDirect(in vec3 WorldPosition, in vec3 Normal, in vec3 Albedo) {

	float Shadow = GetDirectShadow(WorldPosition, Normal);
	return vec3(Albedo) * vec3(1.0f) * Shadow * clamp(dot(Normal, -u_SunDirection), 0.0f, 1.0f);
}


void main() {

    float ITERATIONS = MAX_ITERATIONS;
    vec2 TexCoords = v_TexCoords;

    HASH2SEED = u_Time;
    HASH2SEED += (v_TexCoords.x * v_TexCoords.y) * 64.0;
	
    float Depth = texture(u_DepthTexture, v_TexCoords).x;

	vec3 Normal = normalize(vec3(u_View * vec4(texture(u_NormalTexture, v_TexCoords).xyz, 0.)));
    
    o_AO = GetDirectShadow(WorldPosFromDepth(Depth, v_TexCoords), Normal, vec3(1.0)).x;
    
    vec3 ViewPosition = ViewPosFromDepth(Depth, TexCoords);
    vec3 ViewDirection = normalize(-ViewPosition);

    float BaseBayer = Bayer(ivec2(gl_FragCoord.xy),5);
    vec2 HFNoise = texture(u_BlueNoise, fract(vec2(gl_FragCoord.xy)/textureSize(u_BlueNoise,0).xy)).xy;//hash2()*0.99 + 0.01f;
    HFNoise = fract(HFNoise + (GOLDEN_R * float(u_Frame & 63)));
    
    float Offset = (PI / ITERATIONS);
    float SliceAngle = Offset * HFNoise.x;
    float StepSizeSS = (7.0f*STEP_VECTOR_MUL)/float(u_Width);

    float Sum = 0.0f;
    for (int i = 0 ; i < int(ITERATIONS) ; i++) {

        // Choose a slice on the hemisphere 
        vec3 SliceDirection = vec3(cos(SliceAngle), sin(SliceAngle), 0.0f);
        vec2 MarchDirection = SliceDirection.xy * vec2(1.0f, 1.0f) * StepSizeSS  * (0.002f + 0.998f * pow(HFNoise.y,(1+COSINE)));
        
        // Find tangent and bitangents and project the normal to that plane 
        vec3 Tangent = SliceDirection - (dot(SliceDirection, ViewDirection) * ViewDirection);
        vec3 Bitangent = normalize(cross(Tangent, ViewDirection));
        vec3 NormalProjected = Normal - Bitangent * dot(Normal, Bitangent);
        float ProjectedLength = length(NormalProjected);

        float NDotV = clamp(dot(NormalProjected, ViewDirection) / ProjectedLength, 0.0f, 1.0f);
        float NAngle = sign(dot(Tangent, NormalProjected)) * ACosFit(NDotV);

        // Maximum and minimum possible cosines 
        float Maximum = cos(NAngle + TAU);
        float Minimum = cos(NAngle - TAU);
        
        // Cosine of the left and right horizon angles 
        float HCos[2] = float[](-1.0, -1.0);
        vec2 SampleCoordinate[2] = vec2[](TexCoords, TexCoords);

        // Explore to find horizon angles 
        float ExponentialStep = 1.0f;
        for (int st = 0; st < HORIZON_STEPS; st++) {
            float Noise = hash2().x;

            // 2 sides 
            for (int k = 0; k < 2; k++) {
                SampleCoordinate[k] += float(1-2*k) * MarchDirection * ExponentialStep * vec2(1.0f, u_Aspect);
                vec3 VP = GetViewPositionUV(SampleCoordinate[k]);
                vec3 Delta = VP - ViewPosition;
                float SampleWeight = clamp((length(vec3(Delta.xy, Delta.z*(1+DEPTH_TOLERANCE))))
                                     * (-1.0/(MULTIPLIER*RADIUS)) + ((RADIUS * (1.0-MULTIPLIER)) / (MULTIPLIER*RADIUS)+1.0), 0.0f, 1.0f);
                float CurrentCos = mix(mix(Minimum, Maximum, float(k==0)), dot(normalize(Delta), ViewDirection), SampleWeight);
                HCos[k] = max(HCos[k],CurrentCos);
            }
            ExponentialStep *= 1.5;
        }

         // Find horizon angles
         float HorizonAngleLeft = -ACosFit(float(HCos[1]));
         float HorizonAngleRight = ACosFit(float(HCos[0]));

         // Clamp horizons so that it doesnt sample out of a semicircle 
         HorizonAngleLeft = NAngle + clamp(HorizonAngleLeft-NAngle, -TAU, TAU);
         HorizonAngleRight = NAngle + clamp(HorizonAngleRight-NAngle, -TAU, TAU);

         Sum += ProjectedLength * (IntegrateArc(NDotV, HorizonAngleLeft, NAngle)+IntegrateArc(NDotV, HorizonAngleRight, NAngle));
         SliceAngle += PI / ITERATIONS;
    }

    o_AO = Sum / ITERATIONS;
    o_AO = pow(o_AO, 1.0f);
}