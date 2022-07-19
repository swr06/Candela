#include "Maths.h"

#include <glm/gtc/matrix_access.hpp>

glm::mat4 Lumen::GetRotationMatrix(const glm::mat4& Transform)
{
    glm::vec3 scale = glm::vec3(
        glm::length(glm::vec3(glm::column(Transform, 0))),
        glm::length(glm::vec3(glm::column(Transform, 1))),
        glm::length(glm::vec3(glm::column(Transform, 2))));

    glm::mat4 result = glm::glm::mat4();

    result[0][0] = Transform[0][0] / scale.x;
    result[0][1] = Transform[0][1] / scale.x;
    result[0][2] = Transform[0][2] / scale.x;

    result[1][0] = Transform[1][0] / scale.y;
    result[1][1] = Transform[1][1] / scale.y;
    result[1][2] = Transform[1][2] / scale.y;

    result[2][0] = Transform[2][0] / scale.z;
    result[2][1] = Transform[2][1] / scale.z;
    result[2][2] = Transform[2][2] / scale.z;

    result[3][3] = Transform[3][3];

    return result;

}

glm::vec3 Lumen::GetForwardVector(const glm::mat4& Transform)
{
    return glm::vec4(0.0f, 0.0f, -1.0f, 1.0f) * glm::inverse(GetRotationMatrix(Transform));
}

glm::vec3 Lumen::GetRightVector(const glm::mat4&  Transform)
{
    return glm::vec4(1.0f, 0.0f, 0.0f, 1.0f) * glm::inverse(GetRotationMatrix(Transform));

}

glm::vec3 Lumen::GetUpVector(const glm::mat4& Transform)
{
    return glm::vec4(0.0f, 1.0f, 0.0f, 1.0f) * glm::inverse(GetRotationMatrix(Transform));
}


glm::vec3 Lumen::GetPosition(const glm::mat4& Transform)
{
    return Transform[3] * Transform[3][3];
}

void Lumen::SetPosition(glm::mat4& _inOutTransform, const glm::vec3& Position)
{
    _inOutTransform[3][0] = Position.x / _inOutTransform[3][3];
    _inOutTransform[3][1] = Position.y / _inOutTransform[3][3];
    _inOutTransform[3][2] = Position.z / _inOutTransform[3][3];
}