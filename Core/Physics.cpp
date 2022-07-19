#include "Physics.h"

#include <functional>

namespace Lumen {
		
	namespace Physics {

        using namespace glm;

        class AABB {

        public :

            vec3 Min;
            vec3 Max;

            AABB(vec3 min, vec3 max) : Min(min), Max(max) {

            }
        };

        bool AABBAABBOverlap(Physics::AABB a, Physics::AABB b)
        {
            return ((a.Min.x <= b.Max.x && a.Max.x >= b.Min.x) && (a.Min.y <= b.Max.y && a.Max.y >= b.Min.y) &&
                (a.Min.z <= b.Max.z && a.Max.z >= b.Min.z));
        }

        bool BoxTriangleOverlap(vec3 v0, vec3 v1, vec3 v2, Physics::AABB aabb) {
            vec3 c = (aabb.Min + aabb.Max) / 2.0f;
            vec3 e = aabb.Max - aabb.Min;

            v0 -= c;
            v1 -= c;
            v2 -= c;

            vec3 f0 = v1 - v0; // B - A
            vec3 f1 = v2 - v1; // C - B
            vec3 f2 = v0 - v2; // A - C

            vec3 u0 = vec3(1.0f, 0.0f, 0.0f);
            vec3 u1 = vec3(0.0f, 1.0f, 0.0f);
            vec3 u2 = vec3(0.0f, 0.0f, 1.0f);

            vec3 AxisUxFx[9];

            AxisUxFx[0] = cross(u0, f0);
            AxisUxFx[1] = cross(u0, f1);
            AxisUxFx[2] = cross(u0, f2);
            AxisUxFx[3] = cross(u1, f0);
            AxisUxFx[4] = cross(u1, f1);
            AxisUxFx[5] = cross(u2, f2);
            AxisUxFx[6] = cross(u2, f0);
            AxisUxFx[7] = cross(u2, f1);
            AxisUxFx[8] = cross(u2, f2);

            for (int i = 0; i < 9; i++) {

                vec3 axis = AxisUxFx[i];
                float p0 = dot(v0, axis);
                float p1 = dot(v1, axis);
                float p2 = dot(v2, axis);

                float r = e.x * abs(dot(u0, axis)) +
                    e.y * abs(dot(u1, axis)) +
                    e.z * abs(dot(u2, axis));

                if (max(-max(max(p0, p1), p2), min(min(p0, p1), p2)) > r) {
                    return false;
                }
            }

            vec3 triangleNormal = cross(f0, f1);
            float plane_distance = dot(triangleNormal, v0);

            return true;
        }

        bool BoxTriangleOverlap(vec3 v0, vec3 v1, vec3 v2, Physics::AABB aabb, glm::vec4& intersection) {
            vec3 c = (aabb.Min + aabb.Max) / 2.0f;
            vec3 e = aabb.Max - aabb.Min;

            v0 -= c;
            v1 -= c;
            v2 -= c;

            vec3 f0 = v1 - v0; // B - A
            vec3 f1 = v2 - v1; // C - B
            vec3 f2 = v0 - v2; // A - C

            vec3 u0 = vec3(1.0f, 0.0f, 0.0f);
            vec3 u1 = vec3(0.0f, 1.0f, 0.0f);
            vec3 u2 = vec3(0.0f, 0.0f, 1.0f);

            vec3 AxisUxFx[9];

            AxisUxFx[0] = cross(u0, f0);
            AxisUxFx[1] = cross(u0, f1);
            AxisUxFx[2] = cross(u0, f2);
            AxisUxFx[3] = cross(u1, f0);
            AxisUxFx[4] = cross(u1, f1);
            AxisUxFx[5] = cross(u2, f2);
            AxisUxFx[6] = cross(u2, f0);
            AxisUxFx[7] = cross(u2, f1);
            AxisUxFx[8] = cross(u2, f2);

            for (int i = 0; i < 9; i++) {

                vec3 axis = AxisUxFx[i];
                float p0 = dot(v0, axis);
                float p1 = dot(v1, axis);
                float p2 = dot(v2, axis);

                float r = e.x * abs(dot(u0, axis)) +
                    e.y * abs(dot(u1, axis)) +
                    e.z * abs(dot(u2, axis));

                if (max(-max(max(p0, p1), p2), min(min(p0, p1), p2)) > r) {
                    return false;
                }
            }

            vec3 triangleNormal = cross(f0, f1);
            float plane_distance = dot(triangleNormal, v0);

            vec3 triangleCentroid = v0 + v1 + v2; 
            triangleCentroid /= 3.0f;

            //plane_distance = glm::distance(triangleCentroid, c);

            intersection = glm::vec4(triangleNormal, plane_distance);

            return true;
        }

