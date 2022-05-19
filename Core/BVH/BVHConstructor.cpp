/*
	Constructs a bounding volume hierarchy for a mesh/object. 

	Interesting statistics : 

	Median split : 17 FPS
	512 Steps (Basically ground truth SAH) : 45 FPS
	2 steps : 37 FPS
	2 steps + 12 binary : 40 FPS
	12 steps + 4 binary : 42 FPS
	Binning (64 bins) : 45 FPS

	All hail SAH!

	Traversal using a stack of size 64 : 34 FPS in Dabrovic Sponza
	Traversal using a shared stack of size (64 x (Total Workgroups)) : 29 FPS in Dabrovic Sponza
	Stackless traversal : 43 FPS in Dabrovic Sponza

	The traversal using a stack seems to be faster in some specific scenes.

*/

#include "BVHConstructor.h"

#include <stack>
#include <iostream>
#include <queue>

namespace Lumen {
	namespace BVH {

		// true : Uses Surface Area Heuristic (finds cut using a simple binary search)
		// false : Uses median split (splits across largest axis)
		const bool USE_SAH = true;
		const bool BINNED_SAH = true;
		
		// Number of bins used to determine the optimal split position
		const int BIN_COUNT = 64; 

		// Max primitives each leaf can hold 
		// Recommended : 2 - 3
		const int MAX_TRIANGLES_PER_LEAF = 2;

		const bool OPTIMIZE_FOR_AVERAGE_CASE = true;


		
		// Internal
		static const float INF_COST = 1e29f;

		static uint64_t TotalIterations = 0;
		static uint64_t LeafNodeCount = 0;
		static uint64_t LastNodeIndex = 0;
		static uint64_t SplitFails = 0;
		static uint MaxBVHDepth = 0;

		// Processing bin
		class Bin {

		public : 

			Bin() : Primitives(0), bounds(Bounds()) {
				
			}

			Bounds bounds;

			int Primitives;

		};

		// Utility

