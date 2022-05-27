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

	class Bounds {

	public :

		Bounds(const glm::vec3& x, const glm::vec3& y) {
			Min = x;
			Max = y;
		}

		glm::vec3 Min;
		glm::vec3 Max;
	};

	void GenerateShadowMatrices(const glm::vec3& Origin, const glm::vec3& SunDirection, glm::mat4& Projection, glm::mat4& View, float Distance) {

		float MaxDistance = Distance;

		Bounds Box = Bounds(
			glm::round(Origin - MaxDistance),
			glm::round(Origin + MaxDistance)
		);

		glm::vec3 StartPoints[8];
		glm::vec3 Points[8];

		StartPoints[0] = Box.Min;
		StartPoints[1] = Box.Max;
		StartPoints[2] = glm::vec3(StartPoints[0].x, StartPoints[0].y, StartPoints[1].z);
		StartPoints[3] = glm::vec3(StartPoints[0].x, StartPoints[1].y, StartPoints[0].z);
		StartPoints[4] = glm::vec3(StartPoints[1].x, StartPoints[0].y, StartPoints[0].z);
		StartPoints[5] = glm::vec3(StartPoints[0].x, StartPoints[1].y, StartPoints[1].z);
		StartPoints[6] = glm::vec3(StartPoints[1].x, StartPoints[0].y, StartPoints[1].z);
		StartPoints[7] = glm::vec3(StartPoints[1].x, StartPoints[1].y, StartPoints[0].z);
		
		glm::vec3 Center;

		// Calculate world space bounds
		{
			glm::vec3 WorldspaceMin = glm::vec3(1000000.0f);
			glm::vec3 WorldspaceMax = glm::vec3(-1000000.0f);

			for (int i = 0; i < 8; i++) {

				WorldspaceMin = glm::min(WorldspaceMin, StartPoints[i]);
				WorldspaceMax = glm::max(WorldspaceMax, StartPoints[i]);

			}

			Center = (WorldspaceMin + WorldspaceMax) / 2.0f; // Centroid 
		}

		View = glm::mat4(1.0f);
		View = glm::lookAt(Center, Center + SunDirection, glm::normalize(glm::vec3(0.0f, 1.0f, 0.0f)));

		// Points[] are now in light space 
		for (int i = 0; i < 8; i++) {
			Points[i] = glm::vec3(View * glm::vec4(StartPoints[i], 1.0f));
		}

		glm::vec3 OrthoMin = glm::vec3(1000000.0f);
		glm::vec3 OrthoMax = glm::vec3(-1000000.0f);

		for (int i = 0; i < 8; i++) {

			glm::vec3 CurrentPoint = Points[i];

			// X
			if (CurrentPoint.x > OrthoMax.x) {
				OrthoMax.x = CurrentPoint.x;
			}

			else if (CurrentPoint.x < OrthoMin.x) {
				OrthoMin.x = CurrentPoint.x;
			}

			// Y
			if (CurrentPoint.y > OrthoMax.y) {
				OrthoMax.y = CurrentPoint.y;
			}

			else if (CurrentPoint.y < OrthoMin.y) {
				OrthoMin.y = CurrentPoint.y;
			}

			// Z
			if (CurrentPoint.z > OrthoMax.z) {
				OrthoMax.z = CurrentPoint.z;
			}
			else if (CurrentPoint.z < OrthoMin.z) {
				OrthoMin.z = CurrentPoint.z;
			}
		}

		Projection = glm::ortho(OrthoMin.x, OrthoMax.x, OrthoMin.y, OrthoMax.y, OrthoMin.z, OrthoMax.z);
	}

	void RenderShadowMap(GLClasses::DepthBuffer& Shadowmap, const glm::vec3& Origin, glm::vec3 SunDirection, const std::vector<Entity*> Entities, float Distance)
	{
		SunDirection = glm::normalize(SunDirection);
		GenerateShadowMatrices(Origin, SunDirection, LightProjectionMatrix, LightViewMatrix, Distance);

		GLClasses::Shader& shader = ShaderManager::GetShader("DEPTH");

		glEnable(GL_DEPTH_TEST);
		glDisable(GL_CULL_FACE);
		
		shader.Use();
		Shadowmap.Bind();
		Shadowmap.OnUpdate();

		shader.SetMatrix4("u_ViewProjection", LightProjectionMatrix * LightViewMatrix);
		//shader.SetMatrix4("u_ViewProjection", m);

		for (auto& entity : Entities)
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

		Shadowmap.Unbind();
	}

	glm::mat4 GetLightViewProjection(const glm::vec3& sun_dir)
	{
		return LightProjectionMatrix * LightViewMatrix;
	}
}