        bool CollideBVH(RayIntersector<BVH::StacklessTraversalNode>& Intersector, vec3 CMin, vec3 CMax, const int NodeStartIndex, const int NodeCount, const mat4 InverseMatrix, int Mesh, int TriangleIndex) {

            std::function IsLeafNode = [](BVH::StacklessTraversalNode node) { return glm::floatBitsToInt(node.Min.w) != -1;  };
            std::function GetStartIdx = [](BVH::StacklessTraversalNode node) { return glm::floatBitsToInt(node.Min.w);  };

            CMin = vec3(InverseMatrix * vec4(CMin, 1.0f));
            CMax = vec3(InverseMatrix * vec4(CMax, 1.0f));

            Physics::AABB aabb = { CMin, CMax };

            int Iterations = 0;

            const int MaxIterations = 1024;

            int Pointer = NodeStartIndex;

            Mesh = -1;
            TriangleIndex = -1;

            while (Pointer >= 0 && Iterations < MaxIterations) {

                if (Pointer < NodeStartIndex || Pointer > NodeStartIndex + NodeCount || Pointer < 0 || Pointer > Intersector.m_BVHNodes.size())
                {
                    break;
                }

                Iterations++;

                BVH::StacklessTraversalNode CurrentNode = Intersector.m_BVHNodes[Pointer];

                bool CollidedBox = AABBAABBOverlap(Physics::AABB(glm::vec3(CurrentNode.Min), glm::vec3(CurrentNode.Max)), aabb);

                if (CollidedBox)
                {
                    if (IsLeafNode(CurrentNode)) {

                        int Packed = floatBitsToInt(CurrentNode.Min.w);

                        int Length = Packed & 0xF;

                        for (int Idx = Packed >> 4; Idx < (Packed >> 4) + Length; Idx++) {
                            BVH::Triangle triangle = Intersector.m_BVHTriangles[Idx];

                            const int Offset = 0;

                            vec3 VertexA = Intersector.m_BVHVertices[triangle.PackedData[0] + Offset].position;
                            vec3 VertexB = Intersector.m_BVHVertices[triangle.PackedData[1] + Offset].position;
                            vec3 VertexC = Intersector.m_BVHVertices[triangle.PackedData[2] + Offset].position;

                            if (BoxTriangleOverlap(VertexA, VertexB, VertexC, aabb))
                            {
                                Mesh = triangle.PackedData[3];
                                TriangleIndex = Idx;
                                return true;
                            }
                        }


                        Pointer = (floatBitsToInt(CurrentNode.Max.w));

                        if (Pointer < 0) {
                            break;
                        }

                        Pointer += NodeStartIndex;
                        continue;
                    }

                    else {

                        Pointer++;
                        continue;
                    }

                }

                else {

                    Pointer = (floatBitsToInt(CurrentNode.Max.w));

                    if (Pointer < 0) {
                        break;
                    }

                    Pointer += NodeStartIndex;

                    continue;
                }

                if (Pointer < 0) {
                    break;
                }
            }

            return false;
        }


