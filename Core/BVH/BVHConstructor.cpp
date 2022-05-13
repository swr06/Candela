#include "BVHConstructor.h"

#include <stack>
#include <iostream>
#include <queue>

namespace Lumen {
	namespace BVH {

		static uint64_t TotalIterations = 0;
		static uint64_t LeafNodeCount = 0;
		static uint32_t LastNodeIndex = 0;
		static uint32_t SplitFails = 0;
		static uint MaxBVHDepth = 0;

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
		
		FBounds CastToFBox(const Bounds& bounds) {
			FBounds x;
			x.Min = glm::vec4(bounds.Min, 0.0f);
			x.Max = glm::vec4(bounds.Max, 0.0f);
			return x;
		}

		void FlattenBVH(const Node* RootNode, std::vector<FlattenedNode>& FlattenedNodes, std::vector<int>& Cache, int& ProcessedNodes);


		void ConstructHierarchy(const std::vector<Vertex>& Vertices, std::vector<GLuint>& Indices, const std::vector<GLuint>& OriginalIndices, std::vector<FlattenedNode>& FlattenedNodes, std::vector<Triangle>& oTriangles, Node* RootNode) {

			std::vector<glm::vec3> CentroidCache;
			std::vector<Bounds> BoundsCache;

			glm::vec3 MinInitial = glm::vec3(1000000.0f);
			glm::vec3 MaxInitial = glm::vec3(-1000000.0f);

			// Cache bounds and centroids 
			for (int i = 0; i < Indices.size(); i += 3) {
				Bounds CurrentBounds;

				CurrentBounds.Min = glm::vec3(100000.0f);
				CurrentBounds.Max = glm::vec3(-100000.0f);
			
				for (int t = 0; t < 3; t++) {
					CurrentBounds.Min = glm::min(CurrentBounds.Min, glm::vec3(Vertices[Indices[i + t]].position));
					CurrentBounds.Max = glm::max(CurrentBounds.Max, glm::vec3(Vertices[Indices[i + t]].position));
				}

				MinInitial = glm::min(MinInitial, CurrentBounds.Min);
				MaxInitial = glm::max(MaxInitial, CurrentBounds.Max);

				CentroidCache.push_back(CurrentBounds.GetCenter());
				BoundsCache.push_back(CurrentBounds);
			}

			RootNode->NodeBounds.Min = MinInitial;
			RootNode->NodeBounds.Max = MaxInitial;

			// Sorted indices, indices are pushed here if they are a leaf node
			std::vector<GLuint> SortedIndices;

			// true : Uses Surface Area Heuristic (finds cut using a simple binary search)
			// false : Uses median split (splits across largest axis)
			const bool USE_SAH = false; 

			// Stack to hold processed nodes 
			std::stack<Node*> NodeStack;

			// Array that holds the pointers of the nodes themselves 
			std::vector<Node*> NodeArray;

			// Push to stack/array
			NodeStack.push(RootNode);
			NodeArray.push_back(RootNode);

			while (!NodeStack.empty()) {

				MaxBVHDepth = glm::max(MaxBVHDepth, (uint)NodeStack.size());

				TotalIterations++;

				if (TotalIterations % 32 == 0) {
					std::cout << "\nIteration : " << TotalIterations;
				}

				Node* BuildNode = NodeStack.top();
				NodeStack.pop();

				if (ShouldBeLeaf(BuildNode->Length)) {
					BuildNode->IsLeafNode = true;
					LeafNodeCount++;

					// Push indices 
					for (int i = BuildNode->StartIndex; i < BuildNode->StartIndex + BuildNode->Length; i++) {
						SortedIndices.push_back(Indices.at(i));
					}

					BuildNode->StartIndex = SortedIndices.size();

					continue;
				}
				
				glm::vec3 Centroid = BuildNode->NodeBounds.GetCenter();

				//static void FindSAHCut(std::vector<Triangle>&Triangles, const glm::vec3 & boundingMin, const glm::vec3 & boundingMax, uint idxStart, uint idxCount, int* cutDim, float* cutPos)

				uint SplitAxis;
				float Border;

				SplitAxis = FindLongestAxis(BuildNode->NodeBounds);
				Border = Centroid[SplitAxis];

				int LeftIdx = BuildNode->StartIndex;
				int RightIdx = BuildNode->StartIndex + BuildNode->Length;

				// Set axis
				BuildNode->Axis = SplitAxis;

				// Sort triangles, split them into two sets based on border
				while (true) {
					while (LeftIdx != RightIdx) {

						glm::vec3 Centroid = CentroidCache[Indices[LeftIdx]];

						if (Centroid[SplitAxis] > Border) {
							break;
						}

						LeftIdx++;
					}

					if (LeftIdx == RightIdx--) { break; }

					while (LeftIdx != RightIdx) {

						glm::vec3 Centroid = CentroidCache[Indices[RightIdx]];

						if (Centroid[SplitAxis] < Border) {
							break;
						}

						RightIdx--;
					}

					if (LeftIdx == RightIdx) {
						break;
					}

					LeftIdx++;

					// swap
					int Temp = Indices[LeftIdx];
					Indices[LeftIdx] = Indices[RightIdx];
					Indices[RightIdx] = Temp;
				}

				uint SplitIndex = LeftIdx;

				// Can't split, assume an arbitrary split location (midpoint chosen here)
				if (SplitIndex == BuildNode->StartIndex || SplitIndex == BuildNode->StartIndex + BuildNode->Length) {
					SplitIndex = BuildNode->StartIndex + (BuildNode->Length / 2);
					SplitFails++;
				}

				// Create two nodes
				LastNodeIndex++;
				Node* LeftNodePtr = new Node;
				Node& LeftNode = *LeftNodePtr;
				LeftNode.NodeIndex = LastNodeIndex;
				LeftNode.StartIndex = BuildNode->StartIndex;
				LeftNode.Length = SplitIndex - BuildNode->StartIndex;

				LastNodeIndex++;
				Node* RightNodePtr = new Node;
				Node& RightNode = *RightNodePtr;
				RightNode.NodeIndex = LastNodeIndex;
				RightNode.StartIndex = SplitIndex; // LeftNode.StartIndex + LeftNode.Length;
				RightNode.Length = BuildNode->Length - (SplitIndex - BuildNode->StartIndex);

				// Find bounds for left node
				glm::vec3 LeftMin = glm::vec3(10000.0f);
				glm::vec3 LeftMax = glm::vec3(-10000.0f);
				
				for (int x = 0; x < LeftNode.Length; x++) {

					Bounds bounds = BoundsCache[Indices[LeftNode.StartIndex + x]];
					LeftMin = glm::min(bounds.Min, LeftMin);
					LeftMax = glm::max(bounds.Max, LeftMax);
				}

				// Find bounds for right node
				glm::vec3 RightMin = glm::vec3(10000.0f);
				glm::vec3 RightMax = glm::vec3(-10000.0f);

				for (int x = 0; x < RightNode.Length; x++) {

					Bounds bounds = BoundsCache[Indices[RightNode.StartIndex + x]];
					RightMin = glm::min(bounds.Min, RightMin);
					RightMax = glm::max(bounds.Max, RightMax);
				} 

				// Set bounds 
				LeftNode.NodeBounds = Bounds(LeftMin, LeftMax);
				RightNode.NodeBounds = Bounds(RightMin, RightMax);

				// Since node is not a leaf node, make length 0
				BuildNode->Length = 0;
				BuildNode->LeftChildPtr = LeftNodePtr;
				BuildNode->RightChildPtr = RightNodePtr;

				LeftNode.IsLeafNode = false;
				RightNode.IsLeafNode = false;

				// Push nodes to array 
				NodeArray.push_back(LeftNodePtr);
				NodeArray.push_back(RightNodePtr);

				// Push to stack
				NodeStack.push(&LeftNode);
				NodeStack.push(&RightNode);
			}

			// Flatten!

			std::vector<int> FlattenCache; 
			int ProcessedNodes_ = 0;

			FlattenCache.resize(LastNodeIndex + 1);
			FlattenedNodes.resize(LastNodeIndex + 1);

			FlattenBVH(RootNode, FlattenedNodes, FlattenCache, ProcessedNodes_);

			// Generate faces 

			oTriangles.resize(LastNodeIndex + 1);

			//for (int i = 0; i < SortedIndices.size(); i++) {
			//
			//	auto& CurrentTriangle = oTriangles[i];
			//
			//	int TriangleIndex = SortedIndices[i];
			//
			//	int CurrentIndexRef = TriangleIndex * 3;
			//
			//	CurrentTriangle.Packed[0] = OriginalIndices[CurrentIndexRef + 0];
			//	CurrentTriangle.Packed[1] = OriginalIndices[CurrentIndexRef + 1];
			//	CurrentTriangle.Packed[2] = OriginalIndices[CurrentIndexRef + 2];
			//
			//	CurrentTriangle.Packed[3] = OriginalIndices[TriangleIndex];
			//
			//}
		}

