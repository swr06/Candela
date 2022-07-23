#pragma once

#include <iostream>
#include <glm/glm.hpp>
#include <glad/glad.h>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include <cmath>

namespace Candela {

	void GenerateJitterStuff();
	glm::vec2 GetTAAJitter(int CurrentFrame);
	glm::mat4 GetTAAJitterMatrix(int CurrentFrame, const glm::vec2& resolution);
}