        glm::vec3 CollideBVHStep(RayIntersector<BVH::StacklessTraversalNode>& Intersector, vec3 CMin, vec3 CMax, const int NodeStartIndex, const int NodeCount, const mat4 InverseMatrix) {

            std::function IsLeafNode = [](BVH::StacklessTraversalNode node) { return glm::floatBitsToInt(node.Min.w) != -1;  };
            std::function GetStartIdx = [](BVH::StacklessTraversalNode node) { return glm::floatBitsToInt(node.Min.w);  };

            CMin = vec3(InverseMatrix * vec4(CMin, 1.0f));
            CMax = vec3(InverseMatrix * vec4(CMax, 1.0f));

            Physics::AABB aabb = { CMin, CMax };

            int Iterations = 0;

            const int MaxIterations = 1024;

            int Pointer = NodeStartIndex;

            glm::vec3 PositionNudge = glm::vec3(0.0f);

            while (Pointer >= 0 && Iterations < MaxIterations) {

                if (Pointer < NodeStartIndex || Pointer > NodeStartIndex + NodeCount || Pointer < 0 || Pointer > Intersector.m_BVHNodes.size())
                {
                    break;
                }

                Iterations++;

                BVH::StacklessTraversalNode CurrentNode = Intersector.m_BVHNodes[Pointer];

                bool CollidedBox = AABBAABBOverlap(Physics::AABB(glm::vec3(CurrentNode.Min), glm::vec3(CurrentNode.Max)), aabb);

                if (CollidedBox)
                {
                    if (IsLeafNode(CurrentNode)) {

                        int Packed = floatBitsToInt(CurrentNode.Min.w);

                        int Length = Packed & 0xF;

                        for (int Idx = Packed >> 4; Idx < (Packed >> 4) + Length; Idx++) {
                            BVH::Triangle triangle = Intersector.m_BVHTriangles[Idx];

                            const int Offset = 0;

                            vec3 VertexA = Intersector.m_BVHVertices[triangle.PackedData[0] + Offset].position;
                            vec3 VertexB = Intersector.m_BVHVertices[triangle.PackedData[1] + Offset].position;
                            vec3 VertexC = Intersector.m_BVHVertices[triangle.PackedData[2] + Offset].position;

                            glm::vec4 CollisionData = glm::vec4(0.0f);

                            if (BoxTriangleOverlap(VertexA, VertexB, VertexC, aabb, CollisionData))
                            {
                                float Distance = CollisionData.w;

                                glm::vec3 Normal = glm::vec3(CollisionData);

                                float Length = glm::length(Normal);

                                Normal /= Length;

                                if (Distance <= 0.5f) {

                                    float DeltaDistance = -Distance;
                                    PositionNudge += Normal * DeltaDistance;
                                }

                            }
                        }


                        Pointer = (floatBitsToInt(CurrentNode.Max.w));

                        if (Pointer < 0) {
                            break;
                        }

                        Pointer += NodeStartIndex;
                        continue;
                    }

                    else {

                        Pointer++;
                        continue;
                    }

                }

                else {

                    Pointer = (floatBitsToInt(CurrentNode.Max.w));

                    if (Pointer < 0) {
                        break;
                    }

                    Pointer += NodeStartIndex;

                    continue;
                }

                if (Pointer < 0) {
                    break;
                }
            }

            return PositionNudge;
        }



        bool CollidePoint(const glm::vec3& Point, RayIntersector<BVH::StacklessTraversalNode>& Intersector)
        {
            Physics::AABB aabb = Physics::AABB(Point - 0.01f, Point + 0.01f);

            int Mesh_ = -1;
            int Tri_ = -1;
            int Entity_ = -1;
            int TriangleIdx = -1;
            int MeshIdx_ = -1;

            for (int i = 0; i < Intersector.m_BVHEntities.size(); i++)
            {
                bool Collided = CollideBVH(Intersector, aabb.Min, aabb.Max, Intersector.m_BVHEntities[i].NodeOffset, Intersector.m_BVHEntities[i].NodeCount, Intersector.m_BVHEntities[i].InverseMatrix, Mesh_, Tri_);

                if (Collided) {
                    MeshIdx_ = Mesh_;
                    TriangleIdx = Tri_;
                    Entity_ = i;
                    return true;
                }

            }

            return false;

        }

        bool CollideBox(const glm::vec3& Min, const glm::vec3& Max, RayIntersector<BVH::StacklessTraversalNode>& Intersector)
        {
            Physics::AABB aabb = Physics::AABB(Min, Max);

            int Mesh_ = -1;
            int Tri_ = -1;
            int Entity_ = -1;
            int TriangleIdx = -1;
            int MeshIdx_ = -1;

            for (int i = 0; i < Intersector.m_BVHEntities.size(); i++)
            {
                bool Collided = CollideBVH(Intersector, aabb.Min, aabb.Max, Intersector.m_BVHEntities[i].NodeOffset, Intersector.m_BVHEntities[i].NodeCount, Intersector.m_BVHEntities[i].InverseMatrix, Mesh_, Tri_);

                if (Collided) {
                    MeshIdx_ = Mesh_;
                    TriangleIdx = Tri_;
                    Entity_ = i;
                    return true;
                }

            }

            return false;

        }

        glm::vec3 CollideBoxSim(const glm::vec3& Min, const glm::vec3& Max, RayIntersector<BVH::StacklessTraversalNode>& Intersector)
        {
            Physics::AABB aabb = Physics::AABB(Min, Max);

            glm::vec3 Total = glm::vec3(0.0f);

            for (int i = 0; i < Intersector.m_BVHEntities.size(); i++)
            {
                glm::vec3 Step = CollideBVHStep(Intersector, aabb.Min, aabb.Max, Intersector.m_BVHEntities[i].NodeOffset, Intersector.m_BVHEntities[i].NodeCount, Intersector.m_BVHEntities[i].InverseMatrix);

                Total += Step;
            }

            return Total;

        }

	}
}


