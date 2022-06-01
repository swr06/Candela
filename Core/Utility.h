#pragma once 

#include <glm/glm.hpp>

#include "GLClasses/Shader.h"
#include "GLClasses/ComputeShader.h"

struct CommonUniforms {
	glm::mat4 View, Projection, InvView, InvProjection, PrevProj, PrevView, InvPrevProj, InvPrevView;
	int Frame;
	glm::vec3 SunDirection;
};


