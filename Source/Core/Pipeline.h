#pragma once

#include <iostream>
#include <vector>
#include <glad/glad.h>
#include <GLFW/glfw3.h>

#include "Application/Application.h"
#include "GLClasses/VertexArray.h"
#include "GLClasses/VertexBuffer.h"
#include "GLClasses/IndexBuffer.h"
#include "GLClasses/Shader.h"
#include "Utils/Vertex.h"
#include "CollisionHandler.h"

namespace Candela {

	void StartPipeline();
}