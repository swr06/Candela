#pragma once 

#include "Plane.h"

#include "FpsCamera.h"

namespace Lumen {

	class Frustum {

	public :

        void Update(FPSCamera& Camera, int Frame);

        Plane Top;
        Plane Bottom;

        Plane Right;
        Plane Left;

        Plane Far;
        Plane Near;

	};

}