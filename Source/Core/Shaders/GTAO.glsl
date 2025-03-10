#version 430 core

#define TAU 1.570796326
#define PI (TAU*2.)
#define GOLDEN_R (0.61803398875)

layout (location = 0) out float o_AO;
layout (location = 1) out vec4 o_GI;

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

uniform sampler2D u_AlbedoTexture;
uniform sampler2D u_PrevLighting;


uniform mat4 u_ShadowMatrices[5]; // <- shadow matrices 
uniform sampler2DShadow u_ShadowTextures[5]; // <- the shadowmaps themselves 
uniform float u_ShadowClipPlanes[5]; // <- world space clip distances 

uniform float u_Aspect;

uniform int u_Width;
uniform int u_Height;

uniform int u_Frame;




const float MAX_ITERATIONS = 5.0f;
const int HORIZON_STEPS = 6;

const float RADIUS = 1.f; // Radius of affecting 
const float MULTIPLIER = 0.01f; 
const float DEPTH_TOLERANCE = 0.35f; // Adjust for thin geometry 
const float STEP_VECTOR_MUL = 0.9f ;
const float COSINE = 0.1f;

const float DEPTH_TOLERANCE_IR = 1.8f;
const float MULTIPLIER_IR = 0.5;
const float RADIUS_IR = 3.7f;

