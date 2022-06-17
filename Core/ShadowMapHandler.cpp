#include "ShadowMapHandler.h"

static const int Resolution = 1024;
const float CascadeDistances[5] = { 6.0f, 12.0f, 18.0f, 36.0f, 72.0f};

static Lumen::Shadowmap Shadowmaps[5];
static glm::mat4 ProjectionMatrices[5];
static glm::mat4 ViewMatrices[5];
static float ClipPlanes[5];

void Lumen::ShadowHandler::GenerateShadowMaps()
{
	for (int i = 0; i < 5; i++) {
		Shadowmaps[i].Create(Resolution, Resolution);
	}
}

void Lumen::ShadowHandler::UpdateShadowMaps(int Frame, const glm::vec3& Origin, const glm::vec3& Direction, const std::vector<Entity*> Entities)
{
	int UpdateList[8] = { 0, 1, 2, 0, 1, 0, 3, (rand() % 4) >= 3 ? 1 : 4 };
	int id = UpdateList[Frame % 8];

	RenderShadowMap(Shadowmaps[id], Origin, Direction, Entities, CascadeDistances[id], ProjectionMatrices[id], ViewMatrices[id]);
}

glm::mat4 Lumen::ShadowHandler::GetShadowViewMatrix(int n)
{
	return ViewMatrices[n];
}

glm::mat4 Lumen::ShadowHandler::GetShadowProjectionMatrix(int n)
{
	return ProjectionMatrices[n];
}

glm::mat4 Lumen::ShadowHandler::GetShadowViewProjectionMatrix(int n)
{
	return ProjectionMatrices[n] * ViewMatrices[n];
}

void Lumen::ShadowHandler::CalculateClipPlanes(const glm::mat4& Projection)
{
	for (int i = 0; i < 5; i++) {

		glm::vec4 ViewSpacePosition = glm::vec4(0.0f, 0.0f, CascadeDistances[i], 1.0f);
		glm::vec4 Projected = Projection * ViewSpacePosition;

		Projected /= Projected.w;

		ClipPlanes[i] = Projected.z;

	}
}

float Lumen::ShadowHandler::GetShadowCascadeDistance(int n)
{
	if (n >= 5)
		throw "Invalid shadow map requested";

	return CascadeDistances[n];
}

//float Lumen::ShadowHandler::GetClipPlane(int n)
//{
//	if (n >= 5)
//		throw "Invalid shadow map requested";
//
//	return ClipPlanes[n];
//}

GLuint Lumen::ShadowHandler::GetShadowmap(int n)
{
	if (n >= 5)
		throw "Invalid shadow map requested";

	return Shadowmaps[n].GetDepthTexture();
}