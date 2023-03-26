#version 430 core

#include "Include/Utility.glsl"

layout (location = 0) out vec2 o_SimpleMotionVector;
layout (location = 1) out vec2 o_SpecularMotionVector;

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

uniform sampler2D u_Depth;


vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

vec3 Reprojection(vec3 WorldPos) 
{
	vec4 ProjectedPosition = u_PrevProjection * u_PrevView * vec4(WorldPos, 1.0f);
	ProjectedPosition.xyz /= ProjectedPosition.w;
	ProjectedPosition.xyz = ProjectedPosition.xyz * 0.5f + 0.5f;
	return ProjectedPosition.xyz;
}

vec3 GetIncident(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}

void main() {

    ivec2 Pixel = ivec2(gl_FragCoord.xy);
    float Depth = texelFetch(u_Depth, Pixel, 0).x;
	vec3 WorldPosition = WorldPosFromDepth(Depth, v_TexCoords).xyz;

    vec2 Projected = vec2(-1.0f);

    if (!IsSky(Depth)) {

        vec4 ProjectedPosition = u_PrevProjection * u_PrevView * vec4(WorldPosition, 1.0f);
	    ProjectedPosition.xyz /= ProjectedPosition.w;
        ProjectedPosition.xyz = ProjectedPosition.xyz * 0.5f + 0.5f;

        Projected = ProjectedPosition.xy;
    }
    
    else {
        
        // Generate sky motion vector 

        vec3 IncidentVector = GetIncident(v_TexCoords);
        IncidentVector = normalize(IncidentVector);

        vec3 ReprojectedPlane = Reprojection(u_InverseView[3].xyz + (IncidentVector * 64.0f));

        Projected.xy = ReprojectedPlane.xy;
        
    }

    o_SimpleMotionVector = vec2(-1.5f);

    if (Projected.x > 0.0f && Projected.x < 1.0f && Projected.y > 0.0f && Projected.y < 1.0f) 
    {
        o_SimpleMotionVector = Projected.xy - v_TexCoords;
    }

}