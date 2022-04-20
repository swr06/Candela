#pragma once
#include <glm/glm.hpp>
#include <glad/glad.h>

namespace Lumen
{
	struct Vertex
	{
		glm::vec3 position;
		glm::uvec3 normal_tangent_data;
		GLuint texcoords;
	};
}