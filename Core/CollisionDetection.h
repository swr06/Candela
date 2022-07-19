#pragma once 

#include <iostream>

#include <glm/glm.hpp>
#include <glm/gtc/epsilon.hpp>

#include "AABB.h"

#include "CollisionHelpers.h"

#include <optional>

namespace Lumen {

	namespace Physics {

		std::optional<CollisionResult> OBBTriangleCollision(const glm::mat4& Transform, SimpleAABB Bounds, glm::vec3 Vertices[3], const glm::vec3& TriangleOffset);
	}
}