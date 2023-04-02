#include "Shader.h"
#define STB_INCLUDE_LINE_NONE
#include "stb_include.h"


namespace GLClasses
{
	static std::string GetFileName(std::string path)
	{
		std::filesystem::path pth = std::filesystem::path(path.c_str()).filename();
		return pth.string();
	}

	Shader::~Shader()
	{
		glDeleteProgram(m_Program);
		glUseProgram(0);
	}

	void Shader::CompileShaders()
	{
		_BVHTextureFlag = false;
		m_Program = 0;
		auto start = std::chrono::steady_clock::now();

		GLuint vs = 0;
		GLuint fs = 0;
		GLint successful = 0;
		GLchar GLInfoLog[512];

		GLuint gs = 0;

		if (m_GeometryData.size() > 0)
		{
			gs = glCreateShader(GL_GEOMETRY_SHADER);

			const char* geo_source = m_GeometryData.c_str();

			glShaderSource(gs, 1, &geo_source, 0);
			glCompileShader(gs);
			glGetShaderiv(gs, GL_COMPILE_STATUS, &successful);

			if (!successful)
			{
				std::stringstream s;
				glGetShaderInfoLog(gs, 512, NULL, GLInfoLog);
				std::cout << "\nCOMPILATION ERROR IN GEOMETRY SHADER (" << m_GeometryPath << ")" << "\n" << GLInfoLog << "\n\n";
				s << "\nCOMPILATION ERROR IN GEOMETRY SHADER (" << m_GeometryPath << ")" << "\n" << GLInfoLog << "\n\n";

				Candela::Logger::LogToFile(s.str());
			}

			GLint log_length = 0;

			glGetShaderiv(gs, GL_INFO_LOG_LENGTH, &log_length);

			if (log_length > 0)
			{
				std::stringstream s;

				std::string shaderlog(log_length, 0);
				glGetShaderInfoLog(gs, log_length, 0, shaderlog.data());
				std::cout << "Geometry Shader compilation log: " << shaderlog << std::endl;
				s << "Geometry Shader compilation log: " << shaderlog << std::endl;

				Candela::Logger::LogToFile(s.str());
			}
		}

		vs = glCreateShader(GL_VERTEX_SHADER);
		fs = glCreateShader(GL_FRAGMENT_SHADER);

		const char* vs_char = m_VertexData.c_str();
		const char* fs_char = m_FragmentData.c_str();

		glShaderSource(vs, 1, &vs_char, 0);
		glShaderSource(fs, 1, &fs_char, 0);

		glCompileShader(vs);

		glGetShaderiv(vs, GL_COMPILE_STATUS, &successful);

		if (!successful)
		{
			std::stringstream s;

			glGetShaderInfoLog(vs, 512, NULL, GLInfoLog);
			std::cout << "\nCOMPILATION ERROR IN VERTEX SHADER (" << m_VertexPath << ")" << "\n" << GLInfoLog << "\n\n";
			s << "\nCOMPILATION ERROR IN VERTEX SHADER (" << m_VertexPath << ")" << "\n" << GLInfoLog << "\n\n";

			Candela::Logger::LogToFile(s.str());
		}


		GLint log_length = 0;
		glGetShaderiv(vs, GL_INFO_LOG_LENGTH, &log_length);
		if (log_length > 0)
		{
			std::stringstream s;

			std::string shaderlog(log_length, 0);
			glGetShaderInfoLog(vs, log_length, 0, shaderlog.data());
			std::cout << "Shader compilation log: " << shaderlog << std::endl;
			s << "Shader compilation log: " << shaderlog << std::endl;

			Candela::Logger::LogToFile(s.str());
		}

		glCompileShader(fs);
		glGetShaderiv(fs, GL_COMPILE_STATUS, &successful);

		if (!successful)
		{
			std::stringstream s;

			glGetShaderInfoLog(fs, 512, NULL, GLInfoLog);
			std::cout << "\nCOMPILATION ERROR IN FRAGMENT SHADER (" << m_FragmentPath << ")" << "\n" << GLInfoLog << "\n";
			s << "\nCOMPILATION ERROR IN FRAGMENT SHADER (" << m_FragmentPath << ")" << "\n" << GLInfoLog << "\n";

			Candela::Logger::LogToFile(s.str());
		}

		log_length = 0;
		glGetShaderiv(fs, GL_INFO_LOG_LENGTH, &log_length);
		if (log_length > 0)
		{
			std::stringstream s;

			std::string shaderlog(log_length, 0);
			glGetShaderInfoLog(fs, log_length, 0, shaderlog.data());
			std::cout << "Shader compilation log: " << shaderlog << std::endl;
			s << "Shader compilation log: " << shaderlog << std::endl;

			Candela::Logger::LogToFile(s.str());
		}

		m_Program = glCreateProgram();
		glAttachShader(m_Program, vs);
		glAttachShader(m_Program, fs);

		if (m_GeometryData.size() > 0)
		{
			glAttachShader(m_Program, gs);
		}

		glLinkProgram(m_Program);

		glGetProgramiv(m_Program, GL_LINK_STATUS, &successful);

		if (!successful)
		{
			std::stringstream s;

			glGetProgramInfoLog(m_Program, 512, NULL, GLInfoLog);
			std::cout << "ERROR : SHADER LINKING FAILED : \n" << GLInfoLog << std::endl;
			s << "ERROR : SHADER LINKING FAILED : \n" << GLInfoLog << std::endl;

			Candela::Logger::LogToFile(s.str());
		}

		glDeleteShader(vs);
		glDeleteShader(fs);
		glDeleteShader(gs);

		auto end = std::chrono::steady_clock::now();
		double elapsed_time = std::chrono::duration_cast<std::chrono::duration<double>>(end - start).count();
	}

