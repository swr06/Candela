#pragma once 

#include <iostream>

#include <glm/glm.hpp>

#include <glad/glad.h>

#include "BVH/Intersector.h"

namespace Lumen {

	namespace DDGI {

		void Initialize();

		void UpdateProbes(int Frame, RayIntersector<BVH::StacklessTraversalNode>& Intersector);
	}

}

