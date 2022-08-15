#pragma once 

#include "Plane.h"

#include "FpsCamera.h"

#include "AABB.h"

namespace Candela {

	class Frustum {

	public :

        void Update(FPSCamera& Camera, int Frame);

        bool TestBox(const FrustumBox& aabb, const glm::mat4& ModelMatrix);

        Plane Top;
        Plane Bottom;

        Plane Right;
        Plane Left;

        Plane Far;
        Plane Near;

	};

}