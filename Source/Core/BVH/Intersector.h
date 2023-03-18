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

#include "../GLClasses/Shader.h"

#include <map>

#include <type_traits>

namespace Candela {

	namespace BVH {


		struct TextureReferences {
			glm::vec4 ModelColor;
			int Albedo;
			int Normal;
			int Pad[2];
		};

		typedef FlattenedNode StacklessTraversalNode;
		typedef FlattenedStackNode StackTraversalNode;
	}

	struct BVHEntity {
		glm::mat4 ModelMatrix; // 64
		glm::mat4 InverseMatrix; // 64
		int NodeOffset;
		int NodeCount;
		int Data[14]; 
	};

	struct _ObjectData {
		int TriangleOffset;
		int VerticesOffset;
		int NodeOffset;
		int NodeCount;
	};


	// The template passed to this class can either be Candela::BVH::StacklessTraversalNode or Candela::BVH::StackTraversalNode
	template<typename T> 
	class RayIntersector {

	public :

		RayIntersector();

		void Initialize();
		void AddObject(const Object& object);
		void PushEntity(const Entity& entity);
		void PushEntities(const std::vector<Entity*>& Entities);
		void BufferEntities();
		void IntersectPrimary(GLuint OutputBuffer, int Width, int Height, FPSCamera& Camera);
		void BindEverything(GLClasses::ComputeShader& Shader, bool ShouldBindTextures);
		void BindEverything(GLClasses::Shader& shader);
		bool Collide(const glm::vec3& Point);

		// if ClearCPUData is true, it deletes the CPU side BVH, else it keeps it
		// Useful for physics sim on the CPU.
		void BufferData(bool ClearCPUData);

		void Recompile();

		void GenerateMeshTextureReferences();


		GLuint m_BVHTriSSBO = 0;
		GLuint m_BVHNodeSSBO = 0;
		GLuint m_BVHVerticesSSBO = 0;
		GLuint m_BVHEntitiesSSBO = 0;
		GLuint m_BVHTextureReferencesSSBO = 0;

		void _BindTextures(GLClasses::ComputeShader& Shader);

		GLuint m_TextureReferences = 0;

		std::vector<T> m_BVHNodes;
		std::vector<Vertex> m_BVHVertices;
		std::vector<BVH::Triangle> m_BVHTriangles;
		std::vector<BVHEntity> m_BVHEntities;

	private:

		std::vector<BVHEntity> m_Entities;

		uint32_t m_IndexOffset;

		std::unordered_map<int, _ObjectData> m_ObjectData;
		GLClasses::ComputeShader TraceShader;

		bool m_Stackless = false;

		int m_EntityPushed = 0;

		int m_NodeCountBuffered = 0;

		std::vector<BVH::TextureReferences> m_MeshTextureReferences;
		std::map<GLuint64, int> m_TextureHandleReferenceMap;

		std::unordered_map<uint64_t, bool> m_TextureBoundFlagMap;

		GLClasses::Texture m_MiscTex;

		void _BindTextures();
	};

}


template<typename T>
Candela::RayIntersector<T>::RayIntersector()
{
	m_IndexOffset = 0;
	m_BVHTriSSBO = 0;
	m_BVHNodeSSBO = 0;
	m_BVHVerticesSSBO = 0;
	m_BVHEntitiesSSBO = 0;

	if (std::is_same<T, BVH::FlattenedStackNode>::value) {
		m_Stackless = false;
	}

	else if (std::is_same<T, BVH::FlattenedNode>::value) {
		m_Stackless = true;
	}

	else {
		throw "\nTemplate <T> Passed to RayIntersector can only be of type BVH::FlattenedStackNode or BVH::FlattenedNode>!";
	}

	return;
}

template<typename T>
void Candela::RayIntersector<T>::Initialize()
{
	m_MiscTex.CreateTexture("Res/misc.png");

	if (m_Stackless) {
		TraceShader.CreateComputeShader("Core/Shaders/Intersectors/TraverseBVHStackless.glsl");
	}
	
	else {
		TraceShader.CreateComputeShader("Core/Shaders/Intersectors/TraverseBVHStack.glsl");
	}
	
	TraceShader.Compile();
}

