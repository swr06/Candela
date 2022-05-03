#include "BVHConstructor.h"

#include <stack>
#include <queue>

namespace Lumen {
	namespace BVH {

		static uint64_t TotalIterations = 0;
		static uint64_t LeafNodeCount = 0;
		static uint32_t LastNodeIndex = 0;
		static uint32_t SplitFails = 0;

		inline glm::vec3 Vec3Min(const glm::vec3& a, const glm::vec3& b) {
			return glm::vec3(glm::min(a.x, b.x), glm::min(a.y, b.y), glm::min(a.z, b.z));
		}

		inline glm::vec3 Vec3Max(const glm::vec3& a, const glm::vec3& b) {
			return glm::vec3(glm::max(a.x, b.x), glm::max(a.y, b.y), glm::max(a.z, b.z));
		}

		inline bool ShouldBeLeaf(uint Length) {
			return Length <= 4;
		}

		static float min4f(float f0, float f1, float f2, float f3)
		{
			return f0 < f1 ? (f0 < f2 ? (f0 < f3 ? f0 : f3) : (f2 < f3 ? f2 : f3)) : (f1 < f2 ? (f1 < f3 ? f1 : f3) : (f2 < f3 ? f2 : f3));
		}

		static float max4f(float f0, float f1, float f2, float f3)
		{
			return f0 > f1 ? (f0 > f2 ? (f0 > f3 ? f0 : f3) : (f2 > f3 ? f2 : f3)) : (f1 > f2 ? (f1 > f3 ? f1 : f3) : (f2 > f3 ? f2 : f3));
		}

		static float SurfaceAreaHeuristic(std::vector<Triangle> &Triangles, uint idxStart, uint idxCount, int cutDim, float cutPos)
		{
			uint lCount = 0;
			uint rCount = 0;

			glm::vec3 lMin = { INFINITY, INFINITY, INFINITY };
			glm::vec3 lMax = { -INFINITY, -INFINITY, -INFINITY };

			glm::vec3 rMin = { INFINITY, INFINITY, INFINITY };
			glm::vec3 rMax = { -INFINITY, -INFINITY, -INFINITY };

			for (uint i = idxStart; i < idxStart + idxCount; i++)
			{
				Triangle& triangle = Triangles[i];


				if (triangle.v0.position[cutDim] <= cutPos || triangle.v1.position[cutDim] <= cutPos || triangle.v2.position[cutDim] <= cutPos)
				{
					lCount++;

					lMin.x = min4f(lMin.x, triangle.v0.position.x, triangle.v1.position.x, triangle.v2.position.x);
					lMin.y = min4f(lMin.y, triangle.v0.position.y, triangle.v1.position.y, triangle.v2.position.y);
					lMin.z = min4f(lMin.z, triangle.v0.position.z, triangle.v1.position.z, triangle.v2.position.z);

					lMax.x = max4f(lMax.x, triangle.v0.position.x, triangle.v1.position.x, triangle.v2.position.x);
					lMax.y = max4f(lMax.y, triangle.v0.position.y, triangle.v1.position.y, triangle.v2.position.y);
					lMax.z = max4f(lMax.z, triangle.v0.position.z, triangle.v1.position.z, triangle.v2.position.z);
				}
				else
				{
					rCount++;

					rMin.x = min4f(rMin.x, triangle.v0.position.x, triangle.v1.position.x, triangle.v2.position.x);
					rMin.y = min4f(rMin.y, triangle.v0.position.y, triangle.v1.position.y, triangle.v2.position.y);
					rMin.z = min4f(rMin.z, triangle.v0.position.z, triangle.v1.position.z, triangle.v2.position.z);

					rMax.x = max4f(rMax.x, triangle.v0.position.x, triangle.v1.position.x, triangle.v2.position.x);
					rMax.y = max4f(rMax.y, triangle.v0.position.y, triangle.v1.position.y, triangle.v2.position.y);
					rMax.z = max4f(rMax.z, triangle.v0.position.z, triangle.v1.position.z, triangle.v2.position.z);
				}
			}

			glm::vec3 lDim = { lMax.x - lMin.x, lMax.y - lMin.y, lMax.z - lMin.z };
			glm::vec3 rDim = { rMax.x - rMin.x, rMax.y - rMin.y, rMax.z - rMin.z };

			float lArea = 2 * lDim.x * lDim.y + 2 * lDim.x * lDim.z + 2 * lDim.y * lDim.z;
			float rArea = 2 * rDim.x * rDim.y + 2 * rDim.x * rDim.z + 2 * rDim.y * rDim.z;

			return lArea * lCount + rArea * rCount;
		}

