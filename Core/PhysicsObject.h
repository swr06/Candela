#pragma once 

#include <iostream>

#include <glm/glm.hpp>

namespace Lumen {

	namespace Physics {


		class PhysicsObject {

		public:

			PhysicsObject() {

				Position = glm::vec3(0.0f);
				PreviousPosition = glm::vec3(0.0f);
				Acceleration = glm::vec3(0.0f);
			}

			void Update(float dt) {

				glm::vec3 PositionBeforeUpdate = Position;
				glm::vec3 VelocityVector = Position - PreviousPosition;

				Position = Position + VelocityVector;
				Position = Position + (Acceleration * (dt * dt));
				PreviousPosition = PositionBeforeUpdate;

				//std::cout << "\n" << Position.x << "  " << Position.y << "  " << Position.z << "  ";

				Acceleration = glm::vec3(0.0f);
			}

			void ApplyAcceleration(const glm::vec3& A) {
				Acceleration = A;
			}

			glm::vec3 Position;
			glm::vec3 PreviousPosition;
			glm::vec3 Acceleration;

		};
	}

}
