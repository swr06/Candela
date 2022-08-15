#pragma once 

#include "glm/glm.hpp"

namespace Candela {

	class Plane {

	public :

		glm::vec3 Normal;
		float Distance;

		Plane() {

		}

		Plane(const glm::vec3& Point, const glm::vec3& PlaneNormal)
		{
			Normal = glm::normalize(PlaneNormal);
			Distance = glm::dot(Normal, Point);
		}

		float SDF(const glm::vec3& Point) const {
			
			float Dot = glm::dot(Point, Normal);
			return Dot - Distance;
		}
	};
}