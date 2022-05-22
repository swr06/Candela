#pragma once

#include <iostream>
#include "BVHConstructor.h"

#include "../Entity.h"

#include <vector>
#include <array>

#include "../FpsCamera.h"

#include <unordered_map>

#include "../GLClasses/ComputeShader.h"

#include "../ModelFileLoader.h"

#include "../GLClasses/Texture.h"

#include <map>

namespace Lumen {

	namespace BVH {
		struct TextureReferences {
			int Albedo;
			int Normal;
		};
	}

	struct BVHEntity {
		glm::mat4 ModelMatrix; // 64
		glm::mat4 InverseMatrix; // 64
		int NodeOffset;
		int NodeCount;
		int Padding[14]; 
	};

	struct _ObjectData {
		int TriangleOffset;
		int VerticesOffset;
		int NodeOffset;
		int NodeCount;
	};

	class RayIntersector {

	public :

		RayIntersector();

		void Initialize();
		void AddObject(const Object& object);
		void PushEntity(const Entity& entity);
		void PushEntities(const std::vector<Entity*>& Entities);
		void BufferEntities();
		void Intersect(GLuint OutputBuffer, int Width, int Height, FPSCamera& Camera);

		void BufferData();
		void Recompile();

		void GenerateMeshTextureReferences();


		GLuint m_BVHTriSSBO = 0;
		GLuint m_BVHNodeSSBO = 0;
		GLuint m_BVHVerticesSSBO = 0;
		GLuint m_BVHEntitiesSSBO = 0;
		GLuint m_BVHTextureReferencesSSBO = 0;



	private : 

		GLuint m_TextureReferences = 0;

		std::vector<BVH::FlattenedStackNode> m_BVHNodes;
		std::vector<Vertex> m_BVHVertices;
		std::vector<BVH::Triangle> m_BVHTriangles;
		std::vector<BVHEntity> m_Entities;

		uint32_t m_IndexOffset;

		std::unordered_map<int, _ObjectData> m_ObjectData;
		GLClasses::ComputeShader TraceShader;

		bool Stackless = false;

		int m_EntityPushed = 0;

		int m_NodeCountBuffered = 0;

		std::vector<BVH::TextureReferences> m_MeshTextureReferences;
		std::map<GLuint64, int> m_TextureHandleReferenceMap;
	};


}