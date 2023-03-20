#pragma once

#include <glm/glm.hpp>
#include "FpsCamera.h"

#include "Frustum.h"

#include <GLFW/glfw3.h>

#include "AABB.h"

namespace Candela
{
	class Player
	{
	public :

		Player();
		void OnUpdate(GLFWwindow* window, float dt, float speed, int frame);

		void TestCollision(glm::vec3& position, glm::vec3 vel);
		void Jump();

		FPSCamera Camera;
		bool Freefly = false;
		float Sensitivity = 0.25;
		float Speed = 0.1250f;

		glm::vec3 m_Position;
		glm::vec3 m_Velocity;
		glm::vec3 m_Acceleration;
		AABB m_AABB;
		bool m_isOnGround;
		bool DisableCollisions = false;

		Frustum CameraFrustum;

	private :

	};
}