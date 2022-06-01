#pragma once 

#include <iostream>

#include <glm/glm.hpp>

#include <glad/glad.h>

#include "BVH/Intersector.h"

#include "GLClasses/Framebuffer.h"

#include "FpsCamera.h"
#include "Utility.h"

#include <glfw/glfw3.h>

namespace Lumen {

	// 64 bytes per surfel
	struct Surfel {
		glm::vec4 Position; // <- Radius in w 
		glm::vec4 Normal; // <- Luminance map offset in w
		glm::vec4 Radiance; // <- Accumulated frames in w
		glm::vec4 Extra;  // <- Surfel ID.. etc
	};

	class SurfelGIHandler
	{
		public : 
	
		SurfelGIHandler();

		void Initialize();
		void UpdateSurfels(int Frame, GLClasses::Framebuffer& GBuffer, const CommonUniforms& Uniforms, FPSCamera& Camera);

		GLuint m_SurfelCellVolume; // <- Surfel grid, each grid can hold 4 surfels
	};
}