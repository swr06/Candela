#pragma once 

#include <iostream>

#include "BVH/Intersector.h"

#include <glm/glm.hpp>

namespace Candela {

	namespace Physics {


		void CollidePoint(const glm::vec3& Point, RayIntersector<BVH::StackTraversalNode>& Intersector);
		bool CollideBox(const glm::vec3& Min, const glm::vec3& Max, RayIntersector<BVH::StacklessTraversalNode>& Intersector);

	}

}