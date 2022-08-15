#pragma once

#include <iostream>
#include <string>
#include <vector>
#include "Application/Logger.h"
#include "Utils/Vertex.h"
#include "GLClasses/Texture.h"
#include "GLClasses/VertexBuffer.h"
#include "GLClasses/IndexBuffer.h"
#include "GLClasses/VertexArray.h"
#include "GLClasses/TextureArray.h"
#include <glad/glad.h>

#include "AABB.h"

namespace Candela
{
	class Object;

	class Mesh;

	class Mesh
	{
	public:
		Mesh(const uint32_t number);

		void Buffer();

		std::vector<Vertex> m_Vertices;
		std::vector<GLuint> m_Indices;
		std::string m_MeshName;

		glm::vec3 m_EmissivityColor;

		std::string TexturePaths[6];
		std::string RawTexturePaths[6];

		GLClasses::Texture m_AlbedoMap;
		GLClasses::Texture m_NormalMap;
		GLClasses::Texture m_MetalnessMap;
		GLClasses::Texture m_RoughnessMap;
		GLClasses::Texture m_AmbientOcclusionMap;
		GLClasses::Texture m_MetalnessRoughnessMap;

		GLClasses::VertexBuffer m_VertexBuffer;
		GLClasses::VertexArray m_VertexArray;
		GLClasses::IndexBuffer m_IndexBuffer;

		std::uint32_t m_VertexCount = 0;
		std::uint32_t m_IndicesCount = 0;
		bool m_Indexed = false;
		bool m_IsGLTF = false;

		glm::vec4 m_Color = glm::vec4(0.0f, 0.0f, 0.0f, 1.0f);
		std::string m_Name = std::string("");
		const uint32_t m_MeshNumber;
		int GlobalMeshNumber = 0;

		glm::vec3 Min = glm::vec3(10000.0f);
		glm::vec3 Max = glm::vec3(-10000.0f);

		bool Deleted = false;

		FrustumBox Box;

		friend class Object;
	};

}