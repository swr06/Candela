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

		const float ARBITRARY_MAX = 10000000.0f;
		const float ARBITRARY_MIN = -10000000.0f;

		class Bounds {

		public :

			Bounds() : Min(glm::vec3(ARBITRARY_MAX)), Max(glm::vec3(ARBITRARY_MIN)) {}
			Bounds(const glm::vec3& min, const glm::vec3& max) : Min(glm::vec3(min)), Max(glm::vec3(max)) {}

			glm::vec3 Min;
			glm::vec3 Max;

			inline glm::vec3 GetCenter() const noexcept {
				return (Min + Max) / 2.0f;
			}

			inline glm::vec3 GetExtent() const noexcept {
				return Max - Min;
			}

			inline float GetArea() const noexcept {
				glm::vec3 Extent = GetExtent();
				return Extent.x * Extent.y + Extent.y * Extent.z + Extent.z * Extent.x;
			}
		};

		struct Node {
			Bounds NodeBounds;
			Bounds CentroidBounds;

			uint StartIndex;
			uint Length;
			
			uint NodeIndex;

			Node* LeftChildPtr = nullptr;
			Node* RightChildPtr = nullptr;

			bool IsLeftNode = false;
			bool IsLeafNode = false;

			uint Axis = 1000;
		};

		struct FBounds {
			glm::vec4 Min;
			glm::vec4 Max;
		};

		struct FlattenedNode
		{
			glm::vec4 Min;
			glm::vec4 Max;
		};

		struct Triangle {
			// 0, 1, 2 indices 
			// 3 mesh ID
			int Packed[4];
		};

		Node* BuildBVH(const Object& object, std::vector<FlattenedNode>& FlattenedNodes, std::vector<Vertex>& MeshVertices, std::vector<Triangle>& FlattenedTris);
	}
};