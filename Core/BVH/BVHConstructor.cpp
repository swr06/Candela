#include "BVHConstructor.h"

#include <stack>
#include <queue>

namespace Lumen {
	namespace BVH {

		static uint64_t TotalIterations = 0;
		static uint32_t LastIndex = 0;

		inline glm::vec3 Vec3Min(const glm::vec3& a, const glm::vec3& b) {
			return glm::vec3(glm::min(a.x, b.x), glm::min(a.y, b.y), glm::min(a.z, b.z));
		}

		inline glm::vec3 Vec3Max(const glm::vec3& a, const glm::vec3& b) {
			return glm::vec3(glm::max(a.x, b.x), glm::max(a.y, b.y), glm::max(a.z, b.z));
		}

		inline bool ShouldBeLeaf(uint Length) {
			return Length <= 4;
		}

		int FindLongestAxis(const Bounds& bounds) {
			glm::vec3 Diff = bounds.Max - bounds.Min;

			float Max = glm::max(glm::max(Diff.x, Diff.y), Diff.z);

			if (Max == Diff.x) { return 0; }
			if (Max == Diff.y) { return 1; }
			if (Max == Diff.z) { return 2; }
			
			throw "What";
			
			return 0;
		}

		uint BuildNodes(std::vector<Triangle>& Triangles, Node* RootNode) {

			std::queue<Node*> NodeStack;

			NodeStack.push(RootNode);

			while (!NodeStack.empty()) {

				std::cout << "\nProcess index : " << LastIndex;

				Node* node = NodeStack.front();
				NodeStack.pop();

				TotalIterations++;
				uint StartIndex = node->StartIndex;
				uint EndIndex = node->Length + StartIndex;
				uint Length = EndIndex - StartIndex;

				bool IsLeaf = ShouldBeLeaf(Length);

				if (IsLeaf) {
					node->LeftChild = 0;
					node->LeftChildPtr = nullptr;
					node->RightChild = 0;
					node->RightChildPtr = nullptr;
					node->IsLeafNode = true;
					std::cout << "\n\n\n\n\nLEAF OML!\n\n\n\n";
					throw "yay";
					continue;
				}

				else {

					// Create 2 new nodes 

					Node* LeftNodePtr = new Node;
					Node& LeftNode = *LeftNodePtr;
					LastIndex++;
					node->LeftChild = LastIndex;
					node->LeftChildPtr = LeftNodePtr;
					LeftNode.NodeIndex = node->LeftChild;

					Node* RightNodePtr = new Node;
					Node& RightNode = *RightNodePtr;
					LastIndex++;
					node->RightChild = LastIndex;
					node->RightChildPtr = RightNodePtr;
					RightNode.NodeIndex = node->RightChild;

					int LongestAxis = FindLongestAxis(node->NodeBounds);
					float Border = node->NodeBounds.GetCenter()[LongestAxis];

					Bounds LeftNodeBounds;
					Bounds RightNodeBounds;

					// Split based on spatial median 

					uint LeftIndexItr = StartIndex;
					uint RightIndexItr = EndIndex;
					uint FirstTriangleIndex = 0;

					// Split/Sort triangles into 2 sets 
					// One for the left node and one for the right node
					while (LeftIndexItr < RightIndexItr) {

						// Forward iteration
						while (LeftIndexItr < RightIndexItr) {

							Triangle& CurrentTriangle = Triangles[LeftIndexItr];

							if (CurrentTriangle.v0.position[LongestAxis] > Border &&
								CurrentTriangle.v1.position[LongestAxis] > Border &&
								CurrentTriangle.v2.position[LongestAxis] > Border) {

								break;
							}

							FirstTriangleIndex++;
							LeftIndexItr++;
						}

						// Backward iteration
						while (LeftIndexItr < RightIndexItr) {

							Triangle& CurrentTriangle = Triangles[RightIndexItr];

							if (CurrentTriangle.v0.position[LongestAxis] <= Border &&
								CurrentTriangle.v1.position[LongestAxis] <= Border &&
								CurrentTriangle.v2.position[LongestAxis] <= Border) {

								break;
							}

							RightIndexItr--;
						}

						// Swap triangles
						if (LeftIndexItr < RightIndexItr) {

							Triangle Temp = Triangles[LeftIndexItr];
							Triangles[LeftIndexItr] = Triangles[RightIndexItr];
							Triangles[RightIndexItr] = Temp;

						}


					}


					// Set node properties 

					LeftNode.StartIndex = node->StartIndex;
					LeftNode.Length = FirstTriangleIndex;
					LeftNode.LeftChild = 0;
					LeftNode.RightChild = 0;
					LeftNode.ParentNode = node->NodeIndex;
					LeftNode.IsLeftNode = true;

					// 

					node->SplitAxis = LongestAxis;

					// Find bounding boxes 

					// Left node bounding box 
					glm::vec3 LeftMin = glm::vec3(10000.0f);
					glm::vec3 LeftMax = glm::vec3(-10000.0f);

					for (int i = LeftNode.StartIndex; i < LeftNode.StartIndex + LeftNode.Length; i++)
					{
						Bounds CurrentBounds = Triangles.at(i).GetBounds();
						LeftMin = Vec3Min(CurrentBounds.Min, LeftMin);
						LeftMax = Vec3Max(CurrentBounds.Max, LeftMax);
					}

					LeftNode.NodeBounds = Bounds(LeftMin, LeftMax);

					// Initialize right node
					RightNode.LeftChild = 0;
					RightNode.RightChild = 0;
					RightNode.StartIndex = node->StartIndex + FirstTriangleIndex;
					RightNode.Length = node->Length - FirstTriangleIndex;
					RightNode.ParentNode = node->NodeIndex;
					RightNode.IsLeftNode = false;


					// Find right bounding box
					glm::vec3 RightMin = glm::vec3(10000.0f);
					glm::vec3 RightMax = glm::vec3(-10000.0f);

					for (int i = RightNode.StartIndex; i < RightNode.StartIndex + RightNode.Length; i++)
					{
						Bounds CurrentBounds = Triangles.at(i).GetBounds();
						RightMin = Vec3Min(CurrentBounds.Min, RightMin);
						RightMax = Vec3Max(CurrentBounds.Max, RightMax);
					}

					RightNode.NodeBounds = Bounds(RightMin, RightMax);

					if (!ShouldBeLeaf(RightNode.Length)) {
						NodeStack.push(RightNodePtr);
					}

					if (!ShouldBeLeaf(LeftNode.Length)) {
						NodeStack.push(LeftNodePtr);
					}

				}
			}

			return LastIndex;
		}

