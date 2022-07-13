#include "PhysicsIntegrator.h"

namespace Lumen {

	namespace Physics {

		void Integrate(std::vector<Entity*>& Objects, float DeltaTime, RayIntersector<BVH::StacklessTraversalNode>& Intersector)
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

				glm::vec3 CurrentMin = glm::vec3(e->m_Model * glm::vec4(e->m_Object->Min, 1.0f));
				glm::vec3 CurrentMax = glm::vec3(e->m_Model * glm::vec4(e->m_Object->Max, 1.0f));

				glm::vec3 Nudge = CollideBoxSim(CurrentMin, CurrentMax, Intersector);

				e->m_PhysicsObject.Position += Nudge;

				//std::cout << "\nNudge : " << Nudge.x << "  " << Nudge.y << "  " << Nudge.z;
			}


			//CollideBoxSim

			for (auto& e : Objects) {

				if (!e->m_IsPhysicsObject) {
					continue;
				}

				e->m_PhysicsObject.Update(DeltaTime);
			}

		}

	}

}