		static void FindSAHCut(std::vector<Triangle>& Triangles, const glm::vec3& boundingMin, const glm::vec3& boundingMax, uint idxStart, uint idxCount, int* cutDim, float* cutPos)
		{
			*cutDim = 0;
			*cutPos = boundingMin.x + (boundingMax.x - boundingMin.x) * 0.5;

			float bestCutCost = INFINITY;
			for (int d = 0; d < 3; d++)
			{
				float lower = boundingMin[d];
				float upper = boundingMax[d];

				const float STEPS = 20;
				for (int i = 0; i < STEPS; i++)
				{
					float f = i / STEPS;

					float cut = lower + (upper - lower) * f;

					float cost = SurfaceAreaHeuristic(Triangles, idxStart, idxCount, d, cut);

					if (cost < bestCutCost)
					{
						bestCutCost = cost;
						*cutDim = d;
						*cutPos = cut;
					}
				}
			}
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

		void BuildNodes(std::vector<Triangle>& Triangles, std::vector<FlattenedNode>& FlattenedNodes, Node* RootNode) {

			// true : Uses Surface Area Heuristic (finds cut using a simple binary search)
			// false : Uses median split (splits across largest axis)
			const bool USE_SAH = false; 

			std::stack<Node*> NodeStack;

			NodeStack.push(RootNode);

			while (!NodeStack.empty()) {

				TotalIterations++;

				if (TotalIterations % 32 == 0) {
					std::cout << "\nIteration : " << TotalIterations;
				}

				Node* BuildNode = NodeStack.top();
				NodeStack.pop();

				if (ShouldBeLeaf(BuildNode->Length)) {
					BuildNode->IsLeafNode = true;
					LeafNodeCount++;
					continue;
				}
				
				glm::vec3 Centroid = BuildNode->NodeBounds.GetCenter();

				//static void FindSAHCut(std::vector<Triangle>&Triangles, const glm::vec3 & boundingMin, const glm::vec3 & boundingMax, uint idxStart, uint idxCount, int* cutDim, float* cutPos)

				uint SplitAxis;
				float Border;

				if (!USE_SAH) {
					SplitAxis = FindLongestAxis(BuildNode->NodeBounds);
					Border = Centroid[SplitAxis];
				}

				else {
					int temp_;
					FindSAHCut(Triangles, BuildNode->NodeBounds.Min, BuildNode->NodeBounds.Max, BuildNode->StartIndex, BuildNode->Length, &temp_, &Border);
					SplitAxis = static_cast<uint>(temp_);
				}


				int LeftIdx = BuildNode->StartIndex;
				int RightIdx = BuildNode->StartIndex + BuildNode->Length;

				// Set axis
				BuildNode->Axis = SplitAxis;

				// Sort triangles, split them into two sets based on border
				while (true) {
					while (LeftIdx != RightIdx) {

						glm::vec3 Centroid = Triangles[LeftIdx].GetCentroid();

						if (Centroid[SplitAxis] > Border) {
							break;
						}

						LeftIdx++;
					}

					if (LeftIdx == RightIdx--) { break; }

					while (LeftIdx != RightIdx) {

						glm::vec3 Centroid = Triangles[RightIdx].GetCentroid();

						if (Centroid[SplitAxis] < Border) {
							break;
						}

						RightIdx--;
					}

					if (LeftIdx == RightIdx) {
						break;
					}

					LeftIdx++;

					Triangle TempTri = Triangles[LeftIdx];
					Triangles[LeftIdx] = Triangles[RightIdx];
					Triangles[RightIdx] = TempTri;
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

					Bounds bounds = Triangles[LeftNode.StartIndex + x].GetBounds();
					LeftMin = glm::min(bounds.Min, LeftMin);
					LeftMax = glm::max(bounds.Max, LeftMax);
				}

				// Find bounds for right node
				glm::vec3 RightMin = glm::vec3(10000.0f);
				glm::vec3 RightMax = glm::vec3(-10000.0f);

				for (int x = 0; x < RightNode.Length; x++) {

					Bounds bounds = Triangles[RightNode.StartIndex + x].GetBounds();
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

				// Push to stack
				NodeStack.push(&LeftNode);
				NodeStack.push(&RightNode);
			}
		}



		std::vector<FlattenedNode>* FlattenedNodesPtr;

		uint FlattenBVHRecursive(Node* RootNode, uint* offset) {

			FlattenedNode* CurrentFlattenedNode = &FlattenedNodesPtr->at(*offset);
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
				FlattenBVHRecursive(RootNode->LeftChildPtr, offset);
				CurrentFlattenedNode->SecondChildOffset = FlattenBVHRecursive(RootNode->RightChildPtr, offset);
			}

			return offset_;
		}


		uint FlattenBVHNaive(Node* RootNode, uint* offset) {




		}




		Node* BuildBVH(Object& object, std::vector<Triangle>& Triangles, std::vector<FlattenedNode>& FlattenedNodes)
		{
			TotalIterations = 0;
			LastNodeIndex = 0;
				
			// First, generate triangles from vertices to make everything easier to work with 

			std::cout << "\nGenerating Triangles..";

			for (auto& Mesh : object.m_Meshes) {

				auto& Indices = Mesh.m_Indices;
				auto& Vertices = Mesh.m_Vertices;

				if (true) {

					int TrianglesCounter = 0;

					for (int x = 0; x < Indices.size(); x += 3)
					{
						FVertex v0 = { glm::vec4(Vertices.at(Indices.at(x)).position, 1.0f) };
						FVertex v1 = { glm::vec4(Vertices.at(Indices.at(x + 1)).position, 1.0f) };
						FVertex v2 = { glm::vec4(Vertices.at(Indices.at(x + 2)).position, 1.0f) };

						Triangle tri = { (v0), (v1), (v2) };
						Triangles.push_back(tri);
						TrianglesCounter++;
					}

				}

				else {

					for (int x = 0; x < Vertices.size(); x += 3)
					{
						FVertex v0 = { glm::vec4(Vertices.at(x).position, 1.0f) };
						FVertex v1 = { glm::vec4(Vertices.at(x).position, 1.0f) };
						FVertex v2 = { glm::vec4(Vertices.at(x).position, 1.0f) };

						Triangle tri = { (v0), (v1), (v2) };
						Triangles.push_back(tri);
					}

				}

			}

			std::cout << "\nGenerated Triangles!";

			// Create bounding box 
			std::cout << "\nCreating initial node bounding box..";

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

			RootNode.NodeIndex = 0;
			RootNode.LeftChildPtr = nullptr;
			RootNode.RightChildPtr = nullptr;
			RootNode.StartIndex = 0;
			RootNode.Length = Triangles.size() - 1;
			RootNode.IsLeftNode = false;
			RootNode.NodeBounds = Bounds(InitialMin, InitialMax);

			std::cout << "\nGenerated bounding box!";
			BuildNodes(Triangles, FlattenedNodes, &RootNode);
			
			FlattenedNodes.resize(LastNodeIndex + 1);

			uint Offset = 0;
			FlattenedNodesPtr = &FlattenedNodes;

			// Output debug stats 

			std::cout << "\n\n\n";
			std::cout << "--BVH Construction Info--";
			std::cout << "\nTriangle Count : " << Triangles.size();
			std::cout << "\nNode Count : " << LastNodeIndex;
			std::cout << "\nLeaf Count : " << LeafNodeCount;
			std::cout << "\nSplit Fail Count : " << SplitFails;
			std::cout << "\n\n\n";

			uint flattenedidx = FlattenBVHRecursive(RootNodePtr, &Offset);


			return RootNodePtr;

		}

	}




}