template<typename T>
void Candela::RayIntersector<T>::AddObject(const Object& object)
{
	using namespace Candela::BVH;

	std::vector<T> Nodes;
	std::vector<Vertex> Vertices;
	std::vector<BVH::Triangle> Triangles;

	// Write object data 
	m_ObjectData[object.GetID()].NodeOffset = m_BVHNodes.size();
	m_ObjectData[object.GetID()].TriangleOffset = m_BVHTriangles.size();
	m_ObjectData[object.GetID()].VerticesOffset = m_BVHVertices.size();

	Node* RootNode = BuildBVH(object, Nodes, Vertices, Triangles, m_BVHTriangles.size());

	m_BVHVertices.insert(m_BVHVertices.end(), Vertices.begin(), Vertices.end());
	m_BVHNodes.insert(m_BVHNodes.end(), Nodes.begin(), Nodes.end());

	m_ObjectData[object.GetID()].NodeCount = Nodes.size();

	for (int i = 0; i < Triangles.size(); i++) {
		Triangles[i].PackedData[0] += m_IndexOffset;
		Triangles[i].PackedData[1] += m_IndexOffset;
		Triangles[i].PackedData[2] += m_IndexOffset;
		m_BVHTriangles.push_back(Triangles[i]);
	}

	m_IndexOffset += Vertices.size();
}

template<typename T>
void Candela::RayIntersector<T>::PushEntity(const Entity& entity)
{
	if (m_ObjectData.find((int)entity.m_Object->m_ObjectID) == m_ObjectData.end()) {
		throw "Trying to push entity whose parent object hasn't been added to global BVH";
	}

	BVHEntity push;
	push.ModelMatrix = entity.m_Model;
	push.InverseMatrix = glm::inverse(entity.m_Model);
	push.NodeOffset = m_ObjectData[(int)entity.m_Object->m_ObjectID].NodeOffset;
	push.NodeCount = m_ObjectData[(int)entity.m_Object->m_ObjectID].NodeCount;
	push.Data[0] = glm::floatBitsToInt(entity.m_EmissiveAmount);
	push.Data[1] = glm::floatBitsToInt(1.0f - entity.m_TranslucencyAmount);

	m_Entities.push_back(push);
}

template<typename T>
void Candela::RayIntersector<T>::PushEntities(const std::vector<Entity*>& Entities)
{
	for (const auto& e : Entities) {
		PushEntity(*e);
	}
}

template<typename T>
void Candela::RayIntersector<T>::BufferEntities()
{
	glDeleteBuffers(1, &m_BVHEntitiesSSBO);

	glGenBuffers(1, &m_BVHEntitiesSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, m_BVHEntitiesSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(BVHEntity) * m_Entities.size(), m_Entities.data(), GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	m_EntityPushed = m_Entities.size();
	m_BVHEntities = m_Entities;
	m_Entities.clear();
}

template<typename T>
void Candela::RayIntersector<T>::IntersectPrimary(GLuint OutputBuffer, int Width, int Height, FPSCamera& Camera)
{
	
	TraceShader.Use();
	
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, m_BVHVerticesSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, m_BVHTriSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, m_BVHNodeSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 3, m_BVHEntitiesSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 4, m_BVHTextureReferencesSSBO);
	
	glBindImageTexture(0, OutputBuffer, 0, GL_TRUE, 0, GL_READ_ONLY, GL_RGBA16F);
	
	TraceShader.SetVector2f("u_Dims", glm::vec2(Width, Height));
	TraceShader.SetMatrix4("u_View", Camera.GetViewMatrix());
	TraceShader.SetMatrix4("u_Projection", Camera.GetProjectionMatrix());
	TraceShader.SetMatrix4("u_InverseView", glm::inverse(Camera.GetViewMatrix()));
	TraceShader.SetMatrix4("u_InverseProjection", glm::inverse(Camera.GetProjectionMatrix()));
	
	// verify
	TraceShader.SetInteger("u_EntityCount", m_EntityPushed);
	TraceShader.SetInteger("u_TotalNodes", m_NodeCountBuffered);
	
	glDispatchCompute((int)floor(float(Width) / 16.0f), (int)floor(float(Height)) / 16.0f, 1);
}

template<typename T>
void Candela::RayIntersector<T>::BindEverything(GLClasses::ComputeShader& Shader, bool ShouldBindTextures)
{
	const std::vector<FileLoader::_MeshMaterialData>& Paths = FileLoader::GetMeshTexturePaths();

	Shader.Use();

	int StartIdx = 16;

	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 0, m_BVHVerticesSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 1, m_BVHTriSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 2, m_BVHNodeSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 3, m_BVHEntitiesSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 4, m_BVHTextureReferencesSSBO);

	// verify
	Shader.SetInteger("u_EntityCount", m_EntityPushed);
	Shader.SetInteger("u_TotalNodes", m_NodeCountBuffered);

	if (ShouldBindTextures && !Shader._BVHTextureFlag) {
		_BindTextures(Shader);
		Shader._BVHTextureFlag = true;
		std::cout << "BOUND";
	}
}