		inline bool ShouldBeLeaf(uint Length) {
			return Length <= MAX_TRIANGLES_PER_LEAF;
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

		// Flatteners 

		void FlattenBVH(const Node* RootNode, std::vector<FlattenedNode>& FlattenedNodes, std::vector <glm::ivec2>& Cache, int& ProcessedNodes);
		
		void FlattenStackBVH(std::vector<FlattenedStackNode>& FlattenedNodes, Node* RootNode); 


		// Splitters 

		void GetMedianSplit(Node* node, int& Axis, float& Border) {
			glm::vec3 Centroid = node->NodeBounds.GetCenter();
			Axis = FindLongestAxis(node->NodeBounds);
			Border = Centroid[Axis];
		}

		float GetSAH(Node* Node, int Axis, float Border, const std::vector<int> TriangleReferences, const std::vector<Bounds>& BoundsCache, const std::vector<glm::vec3>& CentroidCache) {

			Bounds LeftBox;
			Bounds RightBox;

			int LeftMultiplier = 0;
			int RightMultiplier = 0;

			LeftBox.Min = glm::vec3(ARBITRARY_MAX);
			RightBox.Min = glm::vec3(ARBITRARY_MAX);
			LeftBox.Max = glm::vec3(ARBITRARY_MIN);
			RightBox.Max = glm::vec3(ARBITRARY_MIN);

			for (int i = Node->StartIndex; i < Node->StartIndex + Node->Length; i++) {

				const Bounds& CurrentBounds = BoundsCache[TriangleReferences[i]];
				const glm::vec3& CurrentCentroid = CentroidCache[TriangleReferences[i]];

				if (CurrentCentroid[Axis] < Border) {

					LeftMultiplier += 1;
					LeftBox.Max = glm::max(LeftBox.Max, CurrentBounds.Max);
					LeftBox.Min = glm::min(LeftBox.Min, CurrentBounds.Min);
				}

				else {

					RightMultiplier += 1;
					RightBox.Max = glm::max(RightBox.Max, CurrentBounds.Max);
					RightBox.Min = glm::min(RightBox.Min, CurrentBounds.Min);

				}
			}

			// Heuristic ->
			float Cost = LeftMultiplier * LeftBox.GetArea() + RightMultiplier * RightBox.GetArea();
			Cost = Cost > 0.0001f ? Cost : INF_COST;
			
			return Cost;
		}

		float SearchBestPlaneSAHLinear(Node* node, const std::vector<int> TriangleReferences, const std::vector<Bounds>& BoundsCache, const std::vector<glm::vec3>& CentroidCache, int& oAxis, float& oBorder) {

			GetMedianSplit(node, oAxis, oBorder);

			float BestCost = INF_COST;

			int Steps = 128;

			for (int Axis = 0; Axis < 3; Axis++) {

				float MinAxis = node->NodeBounds.Min[Axis];
				float MaxAxis = node->NodeBounds.Max[Axis];

				if (MinAxis == MaxAxis) {
					continue;
				}

				float CurrentPosition = MinAxis;

				float StepSize = (MaxAxis - MinAxis) / ((float)Steps);

				for (int Step = 0; Step < Steps; Step++) {

					CurrentPosition += StepSize;

					float CostAt = GetSAH(node, Axis, CurrentPosition, TriangleReferences, BoundsCache, CentroidCache);
				
					if (CostAt < BestCost) {
						BestCost = CostAt;
						oAxis = Axis;
						oBorder = CurrentPosition;
					}

				}


			}

			return BestCost;
		}

		float SearchBestPlaneSAHBinary(Node* node, const std::vector<int> TriangleReferences, const std::vector<Bounds>& BoundsCache, const std::vector<glm::vec3>& CentroidCache, int& oAxis, float& oBorder) {

			const int StepCount = 12;
			const int BinaryStepCount = 3;

			GetMedianSplit(node, oAxis, oBorder);

			float BestCost = INF_COST;

			float LastStepSize = 2.0f / 64.0f;

			for (int Axis = 0; Axis < 3; Axis++) {

				float MinAxis = node->NodeBounds.Min[Axis];
				float MaxAxis = node->NodeBounds.Max[Axis];

				if (MinAxis == MaxAxis) {
					continue;
				}

				float CurrentPosition = MinAxis;

				float StepSize = (MaxAxis - MinAxis) / ((float)StepCount);

				for (int Step = 0; Step < StepCount; Step++) {

					CurrentPosition += StepSize;

					float CostAt = GetSAH(node, Axis, CurrentPosition, TriangleReferences, BoundsCache, CentroidCache);

					if (CostAt < BestCost) {
						BestCost = CostAt;
						oAxis = Axis;
						oBorder = CurrentPosition;
						LastStepSize = StepSize;
					}

				}


			}

			// Binary search 

			float StepSize = LastStepSize * 0.5f;
			float BinaryPosition = oBorder + StepSize;

			for (int Step = 0; Step < BinaryStepCount; Step++) {

				StepSize *= 0.5f;

				float CostAt = GetSAH(node, oAxis, BinaryPosition, TriangleReferences, BoundsCache, CentroidCache);

				if (CostAt < BestCost) {
					BinaryPosition += StepSize;
					BestCost = CostAt;
				}

				else {
					BinaryPosition -= StepSize;
				}

			}

			oBorder = BinaryPosition;
			return BestCost;
		}


		float SearchSAHPlaneBinned(Node* node, const std::vector<int> TriangleReferences, const std::vector<Bounds>& BoundsCache, const std::vector<glm::vec3>& CentroidCache, int& oAxis, float& oBorder) {

			float BestCost = INF_COST;

			for (int Axis = 0; Axis < 3; Axis++) {

				float MinAxis = node->NodeBounds.Min[Axis];
				float MaxAxis = node->NodeBounds.Max[Axis];

				if (MinAxis == MaxAxis) {
					continue;
				}

				// Bin data ->
				Bin Bins[BIN_COUNT];

				float LeftAreas[BIN_COUNT - 1];
				int LeftCount[BIN_COUNT - 1];
				float RightAreas[BIN_COUNT - 1];
				int RightCount[BIN_COUNT - 1];

				float Extent = MaxAxis - MinAxis;
				float Scale = BIN_COUNT / Extent;

				// Create bins 
				for (int i = node->StartIndex; i < node->StartIndex + node->Length; i++) {

					const glm::vec3& CurrentCentroid = CentroidCache[TriangleReferences[i]];
					const Bounds& CurrentBounds = BoundsCache[TriangleReferences[i]];

					int BinIndex = glm::min(BIN_COUNT - 1, (int)((CurrentCentroid[Axis] - MinAxis) * Scale));

					Bins[BinIndex].Primitives++;

					Bins[BinIndex].bounds.Min = glm::min(Bins[BinIndex].bounds.Min, CurrentBounds.Min);
					Bins[BinIndex].bounds.Max = glm::max(Bins[BinIndex].bounds.Max, CurrentBounds.Max);
				}

				// Gather data, compute areas and counts 

				Bounds LeftBox = Bounds();
				Bounds RightBox = Bounds();

				int LeftSum = 0;
				int RightSum = 0;

				for (int i = 0; i < BIN_COUNT - 1; i++) {

					// Left box
					LeftSum += Bins[i].Primitives;
					LeftCount[i] = LeftSum;
					
					LeftBox.Min = glm::min(LeftBox.Min, Bins[i].bounds.Min);
					LeftBox.Max = glm::max(LeftBox.Max, Bins[i].bounds.Max);

					LeftAreas[i] = LeftBox.GetArea();

					// Right box
					int IdxR = BIN_COUNT - 1 - i; // <- Right index

					RightSum += Bins[IdxR].Primitives;
					RightCount[IdxR - 1] = RightSum;

					RightBox.Min = glm::min(RightBox.Min, Bins[IdxR].bounds.Min);
					RightBox.Max = glm::max(RightBox.Max, Bins[IdxR].bounds.Max);

					RightAreas[IdxR - 1] = RightBox.GetArea();
				}

				// Resolve

				float StepSize = Extent / ((float)BIN_COUNT);

				for (int i = 0; i < BIN_COUNT - 1; i++) {

					float CostAt = LeftCount[i] * LeftAreas[i] + RightCount[i] * RightAreas[i];

					if (CostAt < BestCost) {
						BestCost = CostAt;
						oAxis = Axis;
						oBorder = MinAxis + (StepSize * (i + 1));
					}
				}
			}

			return BestCost;

		}

		void GetSplit(Node* node, const std::vector<int> TriangleReferences, const std::vector<Bounds>& BoundsCache, const std::vector<glm::vec3>& CentroidCache, int& oAxis, float& oBorder) {

			if (USE_SAH) {

				if (!BINNED_SAH) {
					SearchBestPlaneSAHLinear(node, TriangleReferences, BoundsCache, CentroidCache, oAxis, oBorder);
				}

				else {
					SearchSAHPlaneBinned(node, TriangleReferences, BoundsCache, CentroidCache, oAxis, oBorder);
				}
			}

			else {

				GetMedianSplit(node, oAxis, oBorder);

			}
		}

		void ConstructTree(const std::vector<Vertex>& Vertices, const std::vector<GLuint>& OriginalIndices, std::vector<Triangle>& oTriangles, Node* RootNode, std::vector<int>& TriangleReferences, std::vector<int>& SortedTriangleReferences) {

			srand(10238);
			rand();
			rand();
			rand();

			uint TriangleCountTotal = OriginalIndices.size() / 3;


			TriangleReferences.resize(TriangleCountTotal);

			for (int i = 0; i < TriangleCountTotal; i++) {

				TriangleReferences[i] = i;

			}

			// Cache bounds and centroids 
			std::vector<glm::vec3> CentroidCache;
			std::vector<Bounds> BoundsCache;

			glm::vec3 MinInitial = glm::vec3(ARBITRARY_MAX);
			glm::vec3 MaxInitial = glm::vec3(ARBITRARY_MIN);

			for (int i = 0; i < OriginalIndices.size(); i += 3) {
				Bounds CurrentBounds;

				CurrentBounds.Min = glm::vec3(ARBITRARY_MAX);
				CurrentBounds.Max = glm::vec3(ARBITRARY_MIN);

				for (int t = 0; t < 3; t++) {
					CurrentBounds.Min = glm::min(CurrentBounds.Min, glm::vec3(Vertices[OriginalIndices[i + t]].position));
					CurrentBounds.Max = glm::max(CurrentBounds.Max, glm::vec3(Vertices[OriginalIndices[i + t]].position));
				}

				MinInitial = glm::min(MinInitial, CurrentBounds.Min);
				MaxInitial = glm::max(MaxInitial, CurrentBounds.Max);

				CentroidCache.push_back(CurrentBounds.GetCenter());
				BoundsCache.push_back(CurrentBounds);
			}

			RootNode->NodeBounds.Min = MinInitial;
			RootNode->NodeBounds.Max = MaxInitial;


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

				if (TotalIterations % 64 == 0) {
					std::cout << "\nBVH Iteration : " << TotalIterations;
				}

				Node* BuildNode = NodeStack.top();
				NodeStack.pop();

				if (ShouldBeLeaf(BuildNode->Length) || BuildNode->Length <= 1) {
					BuildNode->IsLeafNode = true;
					LeafNodeCount++;

					int Finalidx = (int)SortedTriangleReferences.size();

					// Push indices 
					for (int i = BuildNode->StartIndex; i < BuildNode->StartIndex + BuildNode->Length; i++)
					{
						int data = TriangleReferences.at(i);
						SortedTriangleReferences.push_back(data);
					}

					BuildNode->StartIndex = Finalidx;

					continue;
				}

				glm::vec3 CentroidNodeBounds = BuildNode->NodeBounds.GetCenter();

				int SplitAxis;
				float Border;

				//SplitAxis = FindLongestAxis(BuildNode->NodeBounds);
				//Border = Centroid[SplitAxis];
				GetSplit(BuildNode, TriangleReferences, BoundsCache, CentroidCache, SplitAxis, Border);

				// Set axis
				BuildNode->Axis = SplitAxis;

				// The index that defines the split 
				uint SplitIndex = 0;

				if (false) {

					int LeftIdx = BuildNode->StartIndex;
					int RightIdx = BuildNode->StartIndex + BuildNode->Length;

					// Sort triangles, split them into two sets based on border
					while (LeftIdx < RightIdx) {
						while (LeftIdx < RightIdx) {

							glm::vec3 Centroid = CentroidCache[TriangleReferences[LeftIdx]];

							if (Centroid[SplitAxis] > Border) {
								break;
							}

							LeftIdx++;
						}

						while (LeftIdx < RightIdx) {

							glm::vec3 Centroid = CentroidCache[TriangleReferences[RightIdx]];

							if (Centroid[SplitAxis] < Border) {
								break;
							}

							RightIdx--;
						}

						if (LeftIdx < RightIdx)
						{
							// swap
							int Temp = TriangleReferences[LeftIdx];
							TriangleReferences[LeftIdx] = TriangleReferences[RightIdx];
							TriangleReferences[RightIdx] = Temp;
						}
					}

					SplitIndex = LeftIdx;
				}

				else {

					int Midpointer = BuildNode->StartIndex;

					for (int i = BuildNode->StartIndex; i < BuildNode->StartIndex + BuildNode->Length; i++) {

						const glm::vec3& Centroid = CentroidCache[TriangleReferences[i]];

						if (Centroid[SplitAxis] < Border) {

							// Swap
							int Temp = TriangleReferences[i];
							TriangleReferences[i] = TriangleReferences[Midpointer];
							TriangleReferences[Midpointer] = Temp;
							Midpointer++;
						}

					}

					SplitIndex = Midpointer;
				}

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
				RightNode.Length = (BuildNode->StartIndex + BuildNode->Length) - SplitIndex;//BuildNode->Length - (SplitIndex - BuildNode->StartIndex);

				// Find bounds for left node
				glm::vec3 LeftMin = glm::vec3(ARBITRARY_MAX);
				glm::vec3 LeftMax = glm::vec3(ARBITRARY_MIN);

				for (int x = 0; x < LeftNode.Length; x++) {

					Bounds bounds = BoundsCache[TriangleReferences[LeftNode.StartIndex + x]];
					LeftMin = glm::min(bounds.Min, LeftMin);
					LeftMax = glm::max(bounds.Max, LeftMax);
				}

				// Find bounds for right node
				glm::vec3 RightMin = glm::vec3(ARBITRARY_MAX);
				glm::vec3 RightMax = glm::vec3(ARBITRARY_MIN);

				for (int x = 0; x < RightNode.Length; x++) {

					Bounds bounds = BoundsCache[TriangleReferences[RightNode.StartIndex + x]];
					RightMin = glm::min(bounds.Min, RightMin);
					RightMax = glm::max(bounds.Max, RightMax);
				}

				// Set bounds 
				LeftNode.NodeBounds = Bounds(LeftMin, LeftMax);
				RightNode.NodeBounds = Bounds(RightMin, RightMax);

				if (OPTIMIZE_FOR_AVERAGE_CASE) {
					int RandomShuffle = rand() % 4;

					if (RandomShuffle < 2) {
						auto* Temp = LeftNodePtr;
						LeftNodePtr = RightNodePtr;
						RightNodePtr = Temp;
					}
				}

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
		}


		void GenerateTriangles(const std::vector<int>& TriangleIndices, const std::vector<GLuint>& OriginalIndices, std::vector<Triangle>& oTriangles) {
			


			oTriangles.resize((TriangleIndices.size()));

			for (int i = 0; i < TriangleIndices.size(); i++) {

				auto& CurrentTriangle = oTriangles[i];

				int TriangleIndex = TriangleIndices[i];

				// 3 indices correspond to a single triangle
				int CurrentIndexRef = TriangleIndex * 3;

				CurrentTriangle.Packed[0] = OriginalIndices[CurrentIndexRef + 0];
				CurrentTriangle.Packed[1] = OriginalIndices[CurrentIndexRef + 1];
				CurrentTriangle.Packed[2] = OriginalIndices[CurrentIndexRef + 2];
				CurrentTriangle.Packed[3] = TriangleIndex;

			}
		}



		void ConstructHierarchyLinear(const std::vector<Vertex>& Vertices, const std::vector<GLuint>& OriginalIndices, std::vector<FlattenedNode>& FlattenedNodes, std::vector<Triangle>& oTriangles, Node* RootNode) {

			bool DEBUG_BVH = false;

			std::vector<int> TriangleReferences;
			std::vector<int> SortedReferences;

			// Build tree 
			ConstructTree(Vertices, OriginalIndices, oTriangles, RootNode, TriangleReferences, SortedReferences);

			// Flatten
			std::vector<glm::ivec2> FlattenCache; 
			int ProcessedNodes_ = 0;

			FlattenCache.resize(LastNodeIndex + 1);
			FlattenedNodes.resize(LastNodeIndex + 1);

			FlattenBVH(RootNode, FlattenedNodes, FlattenCache, ProcessedNodes_);

			if (DEBUG_BVH) {

				for (int i = 0; i < SortedReferences.size(); i++) {

					bool found = false;

					for (int j = 0; j < SortedReferences.size(); j++) {

						int CurrentElement = SortedReferences[j];

						if (CurrentElement == i) {
							found = true;
							break;
						}

					}

					if (!found) {
						std::cout << "\nBVH DEBUG -> DIDNT FIND ELEMENT : " << i;
					}

				}
			}


			GenerateTriangles(SortedReferences, OriginalIndices, oTriangles);
		}


		void ConstructHierarchy(const std::vector<Vertex>& Vertices, const std::vector<GLuint>& OriginalIndices, std::vector<FlattenedNode>& FlattenedNodes, std::vector<Triangle>& oTriangles, Node* RootNode) {

			bool DEBUG_BVH = false;

			std::vector<int> TriangleReferences;
			std::vector<int> SortedReferences;

			ConstructTree(Vertices, OriginalIndices, oTriangles, RootNode, TriangleReferences, SortedReferences);

			// Flatten!

			std::vector<glm::ivec2> FlattenCache;
			int ProcessedNodes_ = 0;

			FlattenCache.resize(LastNodeIndex + 1);
			FlattenedNodes.resize(LastNodeIndex + 1);

			FlattenBVH(RootNode, FlattenedNodes, FlattenCache, ProcessedNodes_);

			if (DEBUG_BVH) {

				for (int i = 0; i < SortedReferences.size(); i++) {

					bool found = false;

					for (int j = 0; j < SortedReferences.size(); j++) {

						int CurrentElement = SortedReferences[j];

						if (CurrentElement == i) {
							found = true;
							break;
						}

					}

					if (!found) {
						std::cout << "\nBVH DEBUG -> DIDNT FIND ELEMENT : " << i;
					}

				}
			}

			GenerateTriangles(SortedReferences, OriginalIndices, oTriangles);
		}

		void ConstructHierarchy_StackBVH(const std::vector<Vertex>& Vertices, const std::vector<GLuint>& OriginalIndices, std::vector<FlattenedStackNode>& FlattenedNodes, std::vector<Triangle>& oTriangles, Node* RootNode) {

			bool DEBUG_BVH = false;

			std::vector<int> TriangleReferences;
			std::vector<int> SortedReferences;

			ConstructTree(Vertices, OriginalIndices, oTriangles, RootNode, TriangleReferences, SortedReferences);

			// Flatten!

			std::vector<glm::ivec2> FlattenCache;
			int ProcessedNodes_ = 0;

			FlattenCache.resize(LastNodeIndex + 1);
			FlattenedNodes.resize(LastNodeIndex + 1);

			FlattenStackBVH(FlattenedNodes, RootNode);
			GenerateTriangles(SortedReferences, OriginalIndices, oTriangles);
		}


		uint FlattenBVHNaive(Node* RootNode, uint* offset) {

			std::stack<FlattenedNode> WorkStack;

			for (int i = 0; i < LastNodeIndex; i++) {





			}
		}

		int FlattenBVHRecursive(const Node* RootNode, std::vector<FlattenedNode>& FlattenedNodes, std::vector<glm::ivec2>& Cache, int& ProcessedNodes) {

			int idx = ProcessedNodes;
			FlattenedNode& node = FlattenedNodes[ProcessedNodes];
			node.Min = glm::vec4(RootNode->NodeBounds.Min, 0.0f);
			node.Max = glm::vec4(RootNode->NodeBounds.Max, 0.0f);

			glm::ivec2& CacheRef = Cache[ProcessedNodes++];

			if (RootNode->IsLeafNode)
			{
				int Packed = (RootNode->StartIndex << 4) | (RootNode->Length & 0xF); // <- Pack data 
				CacheRef.y = Packed;
				CacheRef.x = -1; // <- flag
			}
			else
			{
				FlattenBVHRecursive(RootNode->LeftChildPtr, FlattenedNodes, Cache, ProcessedNodes);
				
				// Store links to right nodes
				CacheRef.x = FlattenBVHRecursive(RootNode->RightChildPtr, FlattenedNodes, Cache, ProcessedNodes);
			}

			return idx;
		}

		void FlattenBVH(const Node* RootNode, std::vector<FlattenedNode>& FlattenedNodes, std::vector <glm::ivec2> & Cache, int& ProcessedNodes) {

			FlattenBVHRecursive(RootNode, FlattenedNodes, Cache, ProcessedNodes);

			const float NegativeOneIntBits = glm::intBitsToFloat(-1);

			FlattenedNodes[0].Max.w = NegativeOneIntBits;

			// Link nodes 
			for (int i = 0; i < FlattenedNodes.size(); i++) {
				
				// Inner node?
				if (Cache[i].x != -1)
				{
					FlattenedNodes[i + 1].Max.w = glm::intBitsToFloat(Cache[i].x);

					int Indice = (int)(Cache[i].x);

					FlattenedNodes[Indice].Max.w = FlattenedNodes[i].Max.w;
				}

			}

			// Write start/end idx for leaves 
			// -1.0 used as a flag 
			for (int i = 0; i < FlattenedNodes.size(); i++)
			{
				if (Cache[i].x == -1)
				{
					FlattenedNodes[i].Min.w = glm::intBitsToFloat(Cache[i].y);
				}
				else
				{
					FlattenedNodes[i].Min.w = NegativeOneIntBits;
				}
			}
		}

		void FlattenStackBVH(std::vector<FlattenedStackNode>& FlattenedNodes, Node* RootNode) {

			int NodeCounter = 0;

			const float MinusOneIntFloatBits = glm::intBitsToFloat(-1);

			int TotalNodesProcessed = 0;
			int LeavesProcessed = 0;
			int InternalsProcessed = 0;

			// First component : Node pointer 
			// Second component : Work index
			// If the work index is negative, it corresponds to a right node, else it corresponds to a left node
			std::queue<std::pair<Node*, int>> Workqueue;

			Workqueue.push(std::make_pair(RootNode, 0));

			while (!Workqueue.empty())
			{
				TotalNodesProcessed++;

				std::pair<Node*, int> current = std::make_pair(Workqueue.front().first, Workqueue.front().second);
				Workqueue.pop();

				FlattenedStackNode& node = FlattenedNodes[NodeCounter++];

				node.LBounds.Min = glm::vec4(current.first->LeftChildPtr->NodeBounds.Min, 0.0f);
				node.LBounds.Max = glm::vec4(current.first->LeftChildPtr->NodeBounds.Max, 0.0f);

				if (!current.first->LeftChildPtr->IsLeafNode)
				{
					InternalsProcessed++;
					node.LBounds.Min.w = MinusOneIntFloatBits;
					Workqueue.push(std::make_pair(current.first->LeftChildPtr, NodeCounter));
				}

				else
				{
					LeavesProcessed++;
					// Pack data ->
					int Packed = ((current.first->LeftChildPtr->StartIndex) << 4) | (((current.first->LeftChildPtr->Length)) & 0xF);
					node.LBounds.Min.w = glm::intBitsToFloat(Packed);
				}

				node.RBounds.Min = glm::vec4(current.first->RightChildPtr->NodeBounds.Min, 0.0f);
				node.RBounds.Max = glm::vec4(current.first->RightChildPtr->NodeBounds.Max, 0.0f);

				if (!current.first->RightChildPtr->IsLeafNode)
				{
					InternalsProcessed++;
					node.RBounds.Min.w = MinusOneIntFloatBits;
					Workqueue.push(std::make_pair(current.first->RightChildPtr, -NodeCounter));
				}

				else
				{
					LeavesProcessed++;
					// Pack data ->
					int Packed = ((current.first->RightChildPtr->StartIndex) << 4) | (((current.first->RightChildPtr->Length)) & 0xF);
					node.RBounds.Min.w = glm::intBitsToFloat(Packed);
				}

				if (current.second > 0)
				{
					FlattenedNodes[current.second - 1].LBounds.Max.w = glm::intBitsToFloat(NodeCounter - 1);
				}

				else if (current.second < 0)
				{
					FlattenedNodes[-current.second - 1].RBounds.Max.w = glm::intBitsToFloat(NodeCounter - 1);
				}

			}

			if (false) {
				std::cout << "\n\n\nFLATTENING ->";
				std::cout << "Total Processed : " << TotalNodesProcessed;
				std::cout << "\nInternals Processed : " << InternalsProcessed;
				std::cout << "\nLeaves Processed : " << LeavesProcessed;
				std::cout << "\n\n\n";
			}

			return;
		}

		

		void PrintShit(const Object& object, int FlattenedArraySize, std::vector<Vertex>& MeshVertices, std::vector<Triangle>& FlattenedTris) {

			// Output debug stats 

			std::cout << "\n\n\n";
			std::cout << "--BVH Construction Info--";
			std::cout << "\nTriangle Count : " << FlattenedTris.size();
			std::cout << "\nNode Count : " << LastNodeIndex;
			std::cout << "\nLeaf Count : " << LeafNodeCount;
			std::cout << "\nSplit Fail Count : " << SplitFails;
			std::cout << "\nMax Depth : " << MaxBVHDepth;
			std::cout << "\nNode Array Length : " << FlattenedArraySize;
			std::cout << "\nVertices Array Length : " << MeshVertices.size();
			std::cout << "\n\n\n";

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

			std::cout << "\nGenerated!";

			uint Triangles = MeshIndices.size() / 3;

			Node* RootNodePtr = new Node;
			Node& RootNode = *RootNodePtr;

			RootNode.NodeIndex = 0;
			RootNode.LeftChildPtr = nullptr;
			RootNode.RightChildPtr = nullptr;
			RootNode.StartIndex = 0;
			RootNode.Length = Triangles - 1;
			RootNode.IsLeftNode = false;

			ConstructHierarchy(MeshVertices, MeshIndices, FlattenedNodes, FlattenedTris, &RootNode);
			PrintShit(object, FlattenedNodes.size(), MeshVertices, FlattenedTris);

			return RootNodePtr;
		}


		
		Node* BuildBVH(const Object& object, std::vector<FlattenedStackNode>& FlattenedNodes, std::vector<Vertex>& MeshVertices, std::vector<Triangle>& FlattenedTris)
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

			std::cout << "\nGenerated!";

			uint Triangles = MeshIndices.size() / 3;

			Node* RootNodePtr = new Node;
			Node& RootNode = *RootNodePtr;

			RootNode.NodeIndex = 0;
			RootNode.LeftChildPtr = nullptr;
			RootNode.RightChildPtr = nullptr;
			RootNode.StartIndex = 0;
			RootNode.Length = Triangles - 1;
			RootNode.IsLeftNode = false;

			ConstructHierarchy_StackBVH(MeshVertices, MeshIndices, FlattenedNodes, FlattenedTris, &RootNode);
			PrintShit(object, FlattenedNodes.size(), MeshVertices, FlattenedTris);

			return RootNodePtr;
		}





		/*

		// Flattening from PBRT

		uint Flatten_PBRTStyle(Node* RootNode, uint* offset, std::vector<FlattenedNode>& FlattenedNodes) {

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

	}
	
}