// function by mirko
vec2 SampleSliceDir(vec3 vvsN, float rnd01)
{
    float ang0 = rnd01 * PI;
    vec2 dir0 = vec2(cos(ang0), sin(ang0));
    float l = length(vvsN.xy);
    if(l == 0.0) return dir0;
    dir0 *= dot(dir0, vvsN.xy) < 0.0 ? -1.0 : 1.0;
    vec2 n = vvsN.xy / l;
    vec2 dir;
    {
        float x = dir0.x * n.y - dir0.y * n.x;
        float s = l;
        {
            s += (s - s * s) * 0.15;
        }
        float k = 0.21545;
        float xs;
        {
            float a = 0.5 + 0.5 / k;
            float b = 0.5 - 0.5 / k;
            float d = b * b;
            float c = 4.0 / k;
            xs = 0.5 - 0.5 * s;
            xs = a - sqrt(d + c * (xs*xs));
        }
        
        x *= xs;
        float y;
        {
            float v = x > 0.0 ? 2.0 : 0.0;
            float g = -k - 1.0;
            float u = (abs(x) * k + g) * abs(x) + 1.0;
            y = abs(v - sqrt(clamp(u, 0.0, 1.0)));        
        }
        
        float ys = 1.0 / s;// remap curve along y
        
        dir.y = ys - ys * y;// [-1, 1]
        dir.x = sqrt(clamp(1.0 - dir.y*dir.y, 0.0, 1.0));// [0, 1]
    }    
    
	return vec2(dir.x * n.x - dir.y * n.y, 
		        dir.y * n.x + dir.x * n.y);
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

vec3 ViewPosFromDepthBiased(float depth, vec2 txc, vec3 N)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return (u_View * vec4(WorldPos.xyz + N * 0.05f, 1.)).xyz;
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

float IntegrateArcForIrradiance(vec2 sliceNormal, vec2 cosTheta) {
	vec2 theta = vec2(ACosFit(cosTheta.x), ACosFit(cosTheta.y));
	vec2 sinTheta = sqrt(1.0 - (cosTheta*cosTheta));
	float x = theta[1] - theta[0] + sinTheta[0] * cosTheta[0] - sinTheta[1] * cosTheta[1];
	float y = (cosTheta[0]*cosTheta[0]) - (cosTheta[1]*cosTheta[1]);
	return dot(sliceNormal, vec2(x, y)) * 0.5;
}


uint countBits(uint value) {
    value = value - ((value >> 1u) & 0x55555555u);
    value = (value & 0x33333333u) + ((value >> 2u) & 0x33333333u);
    return ((value + (value >> 4u) & 0xF0F0F0Fu) * 0x1010101u) >> 24u;
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



float SampleShadowMap(vec3 SampleUV, int Map) {

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

float GetDirectShadow(vec3 WorldPosition, vec3 N)
{
	int ClosestCascade = -1;
	float Shadow = 0.0;
	float VogelScales[5] = float[5](0.001f, 0.0015f, 0.002f, 0.00275f, 0.00325f);
	
	vec2 TexelSize = 1.0 / textureSize(u_ShadowTextures[ClosestCascade], 0);

	vec4 ProjectionCoordinates;

	float HashBorder = 1.0f; 

	for (int Cascade = 2 ; Cascade < 4; Cascade++) {
	
		ProjectionCoordinates = u_ShadowMatrices[Cascade] * vec4(WorldPosition + N * 0.035f, 1.0f);

		if (ProjectionCoordinates.z < 1.0f && abs(ProjectionCoordinates.x) < 1.0f && abs(ProjectionCoordinates.y) < 1.0f)
		{
			//bool BoxCheck = IsInBox(WorldPosition, 
			//						u_InverseView[3].xyz-(u_ShadowClipPlanes[Cascade]),
			//						u_InverseView[3].xyz+(u_ShadowClipPlanes[Cascade]));
			//
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
	
	float Bias = 0.00002f;
	vec2 SampleUV = ProjectionCoordinates.xy;
	Shadow = SampleShadowMap(vec3(SampleUV, ProjectionCoordinates.z - Bias), ClosestCascade); 
	return Shadow;
}

vec3 GetLightingAt(vec2 T) {
    return texture(u_PrevLighting,T).xyz;
    float Depth = texture(u_DepthTexture, T).x;
    vec3 Position = WorldPosFromDepth(Depth,T);
    vec3 Normal = texture(u_NormalTexture, T).xyz;
    float Shadow = GetDirectShadow(Position,Normal);
    vec3 Albedo = texture(u_AlbedoTexture, T).xyz;
    return Albedo * Shadow * 12.0f;
}

vec3 GetNAt(vec2 T) {
	mat3 normalMatrix = transpose(inverse(mat3(u_View))); // Use if u_View contains scaling
    vec3 Normal = normalize(normalMatrix * texture(u_NormalTexture, T).xyz);
    return Normal;
}


void main() {
    float ITERATIONS = MAX_ITERATIONS;
    vec2 TexCoords = v_TexCoords;

    HASH2SEED = u_Time;
    HASH2SEED += (v_TexCoords.x * v_TexCoords.y) * 64.0;
	
    float Depth = texture(u_DepthTexture, v_TexCoords).x;

	mat3 normalMatrix = transpose(inverse(mat3(u_View))); // Use if u_View contains scaling
    vec3 WorldSpaceNormal = texture(u_NormalTexture, v_TexCoords).xyz;
    vec3 Normal = normalize(normalMatrix * WorldSpaceNormal);
    vec3 ViewPosition = ViewPosFromDepth(Depth, TexCoords);
    vec3 ViewDirection = normalize(-ViewPosition);

    float DistanceScale = 1. - clamp(-ViewPosition.z / 100.0f,0.0,1.);
    DistanceScale *= DistanceScale;
    DistanceScale *= DistanceScale;
    DistanceScale *= DistanceScale;
    DistanceScale *= DistanceScale;
    DistanceScale *= DistanceScale;

    DistanceScale = min(12.+DistanceScale*14., 19.);

    float BaseBayer = Bayer(ivec2(gl_FragCoord.xy),5);
    vec2 HFNoise = texture(u_BlueNoise, fract(vec2(gl_FragCoord.xy)/textureSize(u_BlueNoise,0).xy)).xy;//hash2()*0.99 + 0.01f;
    HFNoise = fract(HFNoise + (GOLDEN_R * float(u_Frame & 63)));
    
    float Offset = (PI / ITERATIONS);
    float SliceAngle = Offset * HFNoise.x;

    vec3 TangentX = normalize(cross(vec3(0.0, 1.0, 0.0), ViewDirection));
    vec3 TangentY = cross(ViewDirection, TangentX);
    mat3 TangentToView = mat3(TangentX, TangentY, ViewDirection);
    vec3 Irradiance = vec3(0.0f);

    float Sum = 0.0f;
    for (int i = 0 ; i < int(ITERATIONS) ; i++) {

        // Choose a slice on the hemisphere 
        //vec3 SliceDirection = vec3(cos(SliceAngle), sin(SliceAngle), 0.0f);
        float HashBL = fract(HFNoise.x + (GOLDEN_R * (i+1)));
        //vec3 SliceDirection = vec3(SampleSliceDir(Normal, HashBL), 0.0f);
        vec3 SliceDirection = vec3(cos(SliceAngle), sin(SliceAngle), 0.0f);

        vec2 MarchDirection = SliceDirection.xy / vec2(u_Width,u_Height);
        MarchDirection *= DistanceScale;
        
        vec3 ViewSliceDir = TangentToView * SliceDirection;
        vec2 SliceNormal = Normal * mat2x3(ViewSliceDir, ViewDirection);

        // Find tangent and bitangents and project the normal to that plane 
        vec3 Tangent = SliceDirection - (dot(SliceDirection, ViewDirection) * ViewDirection);
        vec3 Bitangent = normalize(cross(Tangent, ViewDirection));
        vec3 NormalProjected = Normal - Bitangent * dot(Normal, Bitangent);
        float ProjectedLength = length(NormalProjected);

        // Cosine of N
        float NDotV = clamp(dot(NormalProjected, ViewDirection) / ProjectedLength, 0.0f, 1.0f);
        float NAngle = sign(dot(Tangent, NormalProjected)) * ACosFit(NDotV);

        // Maximum and minimum possible cosines 
        float Maximum = cos(NAngle + TAU);
        float Minimum = cos(NAngle - TAU);
        
        // Cosine of the left and right horizon angles 
        float HCos[2] = float[](-1.0, -1.0);
        float HCosIrr[2] = float[](-1.0, -1.0);
        vec2 SampleCoordinate[2] = vec2[](TexCoords, TexCoords);

        // Explore to find horizon angles 
        // In both directions around the current angle 

        for (int k = 0; k < 2; k++) {

            float ExponentialStep = 1.0f;
            
            for (int st = 0; st < HORIZON_STEPS; st++) {

                vec2 CurrSNormal = SliceNormal * vec2(float(1-2*k),1.);
                SampleCoordinate[k] += float(1-2*k) * MarchDirection * ExponentialStep * HFNoise.y;
                
                if (SampleCoordinate[k].x < 0.0f || SampleCoordinate[k].x >= 1. || 
                    SampleCoordinate[k].y < 0.0f || SampleCoordinate[k].y >= 1.) {
                    break;
                }

                // Sample at position
                float DepthAt = texture(u_DepthTexture,SampleCoordinate[k]).x;
                vec3 VP = GetViewPositionUV(SampleCoordinate[k]);
                vec3 Delta = VP - ViewPosition;

                // Weighting function
                float SampleWeight = clamp((length(vec3(Delta.xy, Delta.z*(1+DEPTH_TOLERANCE))))
                                     * (-1.0/(MULTIPLIER*RADIUS)) + ((RADIUS * (1.0-MULTIPLIER)) / (MULTIPLIER*RADIUS)+1.0), 0.0f, 1.0f);
                float CurrentCos = mix(mix(Minimum, Maximum, float(k==0)), dot(normalize(Delta), ViewDirection), SampleWeight);
                float SampleWeightIrr = clamp((length(vec3(Delta.xy, Delta.z*(1+DEPTH_TOLERANCE_IR)))) 
                      * (-1.0/(MULTIPLIER_IR*RADIUS_IR)) + ((RADIUS_IR * (1.0-MULTIPLIER_IR)) / (MULTIPLIER_IR*RADIUS_IR)+1.0), 0.0f, 1.0f);
                float CurrentCosIrr = mix(mix(Minimum, Maximum, float(k==0)), dot(normalize(Delta), ViewDirection), SampleWeightIrr);
                
                // Assume contribution from current arc and use integral as weight
                // (from https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf)
                float IntegralWeight = IntegrateArcForIrradiance(CurrSNormal, vec2(CurrentCosIrr, HCosIrr[k]));
                
                Irradiance += max(IntegralWeight,0.) * GetLightingAt(SampleCoordinate[k]) * float(CurrentCosIrr>HCosIrr[k]);

                HCos[k] = max(CurrentCos, HCos[k]);
                HCosIrr[k] = max(CurrentCosIrr, HCosIrr[k]);

                ExponentialStep *= 1.3f;
            }
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

    Irradiance *= PI;

    o_AO = Sum / ITERATIONS;
    Irradiance = Irradiance / ITERATIONS;
    o_AO = pow(o_AO, 1.4f);
    o_GI = vec4(vec3(max(Irradiance,0.)),o_AO);
    if (any(isnan(o_GI))) {
        o_GI = vec4(0.0);
    }
}