	void Shader::CreateShaderProgramFromFile(const std::string& vertex_pth, const std::string& fragment_pth, const std::string& geometry_path)
	{
		if (geometry_path.size() > 0)
		{
			std::ifstream geo_file;
			std::stringstream g_cont;

			geo_file.exceptions(std::ifstream::badbit | std::ifstream::failbit);
			geo_file.open(geometry_path, std::ios::in);

			if (geo_file.good() && geo_file.is_open())
			{
				g_cont << geo_file.rdbuf();
				m_GeometryPath = geometry_path;
				m_GeometryData = g_cont.str();
			}

			geo_file.close();
		}

		std::stringstream v_cont;
		std::stringstream f_cont;
		std::ifstream vertex_file;
		std::ifstream frag_file;

		vertex_file.exceptions(std::ifstream::badbit | std::ifstream::failbit);
		frag_file.exceptions(std::ifstream::badbit | std::ifstream::failbit);

		vertex_file.open(vertex_pth, std::ios::in);
		frag_file.open(fragment_pth, std::ios::in);

		m_VertexPath = vertex_pth;
		m_FragmentPath = fragment_pth;

		if (vertex_file.good() && frag_file.good())
		{
			v_cont << vertex_file.rdbuf();
			f_cont << frag_file.rdbuf();
			vertex_file.close();
			frag_file.close();

			char error[256];
			char* vcode = stb_include_file((char*)vertex_pth.c_str(), (char*)"", (char*)"Core/Shaders/", error);
			m_VertexData = vcode;
            free(vcode);

			char* fcode = stb_include_file((char*)fragment_pth.c_str(), (char*)"", (char*)"Core/Shaders/", error);
			m_FragmentData = fcode;
            free(fcode);
		}

		// Create hashes 

		m_VertexSize = m_VertexData.size();
		m_FragmentSize = m_FragmentData.size();
		m_GeometrySize = m_GeometryData.size();

		m_VertexCRC = CRC::Calculate(m_VertexData.c_str(), m_VertexData.size(), CRC::CRC_32());
		m_FragmentCRC = CRC::Calculate(m_FragmentData.c_str(), m_FragmentData.size(), CRC::CRC_32());
		m_GeometryCRC = CRC::Calculate(m_GeometryData.c_str(), m_GeometryData.size(), CRC::CRC_32());
	}

	void Shader::Destroy()
	{
		_BVHTextureFlag = false;
		Location_map.clear();
		glDeleteProgram(m_Program);
		glUseProgram(0);
	}

	void Shader::ValidateProgram()
	{
		GLchar GLInfoLog[512] = {'\0'};
		GLint successful = false;

		glValidateProgram(m_Program);

		glGetProgramiv(m_Program, GL_VALIDATE_STATUS, &successful);

		if (!successful)
		{
			glGetProgramInfoLog(m_Program, 512, NULL, GLInfoLog);
			std::cout << "\n\nVALIDATION STATUS OF SHADER\nVertex Shader : "
				<< m_VertexPath << "\nFragment Shader : " << m_FragmentPath;

			if (m_GeometryData.size() > 0)
			{
				std::cout << "\nGeometry Shader : " << m_GeometryPath << "\n";
			}

			std::cout << "\n";

			std::cout << GLInfoLog;
		}

		return;
	}

