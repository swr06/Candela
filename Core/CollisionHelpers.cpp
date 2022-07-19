#include "CollisionHelpers.h"

#include "Maths.h"

Lumen::OBBProperties Lumen::GetOBBProperties(const glm::mat4& Transform, const SimpleAABB& Bounds, const glm::vec3& PositionOffset)
{
    OBBProperties properties;

    glm::vec3 BoundsPosition = (Bounds.Min + Bounds.Max) / 2.0f;
    glm::vec3 Extents = Bounds.Max - Bounds.Min;

    properties.m_Origin = GetPosition(Transform) + BoundsPosition - PositionOffset;
    properties.m_X = glm::normalize(GetRightVector(Transform));
    properties.m_Y = glm::normalize(GetUpVector(Transform));
    properties.m_Z = glm::normalize(GetForwardVector(Transform));

    const glm::vec3 obbExtents = Extents;

    properties.m_Coordinates[0] = properties.m_Origin + properties.m_X * obbExtents.x + properties.m_Y * obbExtents.y + properties.m_Z * obbExtents.z;
    properties.m_Coordinates[1] = properties.m_Origin - properties.m_X * obbExtents.x + properties.m_Y * obbExtents.y + properties.m_Z * obbExtents.z;

    properties.m_Coordinates[2] = properties.m_Origin + properties.m_X * obbExtents.x - properties.m_Y * obbExtents.y + properties.m_Z * obbExtents.z;
    properties.m_Coordinates[3] = properties.m_Origin - properties.m_X * obbExtents.x - properties.m_Y * obbExtents.y + properties.m_Z * obbExtents.z;

    properties.m_Coordinates[4] = properties.m_Origin + properties.m_X * obbExtents.x + properties.m_Y * obbExtents.y - properties.m_Z * obbExtents.z;
    properties.m_Coordinates[5] = properties.m_Origin - properties.m_X * obbExtents.x + properties.m_Y * obbExtents.y - properties.m_Z * obbExtents.z;

    properties.m_Coordinates[6] = properties.m_Origin + properties.m_X * obbExtents.x - properties.m_Y * obbExtents.y - properties.m_Z * obbExtents.z;
    properties.m_Coordinates[7] = properties.m_Origin - properties.m_X * obbExtents.x - properties.m_Y * obbExtents.y - properties.m_Z * obbExtents.z;

    return properties;
}
