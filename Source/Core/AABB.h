#pragma once

#include <iostream>
#include <glm/glm.hpp>

#include "Plane.h"

namespace Candela
{
    struct AABB 
    {
        AABB(const glm::vec3& dim) : m_Dimensions(dim)
        {

        }

        void SetPosition(const glm::vec3& p)
        {
            m_Position = p;
        }

        glm::vec3 m_Position;
        const glm::vec3 m_Dimensions;
    };

    class FrustumBox
    {
    public :

        FrustumBox() {
            Origin = glm::vec3(0.0f);
            Extent = glm::vec3(0.0f);
        }

        FrustumBox(const glm::vec3& o, const glm::vec3& e) {
            Origin = o;
            Extent = e;
        }

        void CreateBox(const glm::vec3& o, const glm::vec3& e) {
            Origin = o;
            Extent = e;
        }

        void CreateBoxMinMax(const glm::vec3& min, const glm::vec3& max) {
            Origin = (min + max) / 2.0f;
            Extent = glm::vec3(max.x - Origin.x, max.y - Origin.y, max.z - Origin.z);
        }

        glm::vec3 Origin;
        glm::vec3 Extent;

        bool IntersectsPlane(const Plane& plane) const
        {
            float r = Extent.x * std::abs(plane.Normal.x) +
                Extent.y * std::abs(plane.Normal.y) + Extent.z * std::abs(plane.Normal.z);

            return -r <= plane.SDF(Origin);
        }

    };
}