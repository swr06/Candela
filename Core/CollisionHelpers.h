#pragma once 

#include <iostream>

#include <array>

#include <glm/glm.hpp>

#include "AABB.h"

namespace Lumen
{
	struct CollisionQuery {
		glm::vec4 Min;
		glm::vec4 Max;
	};

	struct CollisionResult {
		glm::vec3 Normal;
		float Distance;
	};

	struct OBBProperties
	{
		glm::vec3 m_Origin;
		glm::vec3 m_X;
		glm::vec3 m_Y;
		glm::vec3 m_Z;
		std::array<glm::vec3, 8> m_Coordinates;
	};

	OBBProperties GetOBBProperties(const glm::mat4& Transform, const SimpleAABB& Bounds, const glm::vec3& PositionOffset);

}