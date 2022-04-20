#pragma once

#include <iostream>
#include <string>
#include <glad/glad.h>

namespace GLClasses
{
	class IndexBuffer
	{
	public:

		IndexBuffer();
		~IndexBuffer();

		IndexBuffer(const IndexBuffer&) = delete;
		IndexBuffer operator=(IndexBuffer const&) = delete;

		IndexBuffer(IndexBuffer&& v)
		{
			buffer_id = v.buffer_id;
			type = v.type;
			v.buffer_id = 0;
		}

		void BufferData(GLsizeiptr size, void* data, GLenum usage);
		void Bind();
		void Unbind();


	private:

		GLuint buffer_id;
		GLenum type;
	};

}