#pragma once 

#include <glm/glm.hpp>

#include "GLClasses/Shader.h"
#include "GLClasses/ComputeShader.h"

struct CommonUniforms {
	glm::mat4 View, Projection, InvView, InvProjection, PrevProj, PrevView, InvPrevProj, InvPrevView;
	int Frame;
	glm::vec3 SunDirection;
};

struct CommonUniformData 
{
   
    glm::mat4 u_ViewProjection;
    glm::mat4 u_Projection;
    glm::mat4 u_View;
    glm::mat4 u_InverseProjection;
    glm::mat4 u_InverseView;
    glm::mat4 u_PrevProjection;
    glm::mat4 u_PrevView;
    glm::mat4 u_PrevInverseProjection;
    glm::mat4 u_PrevInverseView;
    glm::mat4 u_InversePrevProjection;
    glm::mat4 u_InversePrevView;

    glm::vec4 u_Time;
    glm::vec4 u_ViewerPosition;
    glm::vec4 u_Incident;
    glm::vec4 u_SunDirection;
    glm::vec4 u_LightDirection;
    glm::vec4 u_zNear;
    glm::vec4 u_zFar;

    int u_Frame;
    int u_CurrentFrame;
};
