#pragma once

#include <iostream>
#include <glad/glad.h>
#include <glfw/glfw3.h>

#include "Object.h"
#include "Entity.h"
#include "GLClasses/Shader.h"

#include "FpsCamera.h"

#include "Frustum.h"

namespace Lumen {

	void RenderEntity(Entity& entity, GLClasses::Shader& shader, Frustum& frustum, bool fcull, int entity_num = 0);
	uint64_t QueryPolygonCount();
	void ResetPolygonCount();
}