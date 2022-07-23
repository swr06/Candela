#include "PhysicsIntegrator.h"

namespace Candela {

	namespace Physics {

		void Integrate(std::vector<Entity*>& Objects, float DeltaTime)
		{
			float G = 9.8f / 3250.0f;

			for (auto& e : Objects) {

				if (!e->m_IsPhysicsObject) {
					continue;
				}

				e->m_PhysicsObject.ApplyAcceleration(glm::vec3(0.0f, -G, 0.0f));
			}

			for (auto& e : Objects) {

				if (!e->m_IsPhysicsObject) {
					continue;
				}

				e->m_PhysicsObject.Update(DeltaTime);
			}

		}

	}

}
