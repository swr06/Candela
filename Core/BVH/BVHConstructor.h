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

		struct FlattenedBBox {
			glm::vec4 Min;
			glm::vec4 Max;
		};

		struct FlattenedNode {

			union {
			
				struct {
					FlattenedBBox bounds[2]; // 64 bytes
				}s0;
			
				struct
				{
					int StartIdx;
					int EndIdx;
					int PaddingT;
					int ChildA;
					int ShapeID;
					int PrimitiveID;
					int ChildB;
					int Padding[8]; // Pad to 64 bytes 
				}s1;
			};

		};

		Node* BuildBVH(Object& object, std::vector<FlattenedNode>& FlattenedNodes);
	}
};