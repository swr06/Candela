#pragma once

#include <iostream>
#include <string>
#include <map>
#include <unordered_map>

#include "GLClasses/Shader.h"

namespace Lumen
{ 
	namespace ShaderManager
	{
		void CreateShaders();

		void AddShader(const std::string& name, const std::string& vert, const std::string& frag, const std::string& geo = std::string(""));
		GLClasses::Shader& GetShader(const std::string& name);
		GLuint GetShaderID(const std::string& name);
		void RecompileShaders();
	}
}