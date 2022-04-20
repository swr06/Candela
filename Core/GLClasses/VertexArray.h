#pragma once

#include <iostream>
#include <string>
#include <glad/glad.h>

namespace GLClasses
{
	using namespace std; 

	class VertexArray
	{
	public:

		VertexArray();
		~VertexArray();

		VertexArray(const VertexArray&) = delete;
		VertexArray operator=(VertexArray const&) = delete;
		VertexArray(VertexArray&& v)
		{
			type = v.type;
			array_id = v.array_id;
			v.array_id = 0;
		}

		void Bind() const;
		void Unbind() const;

	private:

		GLuint array_id;
		GLenum type;
	};
}
