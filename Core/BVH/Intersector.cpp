#include "Intersector.h"

#include <map>

Lumen::RayIntersector::RayIntersector()
{
	m_IndexOffset = 0;
	m_BVHTriSSBO = 0;
	m_BVHNodeSSBO = 0;
	m_BVHVerticesSSBO = 0;
	m_BVHEntitiesSSBO = 0;
}

void Lumen::RayIntersector::Initialize()
{
	TraceShader.CreateComputeShader("Core/Shaders/Intersectors/TraverseBVHStack.glsl");
	TraceShader.Compile();
}

void Lumen::RayIntersector::AddObject(const Object& object)
{
	using namespace Lumen::BVH;

	std::vector<FlattenedStackNode> Nodes;
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
		Triangles[i].Packed[0] += m_IndexOffset;
		Triangles[i].Packed[1] += m_IndexOffset;
		Triangles[i].Packed[2] += m_IndexOffset;
		m_BVHTriangles.push_back(Triangles[i]);
	}

	m_IndexOffset += Vertices.size();
}

void Lumen::RayIntersector::PushEntity(const Entity& entity)
{
	BVHEntity push;
	push.ModelMatrix = entity.m_Model;
	push.InverseMatrix = glm::inverse(entity.m_Model);
	push.NodeOffset = m_ObjectData[(int)entity.m_Object->m_ObjectID].NodeOffset;
	push.NodeCount = m_ObjectData[(int)entity.m_Object->m_ObjectID].NodeCount;

	m_Entities.push_back(push);
}

void Lumen::RayIntersector::PushEntities(const std::vector<Entity*>& Entities)
{
	for (const auto& e : Entities) {
		PushEntity(*e);
	}
}

void Lumen::RayIntersector::BufferEntities()
{
	glDeleteBuffers(1, &m_BVHEntitiesSSBO);

	glGenBuffers(1, &m_BVHEntitiesSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, m_BVHEntitiesSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(BVHEntity) * m_Entities.size(), m_Entities.data(), GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	m_EntityPushed = m_Entities.size();
	m_Entities.clear();
}

void Lumen::RayIntersector::Intersect(GLuint OutputBuffer, int Width, int Height, FPSCamera& Camera)
{
	const std::vector<FileLoader::_TexturePaths>& Paths = FileLoader::GetMeshTexturePaths();

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

	// Bind, bindless textures (ironic, I know.)
	for (auto& e : m_TextureHandleReferenceMap)
	{
		std::string Name = "Textures[" + std::to_string(e.second) + "]";
		glProgramUniformHandleui64ARB(TraceShader.GetProgram(), TraceShader.FetchUniformLocation(Name), e.first);
	}

	// verify
	TraceShader.SetInteger("u_EntityCount", m_EntityPushed);
	TraceShader.SetInteger("u_TotalNodes", m_NodeCountBuffered);

	glDispatchCompute((int)floor(float(Width) / 16.0f), (int)floor(float(Height)) / 16.0f, 1);
}

void Lumen::RayIntersector::BufferData()
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
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(BVH::FlattenedStackNode) * m_BVHNodes.size(), m_BVHNodes.data(), GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	glGenBuffers(1, &m_BVHVerticesSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, m_BVHVerticesSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(Vertex) * m_BVHVertices.size(), m_BVHVertices.data(), GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	m_NodeCountBuffered = m_BVHNodes.size();

	m_BVHNodes.clear();
	m_BVHVertices.clear();
	m_BVHTriangles.clear();
}

void Lumen::RayIntersector::Recompile()
{
	TraceShader.Recompile();
}

void Lumen::RayIntersector::GenerateMeshTextureReferences()
{

	m_TextureHandleReferenceMap.clear();

	auto& DataMap = m_TextureHandleReferenceMap;


	int LastIndex = 0;

	const std::vector<FileLoader::_TexturePaths>& Paths = FileLoader::GetMeshTexturePaths();

	m_MeshTextureReferences.clear();

	bool Valid[2];
	int Write[2];

	for (int i = 0; i < Paths.size(); i++) {
		

		GLuint64 a = GLClasses::GetTextureCachedDataForPath(Paths[i].Albedo, Valid[0]).handle;
		GLuint64 b = GLClasses::GetTextureCachedDataForPath(Paths[i].Normal, Valid[1]).handle;

		if (DataMap.find(a) == DataMap.end()) {
			DataMap[a] = LastIndex++;
		}

		if (DataMap.find(b) == DataMap.end()) {
			DataMap[b] = LastIndex++;
		}

		Write[0] = Valid[0] ? DataMap[a] : -1;
		Write[1] = Valid[1] ? DataMap[b] : -1;

		m_MeshTextureReferences.push_back({ Write[0], Write[1] });
	}


	glDeleteBuffers(1, &m_BVHTextureReferencesSSBO);

	glGenBuffers(1, &m_BVHTextureReferencesSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, m_BVHTextureReferencesSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(BVH::TextureReferences) * m_MeshTextureReferences.size(), m_MeshTextureReferences.data(), GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

}

