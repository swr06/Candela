#version 330 core 

layout (location = 0) out vec2 o_SimpleMotionVector;
layout (location = 1) out vec2 o_SpecularMotionVector;

in vec2 v_TexCoords;

uniform sampler2D u_Depth;

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_PrevProjection;
uniform mat4 u_PrevView;

vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

void main() {

    float Depth = texture(u_Depth, v_TexCoords).x;
	vec3 WorldPosition = WorldPosFromDepth(Depth, v_TexCoords).xyz;

    vec4 ProjectedPosition = u_PrevProjection * u_PrevView * vec4(WorldPosition, 1.0f);
	ProjectedPosition.xyz /= ProjectedPosition.w;
    ProjectedPosition.xyz = ProjectedPosition.xyz * 0.5f + 0.5f;

    o_SimpleMotionVector = vec2(-1.5f);

    if (ProjectedPosition.x > 0.0f && ProjectedPosition.x < 1.0f && ProjectedPosition.y > 0.0f && ProjectedPosition.y < 1.0f) 
    {
        o_SimpleMotionVector = ProjectedPosition.xy - v_TexCoords;
    }

}