#include "Player.h"
#include "Utils/Random.h"

namespace Candela
{
	Player::Player() : Camera(90.0f, 800.0f / 600.0f, 0.02f, 850.0f), m_AABB(glm::vec3(0.3f, 1.0f, 0.3f))
	{
		m_Acceleration = glm::vec3(0.0f);
		m_Velocity = glm::vec3(0.0f);
		m_Position = glm::vec3(0.1f, 4.0f, 0.1f);
		Freefly = true;
		m_isOnGround = false;
		m_AABB.m_Position = m_Position;
	}

	void Player::OnUpdate(GLFWwindow* window, float dt, float speed, int frame)
	{
		if (frame < 6) {
			Camera.SetPosition(m_Position);
			return;
		}

		glm::vec3 StartPosition = m_Position;

		float camera_speed = speed;

		CameraFrustum.Update(Camera, frame);

		if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
		{
			// Take the cross product of the camera's right and up.
			glm::vec3 front = -glm::cross(Camera.GetRight(), Camera.GetUp());
			m_Acceleration += (front * camera_speed);
		}

		if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
		{
			glm::vec3 back = glm::cross(Camera.GetRight(), Camera.GetUp());
			m_Acceleration += (back * camera_speed);
		}

		if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
		{
			m_Acceleration += (-(Camera.GetRight() * camera_speed));
		}

		if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
		{
			m_Acceleration += (Camera.GetRight() * camera_speed);
		}

		if (glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS)
		{
			m_Acceleration.y -= camera_speed * 1.35f;
		}

		if (glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS)
		{
			float jump_speed = 0.06f;

			if (!Freefly) 
			{
				if (m_isOnGround)
				{
					m_isOnGround = false;
					m_Acceleration.y += jump_speed * 14.0f;
				}
			}

			else 
			{
				m_Acceleration.y += camera_speed;
			}
		}


		Camera.SetSensitivity(Sensitivity);

		m_Velocity += m_Acceleration;
		m_Acceleration = { 0, 0, 0 };

		// Gravity : 
		if (!Freefly) 
		{
			if (!m_isOnGround) 
			{
				m_Velocity.y -= 0.2 * dt;
			}

			m_isOnGround = false;
		}

		// Test collisions on three axes 
		m_Position.x += m_Velocity.x * dt;
		TestCollision(m_Position, glm::vec3(m_Velocity.x, 0.0f, 0.0f));
		m_Position.y += m_Velocity.y * dt;
		TestCollision(m_Position, glm::vec3(0.0f, m_Velocity.y, 0.0f));
		m_Position.z += m_Velocity.z * dt;
		TestCollision(m_Position, glm::vec3(0.0f, 0.0f, m_Velocity.z));

		// 
		m_AABB.SetPosition(m_Position);

		if (!Freefly) {
			m_Velocity.x *= 0.825f;
			m_Velocity.z *= 0.825f;
		}
		else {

			m_Velocity.x *= 0.755f;
			m_Velocity.z *= 0.755f;
		}
		

		if (Freefly) {
			m_Velocity.y *= 0.765f;
		}

		Camera.SetPosition(m_Position);


	}

	static bool Test3DAABBCollision(const glm::vec3& pos_1, const glm::vec3& dim_1, const glm::vec3& pos_2, const glm::vec3& dim_2)
	{
		if (pos_1.x < pos_2.x + dim_2.x &&
			pos_1.x + dim_1.x > pos_2.x &&
			pos_1.y < pos_2.y + dim_2.y &&
			pos_1.y + dim_1.y > pos_2.y &&
			pos_1.z < pos_2.z + dim_2.z &&
			pos_1.z + dim_1.z > pos_2.z)
		{
			return true;
		}

		return false;
	}

	void Player::TestCollision(glm::vec3& position, glm::vec3 vel)
	{
		if (DisableCollisions && Freefly) {
			return;
		}

		
	}

	void Player::Jump()
	{
		return;
	}

}