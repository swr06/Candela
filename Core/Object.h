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
#include <glad/glad.h>
#include "Mesh.h"
#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>

namespace Candela
{
	class Object; 
	
	namespace FileLoader
	{
		void ProcessAssimpMesh(aiMesh* mesh, const aiScene* scene, Object* object, const std::string& pth, const glm::vec4& col, const glm::vec3& reflectivity);
	}

	enum class TextureType
	{
		Albedo,
		Normal,
		Specular,
		Metalness,
		Roughness,
		AO // Ambient Occlusion
	};

	struct ReflectionMapProperties
	{
		uint32_t res;
		uint32_t update_rate;
	};

	/*
	Has a texture, light map, albedo and normal map
	*/
	class Object
	{
	public:
		Object();
		~Object();

		//Uploads the vertex data to the GPU
		void Buffer();

		void ClearCPUSideData();

		// Generates a mesh and returns a reference to that mesh
		Mesh& GenerateMesh();
		inline uint32_t GetID() const noexcept { return m_ObjectID; }

		const uint32_t m_ObjectID;
		std::vector<Mesh> m_Meshes;
		friend void FileLoader::ProcessAssimpMesh(aiMesh* mesh, const aiScene* scene, Object* object, const std::string& pth, const glm::vec4& col, const glm::vec3& reflectivity);
	
		glm::vec3 Min;
		glm::vec3 Max;

		std::string Path;
	};
}