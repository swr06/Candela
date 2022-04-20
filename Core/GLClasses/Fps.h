#pragma once

#include <glfw/glfw3.h> // For glfwGetTime()

#include <sstream>

namespace GLClasses
{
	void DisplayFrameRate(GLFWwindow* pWindow, const std::string& title);
}