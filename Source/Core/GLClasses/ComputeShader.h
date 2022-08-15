#pragma once

#include <glad/glad.h>
#include <glfw/glfw3.h>
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtc/type_ptr.hpp>

#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <fstream>
#include <chrono>
#include <unordered_map>
#include <filesystem>

#include "../Application/Logger.h"

#include "stb_include.h"

#include <crc/CRC.h>

namespace GLClasses
{
	class ComputeShader
	{
	public :
		ComputeShader();
		~ComputeShader();

		ComputeShader(const ComputeShader&) = delete;
		ComputeShader operator=(ComputeShader const&) = delete;
		ComputeShader(ComputeShader&& v)
		{
			m_ID = v.m_ID;
			m_ComputeID = v.m_ComputeID;
			m_ComputePath = v.m_ComputePath;
			m_ShaderContents = v.m_ShaderContents;

			v.m_ID = 0;
			v.m_ComputeID = 0;
		}

		void CreateComputeShader(const std::string& path);
		void Compile();
		void Use() const noexcept { glUseProgram(m_ID); return; }

		void SetFloat(const std::string& name, GLfloat value, GLboolean useShader = GL_FALSE);
		void SetInteger(const std::string& name, GLint value, GLboolean useShader = GL_FALSE);
		void SetBool(const std::string& name, bool value, GLboolean useShader = GL_FALSE);
		void SetVector2f(const std::string& name, GLfloat x, GLfloat y, GLboolean useShader = GL_FALSE);
		void SetVector2f(const std::string& name, const glm::vec2& value, GLboolean useShader = GL_FALSE);
		void SetVector3f(const std::string& name, GLfloat x, GLfloat y, GLfloat z, GLboolean useShader = GL_FALSE);
		void SetVector3f(const std::string& name, const glm::vec3& value, GLboolean useShader = GL_FALSE);
		void SetVector4f(const std::string& name, GLfloat x, GLfloat y, GLfloat z, GLfloat w, GLboolean useShader = GL_FALSE);
		void SetVector4f(const std::string& name, const glm::vec4& value, GLboolean useShader = GL_FALSE);
		void SetMatrix4(const std::string& name, const glm::mat4& matrix, GLboolean useShader = GL_FALSE);
		void SetMatrix3(const std::string& name, const glm::mat3& matrix, GLboolean useShader = GL_FALSE);
		void SetIntegerArray(const std::string& name, const GLint* value, GLsizei count, GLboolean useShader = GL_FALSE);
		void SetTextureArray(const std::string& name, const GLuint first, const GLuint count, GLboolean useShader = GL_FALSE);

		bool Recompile();
		void ForceRecompile();

		GLuint FetchUniformLocation(const std::string& name)
		{
			return GetUniformLocation(name);
		}

		GLuint GetProgram() { return m_ID; }

		bool _BVHTextureFlag = false; // Internal.

	private :

		std::unordered_map<std::string, GLint> Location_map; // To avoid unnecessary calls to glGetUniformLocation()
		GLint GetUniformLocation(const std::string& uniform_name);

		std::string m_ShaderContents = "";
		std::string m_ComputePath = "";
		GLuint m_ID = 0;
		GLuint m_ComputeID = 0;

		uint32_t m_ComputeSize = 0;
		uint32_t m_ComputeHash = 0;

	};
}