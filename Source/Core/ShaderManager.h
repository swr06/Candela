#pragma once

#include <iostream>
#include <string>
#include <map>
#include <unordered_map>

#include "GLClasses/Shader.h"
#include "GLClasses/ComputeShader.h"

namespace Candela
{ 
	namespace ShaderManager
	{
		void CreateShaders();

		void AddShader(const std::string& name, const std::string& vert, const std::string& frag, const std::string& geo = std::string(""));
		void AddComputeShader(const std::string& name, const std::string& comp);
		GLClasses::Shader& GetShader(const std::string& name);
		GLClasses::ComputeShader& GetComputeShader(const std::string& name);
		GLuint GetShaderID(const std::string& name);
		void RecompileShaders();
		void ForceRecompileShaders();
	}
}