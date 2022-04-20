#include "ShadowRenderer.h"

#include "ShaderManager.h"
#include <iostream>

namespace Lumen
{
	const static float SHADOW_DISTANCE_X = 48.0f;
	const static float SHADOW_DISTANCE_Y = 48.0f;
	const static float SHADOW_DISTANCE_Z = 128.0f;

	static glm::mat4 LightProjectionMatrix;
	static glm::mat4 LightViewMatrix;
	
	void InitShadowMapRenderer()
	{
	}

	void PrintVec3(std::string s, glm::vec3 x) 
	{
		std::cout << "\n" << s << "  :  " << x.x << "  " << x.y << "  " << x.z << "\n";
	}

	void RenderShadowMap(GLClasses::DepthBuffer& depthbuffer,  glm::vec3 sun_dir, std::vector<Entity*> entities, glm::mat4 m)
	{
		sun_dir = glm::normalize(sun_dir);

		glm::vec3 LightPosition = glm::vec3(-sun_dir * 32.0f);

		if (std::fmod(glfwGetTime(), 0.1f) < 0.001f) {
			PrintVec3("Light Position : ", LightPosition);
		}

		LightProjectionMatrix = glm::ortho(-SHADOW_DISTANCE_X, SHADOW_DISTANCE_X,
			-SHADOW_DISTANCE_Y, SHADOW_DISTANCE_Y,
			0.01f, SHADOW_DISTANCE_Z);
		LightViewMatrix = glm::lookAt(LightPosition, LightPosition + (sun_dir), glm::vec3(0.0f, 1.0f, 0.0f));

		GLClasses::Shader& shader = ShaderManager::GetShader("DEPTH");

		glEnable(GL_DEPTH_TEST);
		glDisable(GL_CULL_FACE);
		
		shader.Use();
		depthbuffer.Bind();
		depthbuffer.OnUpdate();

		shader.SetMatrix4("u_ViewProjection", LightProjectionMatrix * LightViewMatrix);
		//shader.SetMatrix4("u_ViewProjection", m);

		for (auto& entity : entities)
		{
			shader.SetMatrix4("u_ModelMatrix", entity->m_Model);

			int DrawCalls = 0;
			Object* object = entity->m_Object;

			for (auto& e : object->m_Meshes)
			{
				const Mesh* mesh = &e;
				const GLClasses::VertexArray& VAO = mesh->m_VertexArray;
				VAO.Bind();

				if (mesh->m_Indexed)
				{
					DrawCalls++;
					glDrawElements(GL_TRIANGLES, mesh->m_IndicesCount, GL_UNSIGNED_INT, 0);
				}

				else
				{
					DrawCalls++;
					glDrawArrays(GL_TRIANGLES, 0, mesh->m_VertexCount);
				}

				VAO.Unbind();
			}
		}

		depthbuffer.Unbind();
	}

	glm::mat4 GetLightViewProjection(const glm::vec3& sun_dir)
	{
		return LightProjectionMatrix * LightViewMatrix;
	}
}