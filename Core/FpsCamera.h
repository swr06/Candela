#pragma once

#include <iostream>

#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

namespace Lumen
{
	class FPSCamera
	{
	public : 
		FPSCamera(float fov, float aspect, float zNear = 0.1f, float zFar = 1000.0f, float sensitivity = 0.25f);
		~FPSCamera();

		/*
		Moves the camera on mouse movement. 
		xpos = x position of the mouse cursor
		ypos = y position of the mouse cursor
		*/
		void UpdateOnMouseMovement(double xpos, double ypos);

		/*
		Sets the position of the camera
		*/
		void SetPosition(const glm::vec3& position);

		/*
		Increments the position by a factor
		*/
		void ChangePosition(const glm::vec3& position_increment);

		/*
		Sets the front vector of the camera. Default : (0, 1, 0) (Positive Z)
		*/
		void SetFront(const glm::vec3& front);

		/*
		Sets the rotation of the camera
		*/
		void SetRotation(float angle);

		/*
		Sets the field of view of the camera
		*/
		void SetFov(float fov);

		/*
		Sets the aspect of the camera.
		Remember to divide floats and not integers
		*/
		void SetAspect(float aspect);

		/*
		Sets the near and far plane of the camera
		*/
		void SetNearAndFarPlane(float zNear, float zFar);

		/*
		Sets the perspective matrix based on new parameters
		*/
		void SetPerspectiveMatrix(float fov, float aspect_ratio, float zNear, float zFar);

		/*
		Gets the yaw of the camera
		*/
		inline float GetYaw() const
		{
			return _Yaw;
		}

		/*
		Gets the pitch of the camera
		*/
		inline float GetPitch() const
		{
			return _Pitch;
		}

		/*
		Sets the sensitivity of the camera
		*/
		inline void SetSensitivity(float sensitivity) 
		{
			_Sensitivity = sensitivity;
		}

		/*
		Returns the sensitivity of the camera
		*/
		float GetSensitivity()  const { return _Sensitivity; }

		/*
		Gets the position of the camera
		*/
		inline const glm::vec3& GetPosition() const 
		{
			return m_Position;
		}

		/*
		Gets the fov of the camera
		*/
		inline float GetFov()
		{
			return m_Fov;
		}

		/*
		Gets the rotation of the camera
		*/
		inline float GetRotation()
		{
			return m_Rotation;
		}

		/*
		Gets the vp matrix of the camera
		*/
		inline const glm::mat4& GetViewProjection() const
		{
			return m_ViewProjectionMatrix;
		}

		/*
		Gets the projection matrix of the camera
		*/
		inline const glm::mat4& GetProjectionMatrix() const
		{
			return m_ProjectionMatrix;
		}

		/*
		Gets the view matrix of the camera
		*/
		inline const glm::mat4& GetViewMatrix()
		{
			return m_ViewMatrix;
		}

		/*
		Gets the front vector of the camera
		*/
		inline const glm::vec3& GetFront()
		{
			return m_Front;
		}

		/*
		Gets the up vector of the camera
		*/
		inline const glm::vec3& GetUp()
		{
			return m_Up;
		}

		/*
		Gets the right vector of the camera
		*/
		inline const glm::vec3 GetRight()
		{
			return glm::normalize(glm::cross(m_Front, m_Up));
		}

		/*
		Gets the aspect ratio of the camera
		*/
		inline float GetAspect()
		{
			return m_Aspect;
		}

		/*
		Gets the near plane of the camera
		*/
		inline float GetNearPlane()
		{
			return m_zNear;
		}

		/*
		Gets the far plane of the camera
		*/
		inline float GetFarPlane()
		{
			return m_zFar;
		}

		/*
		resets the acceleration of the camera
		should be called after ApplyAcceleration()
		*/
		inline void ResetAcceleration()
		{
			m_Acceleration = glm::vec3(0.0f);
		}

		/*
		Resets the velocity of the camera
		*/
		inline void ResetVelocity()
		{
			m_Velocity = glm::vec3(0.0f);
		}

		/*
		Applies some acceleration to the camera
		*/
		inline void ApplyAcceleration(const glm::vec3& acceleration)
		{
			m_Acceleration = m_Acceleration + acceleration;
		}

		/*
		Recalculates the view, projection and view projection matrices
		*/
		void Refresh()
		{
			RecalculateProjectionMatrix();
			RecalculateViewMatrix();
		}

		/*
		OnUpdate()
		Should be called every frame
		*/
		void OnUpdate();


		inline glm::vec2 GetPrevMouseCoords() noexcept
		{
			return glm::vec2(_PrevMx, _PrevMy);
		}

		inline void SetPrevMouseCoords(float x, float y) noexcept
		{
			_PrevMx = x;
			_PrevMy = y;
		}

		float _Sensitivity = 0.2;

	private : 

		void RecalculateViewMatrix();
		void RecalculateProjectionMatrix();

		float m_Rotation;
		float m_Fov;
		float m_Aspect;
		float m_zNear;
		float m_zFar;

		glm::vec3 m_Position;
		glm::vec3 m_Front;
		glm::vec3 m_Up;

		glm::vec3 m_Acceleration;
		glm::vec3 m_Velocity;

		glm::mat4 m_ViewMatrix;
		glm::mat4 m_ProjectionMatrix;
		glm::mat4 m_ViewProjectionMatrix;

		// The yaw and pitch of the camera : 
		bool _FirstMove = false;
		float _PrevMx = 0.0f;
		float _PrevMy = 0.0f;
		float _Yaw = 0.0f;
		float _Pitch = 0.0f;
	};
}