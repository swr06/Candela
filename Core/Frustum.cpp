#include "Frustum.h"

void Candela::Frustum::Update(FPSCamera& Camera, int Frame)
{
    float HalfVSide = Camera.GetFarPlane() * glm::tan(glm::radians(Camera.GetFov()) / 2.0f);
    float HalfHSide = HalfVSide * Camera.GetAspect();
    const glm::vec3 FarPlaneMultiplier = Camera.GetFarPlane() * Camera.GetFront();

    this->Near = { Camera.GetPosition() + Camera.GetNearPlane() * Camera.GetFront(), Camera.GetFront()  };
    this->Far = { Camera.GetPosition() + FarPlaneMultiplier, -Camera.GetFront() };
    this->Right = { Camera.GetPosition(), glm::cross(Camera.GetUp(), FarPlaneMultiplier + Camera.GetRight() * HalfHSide)};
    this->Left = { Camera.GetPosition(), glm::cross(FarPlaneMultiplier - Camera.GetRight() * HalfHSide, Camera.GetUp()) };
    this->Top = { Camera.GetPosition(), glm::cross(Camera.GetRight(), FarPlaneMultiplier - Camera.GetUp() * HalfVSide) };
    this->Bottom = { Camera.GetPosition(), glm::cross(FarPlaneMultiplier + Camera.GetUp() * HalfVSide, Camera.GetRight()) };
}

bool Candela::Frustum::TestBox(const FrustumBox& aabb, const glm::mat4& ModelMatrix)
{
    glm::vec3 Center = glm::vec3(ModelMatrix * glm::vec4(aabb.Origin, 1.0f));

    glm::vec3 RightVector = ModelMatrix[0] * aabb.Extent.x;
    glm::vec3 UpVector = ModelMatrix[1] * aabb.Extent.y;
    glm::vec3 ForwardVector = -ModelMatrix[2] * aabb.Extent.z;

    float XBasis = std::abs(glm::dot(glm::vec3(1.0f, 0.0f, 0.0f), RightVector)) +
        std::abs(glm::dot(glm::vec3(1.0f, 0.0f, 0.0f), UpVector)) +
        std::abs(glm::dot(glm::vec3(1.0f, 0.0f, 0.0f), ForwardVector));

    float YBasis = std::abs(glm::dot(glm::vec3(0.0f, 1.0f, 0.0f), RightVector)) +
        std::abs(glm::dot(glm::vec3(0.0f, 1.0f, 0.0f), UpVector)) +
        std::abs(glm::dot(glm::vec3(0.0f, 1.0f, 0.0f), ForwardVector));

    float ZBasis = std::abs(glm::dot(glm::vec3(0.0f, 0.0f, 1.0f), RightVector)) +
        std::abs(glm::dot(glm::vec3(0.0f, 0.0f, 1.0f), UpVector)) +
        std::abs(glm::dot(glm::vec3(0.0f, 0.0f, 1.0f), ForwardVector));

    FrustumBox TransformedBox(Center, glm::vec3(XBasis, YBasis, ZBasis));

    return (TransformedBox.IntersectsPlane(Left) && TransformedBox.IntersectsPlane(Right) &&
            TransformedBox.IntersectsPlane(Top) && TransformedBox.IntersectsPlane(Bottom) &&
            TransformedBox.IntersectsPlane(Near) && TransformedBox.IntersectsPlane(Far));
}
