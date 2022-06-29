#pragma once

#include <iostream>
#include <vector>
#include <glad/glad.h>
#include <glfw/glfw3.h>

#include "Application/Application.h"
#include "GLClasses/VertexArray.h"
#include "GLClasses/VertexBuffer.h"
#include "GLClasses/IndexBuffer.h"
#include "GLClasses/Shader.h"

#include "CollisionHandler.h"

namespace Lumen {

	void StartPipeline();
}