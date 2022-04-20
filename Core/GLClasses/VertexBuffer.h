#pragma once

#include <glad/glad.h>

#include <iostream>
#include <string>

namespace GLClasses
{
	using namespace std;

	class VertexBuffer
	{
	public:

		VertexBuffer(GLenum type = GL_ARRAY_BUFFER);
		~VertexBuffer();

		VertexBuffer(const VertexBuffer&) = delete;
		VertexBuffer operator=(VertexBuffer const&) = delete;
		VertexBuffer(VertexBuffer&& v)
		{
			buffer_id = v.buffer_id;
			type = v.type;
			v.buffer_id = 0;
		}

		void BufferData(GLsizeiptr size, void* data, GLenum usage) const;
		void BufferSubData(GLintptr offset, GLsizeiptr size, void* data) const;
		void Bind() const;
		void Unbind() const;
		void VertexAttribPointer(GLuint index, GLint size, GLenum type, GLboolean normalized,
			GLsizei stride, const GLvoid* pointer) const;

		void VertexAttribIPointer(GLuint index, GLint size, GLenum type, GLsizei stride, const GLvoid* pointer) const;

	private:

		GLuint buffer_id;
		GLenum type;
	};
}