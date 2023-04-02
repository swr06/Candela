#include "ComputeShader.h"

namespace GLClasses
{
	ComputeShader::ComputeShader()
	{
		m_ShaderContents = "";
		m_ComputePath = "";
		m_ID = 0;
        m_ComputeID = 0;
	}

	ComputeShader::~ComputeShader()
	{
		Location_map.clear();
		glDeleteProgram(m_ID);
		glUseProgram(0);
		glDeleteShader(m_ComputeID);
	}

	void ComputeShader::CreateComputeShader(const std::string& path)
	{
		if (path.size() > 0)
		{
			std::ifstream file;
			std::stringstream cont;

			file.exceptions(std::ifstream::badbit | std::ifstream::failbit);
			file.open(path, std::ios::in);

			if (file.good() && file.is_open())
			{
				cont << file.rdbuf();
				m_ComputePath = path;
				m_ShaderContents = cont.str();
			}

			file.close();

			char error[256];
			char* ccode = stb_include_file((char*)path.c_str(), (char*)"", (char*)"Core/Shaders/", error);
			m_ShaderContents = ccode;
			free(ccode);

		}

		m_ComputeSize = m_ShaderContents.size();
		m_ComputeHash = CRC::Calculate(m_ShaderContents.c_str(), m_ShaderContents.size(), CRC::CRC_32());
	}

	void ComputeShader::Compile()
	{
		_BVHTextureFlag = false;
        m_ID = glCreateProgram();
        GLuint m_ComputeID = glCreateShader(GL_COMPUTE_SHADER);

        const char* contcstr = m_ShaderContents.c_str();
        glShaderSource(m_ComputeID, 1, &contcstr, 0);
        glCompileShader(m_ComputeID);

        int rvalue;

        glGetShaderiv(m_ComputeID, GL_COMPILE_STATUS, &rvalue);

        if (!rvalue)
        {
            GLchar log[1024];
            GLsizei length;
            glGetShaderInfoLog(m_ComputeID, 1023, &length, log);

            std::cout << "\nCOMPILATION ERROR IN COMPUTE SHADER (" << m_ComputePath << ")" << "\n" << log << "\n\n";
        }

        glAttachShader(m_ID, m_ComputeID);

        glLinkProgram(m_ID);
        glGetProgramiv(m_ID, GL_LINK_STATUS, &rvalue);

        if (!rvalue) 
        {
            GLchar log[1024];
            GLsizei length;
            glGetProgramInfoLog(m_ID, 1023, &length, log);
            std::cout << "\nLINKING ERROR IN COMPUTE SHADER (" << m_ComputePath << ")" << "\n" << log << "\n\n";
        }

        glUseProgram(m_ID);
	}

	void ComputeShader::SetFloat(const std::string& name, GLfloat value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform1f(GetUniformLocation(name), value);
	}

	void ComputeShader::SetInteger(const std::string& name, GLint value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform1i(GetUniformLocation(name), value);
	}

	void ComputeShader::SetBool(const std::string& name, bool value, GLboolean useShader)
	{
		GLint val = value ? GL_TRUE : GL_FALSE;

		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform1i(GetUniformLocation(name), val);
	}

	void ComputeShader::SetIntegerArray(const std::string& name, const GLint* value, GLsizei count, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform1iv(GetUniformLocation(name), count, value);
	}

	void ComputeShader::SetTextureArray(const std::string& name, const GLuint first, const GLuint count, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		for (int i = 0; i < count; i++)
		{
			std::string uniform_name = name + "[" + std::to_string(i) + "]";

			GLint Loc = GetUniformLocation(uniform_name);

			if (Loc < 0) {
				continue;
			}

			glUniform1i(GetUniformLocation(uniform_name), i + first);
		}

		return;
	}

	bool ComputeShader::Recompile()
	{
		uint32_t PrevHash = m_ComputeHash;
		uint32_t PrevSize = m_ComputeSize;

		this->CreateComputeShader(m_ComputePath);

		if (m_ComputeHash != PrevHash || m_ComputeSize != PrevSize) {

			_BVHTextureFlag = false;

			Location_map.clear();
			glDeleteProgram(m_ID);
			glDeleteShader(m_ComputeID);
			glUseProgram(0);

			this->Compile();

			return true;
		}

		return false;
	}

	void ComputeShader::ForceRecompile()
	{
		_BVHTextureFlag = false;

		this->CreateComputeShader(m_ComputePath);

		Location_map.clear();
		glDeleteProgram(m_ID);
		glDeleteShader(m_ComputeID);
		glUseProgram(0);

		this->Compile();

	}

	void ComputeShader::SetVector2f(const std::string& name, GLfloat x, GLfloat y, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform2f(GetUniformLocation(name), x, y);
	}

	void ComputeShader::SetVector2f(const std::string& name, const glm::vec2& value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform2f(GetUniformLocation(name), value.x, value.y);
	}

	void ComputeShader::SetVector3f(const std::string& name, GLfloat x, GLfloat y, GLfloat z, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform3f(GetUniformLocation(name), x, y, z);
	}

	void ComputeShader::SetVector3f(const std::string& name, const glm::vec3& value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform3f(GetUniformLocation(name), value.x, value.y, value.z);
	}

	void ComputeShader::SetVector4f(const std::string& name, GLfloat x, GLfloat y, GLfloat z, GLfloat w, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform4f(GetUniformLocation(name), x, y, z, w);
	}

	void ComputeShader::SetVector4f(const std::string& name, const glm::vec4& value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform4f(GetUniformLocation(name), value.x, value.y, value.z, value.w);
	}

	void ComputeShader::SetMatrix4(const std::string& name, const glm::mat4& matrix, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		//glUniformMatrix4fv(glGetUniformLocation(this->Program, name), 1, GL_FALSE, glm::value_ptr(matrix));
		glUniformMatrix4fv(GetUniformLocation(name), 1, GL_FALSE, glm::value_ptr(matrix));
	}

	void ComputeShader::SetMatrix3(const std::string& name, const glm::mat3& matrix, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniformMatrix3fv(GetUniformLocation(name), 1, GL_FALSE, glm::value_ptr(matrix));
	}


	GLint ComputeShader::GetUniformLocation(const std::string& uniform_name)
	{
		if (Location_map.find(uniform_name) == Location_map.end())
		{
			GLint loc = glGetUniformLocation(m_ID, uniform_name.c_str());

			if (loc == -1)
			{
				std::stringstream s;
				//std::cout << "\nERROR! : UNIFORM NOT FOUND IN COMPUTE SHADER !    |    UNIFORM : " << uniform_name << "  \n\n";
				s << "\nERROR! : UNIFORM NOT FOUND IN COMPUTE SHADER !    |    UNIFORM : " << uniform_name << "  \n\n";

				Candela::Logger::LogToFile(s.str());
			}

			Location_map[uniform_name] = loc;
		}

		return Location_map[uniform_name];
	}
}