template<typename T>
void Candela::RayIntersector<T>::BindEverything(GLClasses::Shader& shader)
{
	shader.Use();

	int StartIdx = 16;

	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 0, m_BVHVerticesSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 1, m_BVHTriSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 2, m_BVHNodeSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 3, m_BVHEntitiesSSBO);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, StartIdx + 4, m_BVHTextureReferencesSSBO);

	// verify
	shader.SetInteger("u_EntityCount", m_EntityPushed);
	shader.SetInteger("u_TotalNodes", m_NodeCountBuffered);

	shader.Use();

	for (int i = 0; i < 512; i++) {

		std::string Name = "Textures[" + std::to_string(i) + "]";
		glProgramUniformHandleui64ARB(shader.GetProgram(), shader.FetchUniformLocation(Name), m_MiscTex.GetTextureID());

	}
}

template<typename T>
void Candela::RayIntersector<T>::BufferData(bool ClearCPUData)
{
	glDeleteBuffers(1, &m_BVHTriSSBO);
	glDeleteBuffers(1, &m_BVHNodeSSBO);
	glDeleteBuffers(1, &m_BVHVerticesSSBO);

	glGenBuffers(1, &m_BVHTriSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, m_BVHTriSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(BVH::Triangle) * m_BVHTriangles.size(), m_BVHTriangles.data(), GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	glGenBuffers(1, &m_BVHNodeSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, m_BVHNodeSSBO);
	//glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(FlattenedNode) * BVHNodes.size(), BVHNodes.data(), GL_STATIC_DRAW);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(T) * m_BVHNodes.size(), m_BVHNodes.data(), GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	glGenBuffers(1, &m_BVHVerticesSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, m_BVHVerticesSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(Vertex) * m_BVHVertices.size(), m_BVHVertices.data(), GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	m_NodeCountBuffered = m_BVHNodes.size();

	if (ClearCPUData) {
		m_BVHNodes.clear();
		m_BVHVertices.clear();
		m_BVHTriangles.clear();
	}
}

template<typename T>
inline bool Candela::RayIntersector<T>::Collide(const glm::vec3& Point)
{
	return false;
}


template<typename T>
void Candela::RayIntersector<T>::Recompile()
{
	//TraceShader.Recompile();
}

template<typename T>
void Candela::RayIntersector<T>::GenerateMeshTextureReferences()
{

	m_TextureHandleReferenceMap.clear();

	auto& DataMap = m_TextureHandleReferenceMap;


	int LastIndex = 0;

	const std::vector<FileLoader::_MeshMaterialData>& MeshMaterials = FileLoader::GetMeshTexturePaths();

	m_MeshTextureReferences.clear();

	bool Valid[2];
	int Write[2];

	
	for (int i = 0; i < MeshMaterials.size(); i++) {

		GLuint64 a = GLClasses::GetTextureCachedDataForPath(MeshMaterials[i].Albedo, Valid[0]).handle;
		GLuint64 b = GLClasses::GetTextureCachedDataForPath(MeshMaterials[i].Normal, Valid[1]).handle;

		if (DataMap.find(a) == DataMap.end()) {
			DataMap[a] = LastIndex++;
		}

		if (DataMap.find(b) == DataMap.end()) {
			DataMap[b] = LastIndex++;
		}

		Write[0] = Valid[0] ? DataMap[a] : -1;
		Write[1] = Valid[1] ? DataMap[b] : -1;

		m_MeshTextureReferences.push_back({ glm::vec4(MeshMaterials[i].ModelColor,1.0f), Write[0], Write[1] });
	}

	glDeleteBuffers(1, &m_BVHTextureReferencesSSBO);

	glGenBuffers(1, &m_BVHTextureReferencesSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, m_BVHTextureReferencesSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(BVH::TextureReferences) * m_MeshTextureReferences.size(), m_MeshTextureReferences.data(), GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	//_BindTextures();

}

// TODO : Remove limit for textures 

template<typename T>
inline void Candela::RayIntersector<T>::_BindTextures()
{
	TraceShader.Use();
	
	// Bind, bindless textures (ironic, I know.)
	for (auto& e : m_TextureHandleReferenceMap)
	{
		std::string Name = "Textures[" + std::to_string(e.second) + "]";
		glProgramUniformHandleui64ARB(TraceShader.GetProgram(), TraceShader.FetchUniformLocation(Name), e.first);
	}
	
	glUseProgram(0);
}

template<typename T>
inline void Candela::RayIntersector<T>::_BindTextures(GLClasses::ComputeShader& Shader)
{
	Shader.Use();

	for (int i = 0; i < 512; i++) {

		std::string Name = "Textures[" + std::to_string(i) + "]";
		glProgramUniformHandleui64ARB(Shader.GetProgram(), Shader.FetchUniformLocation(Name), m_MiscTex.GetTextureID());

	}

	// Bind, bindless textures (ironic, I know.)
	for (auto& e : m_TextureHandleReferenceMap)
	{
		std::string Name = "Textures[" + std::to_string(e.second) + "]";
		glProgramUniformHandleui64ARB(Shader.GetProgram(), Shader.FetchUniformLocation(Name), e.first);
	}
}
