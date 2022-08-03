#version 330 core 

layout (location = 0) out vec3 o_Output;

in vec2 v_TexCoords;

uniform sampler2D u_Depth;
uniform sampler2D u_RefractDepth;
uniform sampler2D u_Normals;

uniform float u_zNear;
uniform float u_zFar;

uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_InverseProjection;
uniform mat4 u_InverseView;
uniform mat4 u_ViewProjection;

uniform float u_Time;
uniform int u_Frame;


const float INV_RES = 2;

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

vec3 ApproximateRefract(vec3 ViewSpacePosition, vec3 ViewSpacePositionUnderwater, vec3 ViewSpaceNormal, float ClipDepth) 
{
	float AirIdx = 1.00029f;
	float WaterIdx = 1.33333f;
	vec3 RefractedVector = normalize(refract(normalize(ViewSpacePosition), ViewSpaceNormal, AirIdx / WaterIdx));
	float RefractionAmount = distance(ViewSpacePosition, ViewSpacePositionUnderwater);
    vec3 ApproximateHitPosition = ViewSpacePosition + RefractedVector * RefractionAmount;
    vec3 HitCoordinate = ProjectToScreenSpace(ApproximateHitPosition);
    
	if(HitCoordinate.z < ClipDepth || HitCoordinate != clamp(HitCoordinate, 0.00001f, 0.99999f)) 
	{
		HitCoordinate.xy = v_TexCoords;
    }

	return HitCoordinate;
}

vec4 ScreenspaceRaytrace(const vec3 Origin, const vec3 Direction, const int Steps, const int BinarySteps, const float ThresholdMultiplier) {

    float TraceDistance = 48.0f;

    float StepSize = TraceDistance / Steps;

	vec2 Hash = hash2();
    vec3 RayPosition = Origin + Direction * Hash.x;

    vec3 FinalProjected = vec3(0.0f);
    float FinalDepth = 0.0f;

    bool FoundIntersection = false;
    int SkyHits = 0;

    for (int Step = 0 ; Step < Steps ; Step++) {

        vec3 ProjectedRayScreenspace = ProjectToClipSpace(RayPosition); 
		
		if(abs(ProjectedRayScreenspace.x) > 1.0f || abs(ProjectedRayScreenspace.y) > 1.0f || abs(ProjectedRayScreenspace.z) > 1.0f) 
		{
			return vec4(vec3(-1.0f),SkyHits>4);
		}
		
		ProjectedRayScreenspace.xyz = ProjectedRayScreenspace.xyz * 0.5f + 0.5f; 

		// Depth texture uses nearest filtering
        float DepthAt = texture(u_Depth, ProjectedRayScreenspace.xy).x; 

        if (DepthAt == 1.0f) {
            SkyHits += 1;
        }

		float CurrentRayDepth = LinearizeDepth(ProjectedRayScreenspace.z); 
		float Error = abs(LinearizeDepth(DepthAt) - CurrentRayDepth);

        if (Error < StepSize * ThresholdMultiplier * 8.0f && ProjectedRayScreenspace.z > DepthAt) 
		{

			vec3 BinaryStepVector = (Direction * StepSize) / 2.0f;
            RayPosition -= (Direction * StepSize) * 0.5f; // <- Step back a bit 
			    
            for (int BinaryStep = 0 ; BinaryStep < BinarySteps ; BinaryStep++) {
			    		
			    BinaryStepVector /= 2.0f;

			    vec3 Projected = ProjectToClipSpace(RayPosition); 
			    Projected = Projected * 0.5f + 0.5f;
                FinalProjected = Projected;

				// Depth texture uses nearest filtering
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

			Error = abs(LinearizeDepth(FinalDepth) - LinearizeDepth(FinalProjected.z));

			if (Error < StepSize * ThresholdMultiplier) {
				FoundIntersection = true; 
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
        return vec4(vec3(-1.0f), SkyHits>4);
    }

	float T = distance(RayPosition, Origin);

	vec3 Pos = Origin + Direction * T;

	if (distance(RayPosition, Pos) > 0.025f) {
		return vec4(vec3(-1.0f), SkyHits>4);
	}

    return vec4(FinalProjected.xy, FinalDepth == 1.0f ? -1.0f : T, FinalDepth == 1.0f ? 1.0f : float(SkyHits>4));
}

void main() {

	vec2 TexCoords = v_TexCoords;
	HASH2SEED = (TexCoords.x * TexCoords.y) * 64.0 * u_Time;

	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	ivec2 HighResPixel = Pixel * int(INV_RES);

	float Depth = texelFetch(u_RefractDepth, HighResPixel, 0).x;

	if (Depth > 0.999999999999f || Depth == 1.0f) {
		o_Output = vec3(v_TexCoords, -1.0f);
		return;
	}

	vec3 WorldPosition = WorldPosFromDepth(Depth, TexCoords);

	float OpaqueDepth = texelFetch(u_Depth, HighResPixel, 0).x;
	vec3 WorldPositionOpaque = (OpaqueDepth > 0.9999999999f || OpaqueDepth == 1.0f) ? vec3(100000.0f) : WorldPosFromDepth(OpaqueDepth, TexCoords);

	float Transversal = (OpaqueDepth > 0.9999999999f || OpaqueDepth == 1.0f) ? 1000.0f : distance(WorldPosition, WorldPositionOpaque);

	Transversal = clamp(Transversal, 0.0f, 32.0f);

	vec3 Normal = normalize(texelFetch(u_Normals, HighResPixel, 0).xyz);

	vec3 Player = u_InverseView[3].xyz;
	vec3 Incident = normalize(WorldPosition - Player);

	vec3 RefractedDirection = refract(Incident, Normal, 1.0f / 1.5f);

	vec4 Res = ScreenspaceRaytrace(WorldPosition, RefractedDirection, 10, 6, 0.0045f);

	if (Res.xy != clamp(Res.xy, 0.0f, 1.0f)) {
		
		vec3 ApproximateIntersection = WorldPosition + Transversal * RefractedDirection * 0.75f;

		vec3 Projected = ProjectToScreenSpace(ApproximateIntersection);

		if (Projected.xy != clamp(Projected.xy, 0.0f, 1.0f)) {

			Projected.xy = v_TexCoords;
			
		}

		Res.xy = Projected.xy;

	}

	o_Output = vec3(Res.xy, Res.z);
}