		// Default BVH 
		/*
		uint FlattenBVHRecursive(Node* RootNode, uint* offset, std::vector<FlattenedNode>& FlattenedNodes) {
		
			FlattenedNode* CurrentFlattenedNode = &FlattenedNodes.at(*offset);
			CurrentFlattenedNode->Min = glm::vec4(RootNode->NodeBounds.Min, 0.0f);
			CurrentFlattenedNode->Max = glm::vec4(RootNode->NodeBounds.Max, 0.0f);
			uint offset_ = (*offset)++;
		
			if (RootNode->Length > 0)
			{
				if (RootNode->LeftChildPtr) {
					throw "!!!";
				}
		
				if (RootNode->RightChildPtr) {
					throw "!!!";
				}
		
				if (!RootNode->IsLeafNode) {
					throw "!!!";
				}
		
				CurrentFlattenedNode->StartIdx = RootNode->StartIndex;
				CurrentFlattenedNode->TriangleCount = RootNode->Length;
			}
		
			else
			{
				if (!RootNode->LeftChildPtr) {
					throw "!!!";
				}
		
				if (!RootNode->RightChildPtr) {
					throw "!!!";
				}
		
				CurrentFlattenedNode->Axis = RootNode->Axis;
				CurrentFlattenedNode->TriangleCount = 0;
				FlattenBVHRecursive(RootNode->LeftChildPtr, offset, FlattenedNodes);
				CurrentFlattenedNode->SecondChildOffset = FlattenBVHRecursive(RootNode->RightChildPtr, offset, FlattenedNodes);
			}
		
			return offset_;
		}*/

