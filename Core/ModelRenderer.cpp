#include "ModelRenderer.h"

#include <glm/glm.hpp>

static uint64_t PolygonsRendered = 0;

extern int __TotalMeshesRendered;
extern int __MainViewMeshesRendered;

void Lumen::RenderEntity(Entity& entity, GLClasses::Shader& shader, Frustum& frustum, bool fcull)
{
	const glm::mat4 ZOrientMatrix = glm::mat4(glm::vec4(1.0f, 0.0f, 0.0f, 0.0f), glm::vec4(0.0f, 0.0f, 1.0f, 0.0f), glm::vec4(0.0f, 1.0f, 0.0f, 0.0f), glm::vec4(1.0f));

	Object* object = entity.m_Object;

	shader.SetMatrix4("u_ModelMatrix", entity.m_Model);
	shader.SetMatrix3("u_NormalMatrix", glm::mat3(glm::transpose(glm::inverse(entity.m_Model))));

	int DrawCalls = 0;

	int MeshesRendered = 0;

	for (auto& e : object->m_Meshes)
	{
		if (fcull) {
			bool FrustumTest = frustum.TestBox(e.Box, entity.m_Model);

			if (!FrustumTest) {
				continue;
			}
		}

		MeshesRendered++;
		__TotalMeshesRendered++;
		__MainViewMeshesRendered++;

		const Mesh* mesh = &e;

		if (mesh->m_AlbedoMap.GetID() != 0)
		{
			mesh->m_AlbedoMap.Bind(0);
		}

		if (mesh->m_NormalMap.GetID() != 0)
		{
			mesh->m_NormalMap.Bind(1);
		}

		if (mesh->m_RoughnessMap.GetID() != 0)
		{
			mesh->m_RoughnessMap.Bind(2);
		}

		if (mesh->m_MetalnessMap.GetID() != 0)
		{
			mesh->m_MetalnessMap.Bind(3);
		}

		if (mesh->m_AmbientOcclusionMap.GetID() != 0)
		{
			mesh->m_AmbientOcclusionMap.Bind(4);
		}

		shader.SetBool("u_UsesGLTFPBR", false);
		shader.SetBool("u_UsesAlbedoTexture", mesh->m_AlbedoMap.GetID() > 0);
		shader.SetBool("u_UsesRoughnessMap", mesh->m_RoughnessMap.GetID() > 0);
		shader.SetBool("u_UsesMetalnessMap", mesh->m_MetalnessMap.GetID() > 0);
		shader.SetBool("u_UsesNormalMap", mesh->m_NormalMap.GetID() > 0);
		shader.SetVector3f("u_EmissiveColor", mesh->m_EmissivityColor);
		shader.SetFloat("u_EmissivityAmount", entity.m_EmissiveAmount);
		shader.SetVector3f("u_ModelColor", mesh->m_Color);
		shader.SetFloat("u_ModelEmission", entity.m_EmissiveAmount);
		shader.SetFloat("u_EntityRoughness", entity.m_EntityRoughness);
		shader.SetFloat("u_EntityMetalness", entity.m_EntityMetalness);

		if (mesh->TexturePaths[5].size() > 0 && mesh->m_MetalnessRoughnessMap.GetID() > 0) {

			shader.SetBool("u_UsesGLTFPBR", true);
			mesh->m_MetalnessRoughnessMap.Bind(5);
		}

		const GLClasses::VertexArray& VAO = mesh->m_VertexArray;
		VAO.Bind();

		DrawCalls++;

		if (mesh->m_Indexed)
		{
			glDrawElements(GL_TRIANGLES, mesh->m_IndicesCount, GL_UNSIGNED_INT, 0);
			PolygonsRendered += mesh->m_IndicesCount / 3;
		}

		else
		{
			glDrawArrays(GL_TRIANGLES, 0, mesh->m_VertexCount);
			PolygonsRendered += mesh->m_VertexCount / 3;
		}


		VAO.Unbind();

	}

	if (std::fmod(glfwGetTime(), 0.5f) < 0.001f)
	{
		std::cout << "\nDRAW CALLS : " << DrawCalls;
	}
}

uint64_t Lumen::QueryPolygonCount()
{
	return PolygonsRendered;
}

void Lumen::ResetPolygonCount()
{
	PolygonsRendered = 0;
}
