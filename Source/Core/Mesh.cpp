#include "Mesh.h"

namespace Candela
{
	Mesh::Mesh(const uint32_t number) : m_VertexBuffer(GL_ARRAY_BUFFER), m_MeshNumber(number)
	{
		m_VertexArray.Bind();
		m_VertexBuffer.Bind();
		m_IndexBuffer.Bind();

		m_VertexBuffer.VertexAttribPointer(0, 3, GL_FLOAT, 0, sizeof(Vertex), (void*)(offsetof(Vertex, position)));
		m_VertexBuffer.VertexAttribIPointer(1, 3, GL_UNSIGNED_INT, sizeof(Vertex), (void*)(offsetof(Vertex, normal_tangent_data)));
		m_VertexBuffer.VertexAttribIPointer(2, 1, GL_UNSIGNED_INT, sizeof(Vertex), (void*)(offsetof(Vertex, texcoords)));

		m_VertexArray.Unbind();

		TexturePaths[0] = "";
		TexturePaths[1] = "";
		TexturePaths[2] = "";
		TexturePaths[3] = "";
		TexturePaths[4] = "";
		TexturePaths[5] = "";
	}

	void Mesh::Buffer()
	{
		if (m_Vertices.size() > 0)
		{
			m_VertexCount = m_Vertices.size();
			m_VertexBuffer.BufferData(m_Vertices.size() * sizeof(Vertex), &m_Vertices.front(), GL_STATIC_DRAW);
		}

		if (m_Indices.size() > 0)
		{
			m_IndicesCount = m_Indices.size();
			m_IndexBuffer.BufferData(m_Indices.size() * sizeof(GLuint), &m_Indices.front(), GL_STATIC_DRAW);
			m_Indexed = true;
		}

		else
		{
			m_Indexed = false;
		}
	}
}