		uint FlattenBVHNaive(Node* RootNode, uint* offset) {

			std::stack<FlattenedNode> WorkStack;

			for (int i = 0; i < LastNodeIndex; i++) {





			}
		}

		int FlattenBVHRecursive(const Node* RootNode, std::vector<FlattenedNode>& FlattenedNodes, std::vector<int>& Cache, int& ProcessedNodes) {

			int idx = ProcessedNodes;
			FlattenedNode& node = FlattenedNodes[ProcessedNodes];
			node.Min = glm::vec4(RootNode->NodeBounds.Min, 0.0f);
			node.Max = glm::vec4(RootNode->NodeBounds.Max, 0.0f);

			int& extra = Cache[ProcessedNodes++];

			if (RootNode->IsLeafNode)
			{
				// 28 bits for start index 
				// 4 for length 
				int Packed = ((RootNode->StartIndex) << 4) | (RootNode->Length & 0xF);
				extra = Packed;
				node.Min.w = -1.0f; // <- Used as a flag
			}
			else
			{
				FlattenBVHRecursive(RootNode->LeftChildPtr, FlattenedNodes, Cache, ProcessedNodes);
				
				// Store links to right nodes
				node.Min.w = (float)FlattenBVHRecursive(RootNode->RightChildPtr, FlattenedNodes, Cache, ProcessedNodes);
			}

			return idx;
		}

