#pragma once

/*

VERY WIP !

*/

#include <iostream>
#include <vector>

#include <cmath>

#include <glm/glm.hpp>

#include "../Utils/Vertex.h"

#include "../Object.h"

namespace Lumen {
	namespace BVH {
		typedef uint32_t uint;

		const float ARBITRARY_MAX = 1000000.0f;
		const float ARBITRARY_MIN = -1000000.0f;

		class Bounds {

		public :

			Bounds() : Min(glm::vec3(ARBITRARY_MAX)), Max(glm::vec3(ARBITRARY_MIN)) {}
			Bounds(const glm::vec3& min, const glm::vec3& max) : Min(glm::vec3(min)), Max(glm::vec3(max)) {}

			glm::vec3 Min;
			glm::vec3 Max;

			glm::vec3 GetCenter() {
				return (Min + Max) / 2.0f;
			}

			glm::vec3 GetExtent() {
				return Max - Min;
			}
		};

		struct Node {
			Bounds NodeBounds;

			uint StartIndex;
			uint Length;
			
			uint NodeIndex;

			Node* LeftChildPtr = nullptr;
			Node* RightChildPtr = nullptr;

			bool IsLeftNode = false;
			bool IsLeafNode = false;

			uint Axis = 1000;
		};

		struct FlattenedNode {
			glm::vec4 Min;
			glm::vec4 Max;
			uint StartIdx;
			uint TriangleCount;
			uint Axis;
			uint SecondChildOffset;
		};

		struct FVertex {
			glm::vec4 position;
		};

		struct Triangle 
		{
			FVertex v0, v1, v2;

			inline glm::vec3 GetCentroid() const noexcept {
				return (glm::vec3(v0.position) + glm::vec3(v1.position) + glm::vec3(v2.position)) / 3.0f;
			}

			inline Bounds GetBounds() const noexcept {
				glm::vec3 min, max;
				min.x = glm::min(glm::min(v0.position.x, v1.position.x), v2.position.x);
				min.y = glm::min(glm::min(v0.position.y, v1.position.y), v2.position.y);
				min.z = glm::min(glm::min(v0.position.z, v1.position.z), v2.position.z);

				max.x = glm::max(glm::max(v0.position.x, v1.position.x), v2.position.x);
				max.y = glm::max(glm::max(v0.position.y, v1.position.y), v2.position.y);
				max.z = glm::max(glm::max(v0.position.z, v1.position.z), v2.position.z);

				return Bounds(min, max);
			}
		};

		Node* BuildBVH(Object& object, std::vector<Triangle>& Triangles, std::vector<FlattenedNode>& FlattenedNodes);
	}
};