#pragma once 

#include "Physics.h"

#include "Entity.h"

#include <glm/glm.hpp>

#include <cmath>

namespace Candela {

	namespace Physics {

		/*
		Verlet integration 
			xn+1 = 2xn - xn-1 + an (dt)^2
			or, xn+1 = xn + vn * dt; 

			Key : Velocity is deduced from the last step!
		*/

		void Integrate(std::vector<Entity*>& Objects, float DeltaTime);


	}

}