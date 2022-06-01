#pragma once 

#include <iostream>

#include <glm/glm.hpp>

#include <glad/glad.h>

#include "BVH/Intersector.h"

#include "Utility.h"

#include "FpsCamera.h"

#include "ShadowMapHandler.h"

namespace Lumen {

	namespace DDGI {

		void Initialize();

		void UpdateProbes(int Frame, RayIntersector<BVH::StacklessTraversalNode>& Intersector, CommonUniforms& uniforms);
		glm::vec3 GetProbeGridSize();
		glm::vec3 GetProbeGridRes();
		glm::vec3 GetProbeBoxOrigin();
		GLuint GetVolume();
	}

}