		struct FlattenRequest {
			Node* ActualNode;
			FlattenedNode* FNode;
		};

		uint FlattenBVH(std::vector<FlattenedNode>& FlattenedNodes, Node* RootNode, uint& node_offset) {
			FlattenedNode* CurrentFNode = &FlattenedNodes[node_offset];

			CurrentFNode->Min = glm::vec4(RootNode->NodeBounds.Min, 1.0f);
			CurrentFNode->Max = glm::vec4(RootNode->NodeBounds.Max, 1.0f);

			uint Offset = node_offset++;

			if (RootNode->IsLeafNode) {

				CurrentFNode->StartIdx = RootNode->StartIndex;
				CurrentFNode->TriangleCount = RootNode->Length;
				CurrentFNode->Axis = 10000;

			}

			else {

				CurrentFNode->Axis = RootNode->SplitAxis;
				CurrentFNode->TriangleCount = 0;
				FlattenBVH(FlattenedNodes, RootNode->LeftChildPtr, node_offset);
				CurrentFNode->StartIdx = FlattenBVH(FlattenedNodes, RootNode->RightChildPtr, node_offset);
			}

			return Offset;
		}

		Node* BuildBVH(Object& object, std::vector<Triangle>& Triangles, std::vector<FlattenedNode>& FlattenedNodes)
		{
			TotalIterations = 0;
				
			// First, generate triangles from vertices to make everything easier to work with 

			std::cout << "\nGenerating Triangles..";

			for (auto& Mesh : object.m_Meshes) {

				auto& Indices = Mesh.m_Indices;
				auto& Vertices = Mesh.m_Vertices;

				for (int x = 0; x < Indices.size(); x += 3)
				{
					FVertex v0 = { glm::vec4(Vertices.at(Indices.at(x + 0)).position, 1.0f) };
					FVertex v1 = { glm::vec4(Vertices.at(Indices.at(x + 1)).position, 1.0f) };
					FVertex v2 = { glm::vec4(Vertices.at(Indices.at(x + 2)).position, 1.0f) };

					Triangle tri = { (v0), (v1), (v2) };
					Triangles.push_back(tri);
				}
			}

			std::cout << "\nGenerated Triangles!";

			// Create bounding box 
			std::cout << "\Creating initial node bounding box..";

			glm::vec3 InitialMin = glm::vec3(10000.0f);
			glm::vec3 InitialMax = glm::vec3(-10000.0f);

			for (int i = 0; i < Triangles.size(); i++)
			{
				Bounds CurrentBounds = Triangles.at(i).GetBounds();
				InitialMin = Vec3Min(CurrentBounds.Min, InitialMin);
				InitialMax = Vec3Max(CurrentBounds.Max, InitialMax);
			}

			Node* RootNodePtr = new Node;
			Node& RootNode = *RootNodePtr;

			RootNode.LeftChild = 0;
			RootNode.RightChild = 0;
			RootNode.StartIndex = 0;
			RootNode.Length = Triangles.size() - 1;
			RootNode.ParentNode = 0;
			RootNode.IsLeftNode = false;
			RootNode.NodeBounds = Bounds(InitialMin, InitialMax);

			std::cout << "\nGenerated bounding box!";


			uint Size = BuildNodes(Triangles, &RootNode);
			
			uint NodeIdx = 0;
			FlattenedNodes.resize(Size);
			FlattenBVH(FlattenedNodes, &RootNode, NodeIdx);


			// Output debug stats 

			std::cout << "\n\n\n";
			std::cout << "--BVH Construction Info--";
			std::cout << "Triangle Count : " << Triangles.size();
			std::cout << "Node Count : " << Triangles.size();
			std::cout << "\n\n\n";



		}

	}




}