#pragma once

#include <iostream>
#include <glm/glm.hpp>

namespace Lumen
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
}