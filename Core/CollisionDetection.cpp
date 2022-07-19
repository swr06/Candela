#include "CollisionDetection.h"


namespace Lumen {

    namespace Physics {

        typedef float f32;

        bool TestAxis(const glm::vec3& _axis, const OBBProperties& _obb,
            const glm::vec3 TriangleVertices[3], glm::vec3& _inOutAxis, f32& _inOutPenetration,
            std::string& _outDebugInfo)
        {
            f32 obbMax = -std::numeric_limits<f32>::max();
            f32 obbMin = std::numeric_limits<f32>::max();

            for (const glm::vec3& obbPoint : _obb.m_Coordinates)
            {
                const f32 distanceOnAxis = glm::dot(obbPoint, _axis);

                obbMax = glm::max(obbMax, distanceOnAxis);
                obbMin = glm::min(obbMin, distanceOnAxis);
            }

            f32 triMax = -std::numeric_limits<f32>::max();
            f32 triMin = std::numeric_limits<f32>::max();

            for (int i = 0; i < 3; i++)
            {
                const glm::vec3& triPoint = TriangleVertices[i];
                const f32 distanceOnAxis = glm::dot(triPoint, _axis);

                triMax = glm::max(triMax, distanceOnAxis);
                triMin = glm::min(triMin, distanceOnAxis);
            }

            const f32 obbRange = obbMax - obbMin;
            const f32 triRange = triMax - triMin;

            if (glm::epsilonEqual(triMax, triMin, glm::epsilon<f32>()))
            {
                return true;
            }

            const f32 range = obbRange + triRange;
            const f32 span = glm::max(obbMax, triMax) - glm::min(obbMin, triMin);

            if (range >= span)
            {
                const f32 penetration = range - span;

                const f32 obbCenter = obbMin + (obbMax - obbMin) / 2.f;
                const f32 triCenter = triMin + (triMax - triMin) / 2.f;

                assert(penetration >= 0.f);
                if (penetration < _inOutPenetration)
                {
                    // Always want a normal pointed towards the intersecting triangle.
                    const glm::vec3 direction = obbCenter < triCenter ? _axis : -_axis;

                    _inOutPenetration = penetration;
                    _inOutAxis = direction;
                    _outDebugInfo = "Axis";
                }

                return true;
            }

            return false;
        }

        bool TestCrossProductAxis(
            const glm::vec3& _axisA,
            const glm::vec3& _axisB,
            const OBBProperties& _obb,
            const glm::vec3 TriangleVertices[3],
            glm::vec3& _inOutAxis,
            f32& _inOutPenetration, std::string& _outDebugInfo)
        {
            if (glm::abs(glm::dot(_axisA, _axisB)) > 0.99f)
            {
                // The axes are close to parallel, so skip this test.
                return true;
            }

            const glm::vec3 testAxis = glm::normalize(glm::cross(_axisA, _axisB));

            const f32 oldPenetration = _inOutPenetration;

            const bool result = TestAxis(testAxis, _obb, TriangleVertices, _inOutAxis, _inOutPenetration, _outDebugInfo);

            if (oldPenetration != _inOutPenetration)
            {
                _outDebugInfo = "Cross Product Axis";
            }

            return result;
        }

        bool TestTriangleNormalAxis(
            const OBBProperties& _obb,
            const glm::vec3 TriangleVertices[3],
            glm::vec3& _inOutAxis,
            f32& _inOutPenetration, std::string& _outDebugInfo)
        {
            const glm::vec3 axis = glm::normalize(
                glm::cross(
                    glm::normalize(TriangleVertices[1] - TriangleVertices[0]),
                    glm::normalize(TriangleVertices[2] - TriangleVertices[1])));

            f32 obbMax = -std::numeric_limits<f32>::max();
            f32 obbMin = std::numeric_limits<f32>::max();

            for (const glm::vec3& obbPoint : _obb.m_Coordinates)
            {
                const f32 distanceOnAxis = glm::dot(obbPoint, axis);

                obbMax = glm::max(obbMax, distanceOnAxis);
                obbMin = glm::min(obbMin, distanceOnAxis);
            }

            const f32 triDistance = glm::dot(TriangleVertices[0], axis);

            if (obbMax > triDistance && obbMin < triDistance)
            {
                const f32 penetration = triDistance - obbMin;

                assert(penetration >= 0.f);
                if (penetration < _inOutPenetration)
                {
                    _inOutPenetration = penetration;

                    // Always want a normal pointed towards the intersecting triangle.
                    _inOutAxis = -axis;

                    _outDebugInfo = "Triangle Normal";
                }

                return true;
            }

            return false;
        }

        std::optional<CollisionResult> CollideTriOBB(const OBBProperties& _obb, const glm::vec3 TriangleVertices[3])
        {
            if (TriangleVertices[1] == TriangleVertices[0] || TriangleVertices[2] == TriangleVertices[1] || TriangleVertices[2] == TriangleVertices[0])
            {
                return std::nullopt;
            }

            const glm::vec3 triEdge0 = glm::normalize(TriangleVertices[1] - TriangleVertices[0]);
            const glm::vec3 triEdge1 = glm::normalize(TriangleVertices[2] - TriangleVertices[1]);
            const glm::vec3 triEdge2 = glm::normalize(TriangleVertices[0] - TriangleVertices[2]);

            glm::vec3 chosenAxis = glm::vec3();
            f32 penetration = std::numeric_limits<f32>::max();
            std::string debug;

            if (
                !TestCrossProductAxis(_obb.m_X, triEdge0, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestCrossProductAxis(_obb.m_X, triEdge1, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestCrossProductAxis(_obb.m_X, triEdge2, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestCrossProductAxis(_obb.m_Y, triEdge0, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestCrossProductAxis(_obb.m_Y, triEdge1, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestCrossProductAxis(_obb.m_Y, triEdge2, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestCrossProductAxis(_obb.m_Z, triEdge0, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestCrossProductAxis(_obb.m_Z, triEdge1, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestCrossProductAxis(_obb.m_Z, triEdge2, _obb, TriangleVertices, chosenAxis, penetration, debug))
            {
                return std::nullopt;
            }

            if (
                !TestAxis(_obb.m_X, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestAxis(_obb.m_Y, _obb, TriangleVertices, chosenAxis, penetration, debug)
                || !TestAxis(_obb.m_Z, _obb, TriangleVertices, chosenAxis, penetration, debug))
            {
                return std::nullopt;
            }

            if (!TestTriangleNormalAxis(_obb, TriangleVertices, chosenAxis, penetration, debug))
            {
                return std::nullopt;
            }

            CollisionResult result;
            result.Normal = chosenAxis;
            result.Distance = -penetration;
            // result.m_DebugInfo = debug;
            return result;
        }


        std::optional<CollisionResult> OBBTriangleCollision(const glm::mat4& Transform, SimpleAABB Bounds, glm::vec3 Vertices[3], const glm::vec3& TriangleOffset)
        {
            OBBProperties OBB = GetOBBProperties(Transform, Bounds, TriangleOffset);
            return CollideTriOBB(OBB, Vertices);
        }

    }

}