	bool Shader::Recompile()
	{
		uint32_t PrevVHash = m_VertexCRC;
		uint32_t PrevFHash = m_FragmentCRC;
		uint32_t PrevGHash = m_GeometryCRC;

		uint32_t PrevVSize = m_VertexSize;
		uint32_t PrevFSize = m_FragmentSize;
		uint32_t PrevGSize = m_GeometrySize;

		CreateShaderProgramFromFile(m_VertexPath, m_FragmentPath, m_GeometryPath);

		if (PrevVHash != m_VertexCRC || PrevFHash != m_FragmentCRC ||
			PrevGHash != m_GeometryCRC || PrevVSize != m_VertexSize ||
			PrevFSize != m_FragmentSize || PrevGSize != m_GeometrySize) {
			
			_BVHTextureFlag = false;

			Location_map.clear();
			glDeleteProgram(m_Program);
			glUseProgram(0);

			CompileShaders();
			return true;
		}

		return false;
	}

	void Shader::ForceRecompile()
	{
		_BVHTextureFlag = false;

		CreateShaderProgramFromFile(m_VertexPath, m_FragmentPath, m_GeometryPath);
		
		Location_map.clear();
		glDeleteProgram(m_Program);
		glUseProgram(0);

		CompileShaders();
	}

	void Shader::SetFloat(const std::string& name, GLfloat value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		glUniform1f(GetUniformLocation(name), value);
	}

	void Shader::SetInteger(const std::string& name, GLint value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		glUniform1i(GetUniformLocation(name), value);
	}

	void Shader::SetBool(const std::string& name, bool value, GLboolean useShader)
	{
		GLint val = value ? GL_TRUE : GL_FALSE;

		if (useShader)
		{
			this->Use();
		}

		glUniform1i(GetUniformLocation(name), val);
	}

	void Shader::SetIntegerArray(const std::string& name, const GLint* value, GLsizei count, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		glUniform1iv(GetUniformLocation(name), count, value);
	}

	void Shader::SetTextureArray(const std::string& name, const GLuint first, const GLuint count, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		for (int i = 0; i < count; i++)
		{
			std::string uniform_name = name + "[" + std::to_string(i) + "]";
			glUniform1i(GetUniformLocation(uniform_name), i + first);
		}

		return;
	}

	void Shader::BindUBOToBindingPoint(const std::string& name, int idx)
	{
		GLuint uboloc = glGetUniformBlockIndex(m_Program, name.c_str());
		glUniformBlockBinding(m_Program, uboloc, idx);
		return;
	}

	GLuint Shader::FetchUniformLocation(const std::string& name)
	{
		return GetUniformLocation(name);
	}

	void Shader::SetVector2f(const std::string& name, GLfloat x, GLfloat y, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform2f(Loc, x, y);
	}

	void Shader::SetVector2f(const std::string& name, const glm::vec2& value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform2f(Loc, value.x, value.y);
	}

	void Shader::SetVector3f(const std::string& name, GLfloat x, GLfloat y, GLfloat z, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform3f(Loc, x, y, z);
	}

	void Shader::SetVector3f(const std::string& name, const glm::vec3& value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform3f(Loc, value.x, value.y, value.z);
	}

	void Shader::SetVector4f(const std::string& name, GLfloat x, GLfloat y, GLfloat z, GLfloat w, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform4f(Loc, x, y, z, w);
	}

	void Shader::SetVector4f(const std::string& name, const glm::vec4& value, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniform4f(Loc, value.x, value.y, value.z, value.w);
	}

	void Shader::SetMatrix4(const std::string& name, const glm::mat4& matrix, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		} 

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniformMatrix4fv(Loc, 1, GL_FALSE, glm::value_ptr(matrix));
	}

	void Shader::SetMatrix3(const std::string& name, const glm::mat3& matrix, GLboolean useShader)
	{
		if (useShader)
		{
			this->Use();
		}

		GLint Loc = GetUniformLocation(name);

		if (Loc < 0) {
			return;
		}

		glUniformMatrix3fv(Loc, 1, GL_FALSE, glm::value_ptr(matrix));
	}

	GLint Shader::GetUniformLocation(const std::string& uniform_name)
	{
		if (Location_map.find(uniform_name) == Location_map.end())
		{
			GLint loc = glGetUniformLocation(this->m_Program, uniform_name.c_str());

			if (loc == -1)
			{
				std::stringstream s;
				//std::cout << "\nERROR! : UNIFORM NOT FOUND!    |    UNIFORM : " << uniform_name << "  \n\n";
				s << "\nERROR! : UNIFORM NOT FOUND!    |    UNIFORM : " << uniform_name << "  \n\n";

				Candela::Logger::LogToFile(s.str());
			}

			Location_map[uniform_name] = loc;
		}

		return Location_map[uniform_name];
	}
}