		void FlattenBVH(const Node* RootNode, std::vector<FlattenedNode>& FlattenedNodes, std::vector<int>& Cache, int& ProcessedNodes) {

			FlattenBVHRecursive(RootNode, FlattenedNodes, Cache, ProcessedNodes);

			FlattenedNodes[0].Max.w = -1.0f;

			// Link nodes 
			for (int i = 0; i < FlattenedNodes.size(); i++) {

				if (FlattenedNodes[i].Min.w != -1.0f)
				{
					FlattenedNodes[i + 1].Max.w = FlattenedNodes[i].Min.w;

					int Indice = (int)(FlattenedNodes[i].Min.w);

					FlattenedNodes[Indice].Max.w = FlattenedNodes[i].Max.w;
				}

			}

			// Write start/end idx for leaves 
			// -1.0 used as a flag 
			for (int i = 0; i < FlattenedNodes.size(); i++)
			{
				if (FlattenedNodes[i].Min.w == -1.0f)
				{
					FlattenedNodes[i].Min.w = (float) Cache[i];
				}
				else
				{
					FlattenedNodes[i].Min.w = -1.0f;
				}
			}
		}


		Node* BuildBVH(const Object& object, std::vector<FlattenedNode>& FlattenedNodes, std::vector<Vertex>& MeshVertices, std::vector<Triangle>& FlattenedTris)
		{
			TotalIterations = 0;
			LastNodeIndex = 0;
				
			// First, generate triangles from vertices to make everything easier to work with 

			std::cout << "\nGenerating Combined Mesh Vertices/Indices..";

			// Combined vertices and indices  
			std::vector<GLuint> MeshIndices; 

			uint IndexOffset = 0;

			for (auto& Mesh : object.m_Meshes) {

				auto& Indices = Mesh.m_Indices;
				auto& Vertices = Mesh.m_Vertices;

				for (int x = 0; x < Indices.size(); x += 1)
				{
					MeshIndices.push_back(Indices.at(x) + IndexOffset);
				}

				for (int x = 0; x < Vertices.size(); x += 1) 
				{
					MeshVertices.push_back(Vertices.at(x));
				}

				IndexOffset += Vertices.size();
			}

			std::vector<GLuint> IndicesCopy = MeshIndices;

			std::cout << "\nGenerated!";

			uint Triangles = MeshIndices.size() / 3;

			Node* RootNodePtr = new Node;
			Node& RootNode = *RootNodePtr;

			RootNode.NodeIndex = 0;
			RootNode.LeftChildPtr = nullptr;
			RootNode.RightChildPtr = nullptr;
			RootNode.StartIndex = 0;
			RootNode.Length = Triangles;
			RootNode.IsLeftNode = false;

			ConstructHierarchy(MeshVertices, MeshIndices, IndicesCopy, FlattenedNodes, FlattenedTris, &RootNode);

			uint Offset = 0;

			// Output debug stats 

			std::cout << "\n\n\n";
			std::cout << "--BVH Construction Info--";
			std::cout << "\nTriangle Count : " << Triangles;
			std::cout << "\nNode Count : " << LastNodeIndex;
			std::cout << "\nLeaf Count : " << LeafNodeCount;
			std::cout << "\nSplit Fail Count : " << SplitFails;
			std::cout << "\nMax Depth : " << MaxBVHDepth;
			std::cout << "\n\n\n";

			return RootNodePtr;
		}
	}

}