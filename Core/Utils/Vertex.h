#pragma once
#include <glm/glm.hpp>
#include <glad/glad.h>

namespace Candela
{
	struct Vertex
	{
		glm::vec4 position;
		glm::uvec3 normal_tangent_data;
		GLuint texcoords;
	};
}