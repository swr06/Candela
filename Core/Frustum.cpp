#include "Frustum.h"

void Lumen::Frustum::Update(FPSCamera& Camera, int Frame)
{
    const float HalfVSide = Camera.GetFarPlane()  * tanf(Camera.GetFov() * 0.5f);
    const float HalfHSide = HalfVSide * Camera.GetAspect();
    const glm::vec3 FarPlaneMultiplier = Camera.GetFarPlane() * Camera.GetFront();

    this->Near = { Camera.GetPosition() + Camera.GetNearPlane() * Camera.GetFront(), Camera.GetFront()  };
    this->Far = { Camera.GetPosition() + FarPlaneMultiplier, -Camera.GetFront() };
    this->Right = { Camera.GetPosition(), glm::cross(Camera.GetUp(), FarPlaneMultiplier + Camera.GetRight() * HalfHSide)};
    this->Left = { Camera.GetPosition(), glm::cross(FarPlaneMultiplier - Camera.GetRight() * HalfHSide, Camera.GetUp()) };
    this->Top = { Camera.GetPosition(), glm::cross(Camera.GetRight(), FarPlaneMultiplier - Camera.GetUp() * HalfVSide) };
    this->Bottom = { Camera.GetPosition(), glm::cross(FarPlaneMultiplier + Camera.GetUp() * HalfVSide, Camera.GetRight()) };
}
