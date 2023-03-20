#include "ShadowMapHandler.h"

static int Resolution = 1024;
const float CascadeDistances[5] = { 6.0f, 12.0f, 18.0f, 36.0f, 72.0f };

static std::vector<Candela::Shadowmap> Shadowmaps;
static glm::mat4 ProjectionMatrices[5];
static glm::mat4 ViewMatrices[5];
static float ClipPlanes[5];

static float ShadowDistanceMult = 1.0f;

// Sky shadowmaps! 
static glm::vec3 SkyShadowmapDirections[SKY_SHADOWMAP_COUNT];
static Candela::Shadowmap SkyShadowingMaps[SKY_SHADOWMAP_COUNT];
static glm::mat4 SkyProjectionMatrices[SKY_SHADOWMAP_COUNT];
static glm::mat4 SkyViewMatrices[SKY_SHADOWMAP_COUNT];

void Candela::ShadowHandler::SetDirectShadowMapRes(int r)
{
	if (r != Resolution) {

		Resolution = r;
		Shadowmaps.clear();
        Shadowmaps.resize(5);

		for (int i = 0; i < 5; i++) {
			Shadowmaps[i].Create(Resolution, Resolution);
		}

	}
}

void Candela::ShadowHandler::GenerateShadowMaps()
{
	ShadowRenderer::Initialize();
	Shadowmaps.resize(5);

	for (int i = 0; i < 5; i++) {
		Shadowmaps[i].Create(Resolution, Resolution);
	}

	for (int i = 0; i < SKY_SHADOWMAP_COUNT; i++) {

		glm::vec2 Angles = Maths::FibonacciLattice(i, SKY_SHADOWMAP_COUNT);
		glm::vec3 Direction = glm::vec3(Maths::CosineHemisphere(glm::vec3(0.0f, 1.0f, 0.0f), Angles));
		SkyShadowmapDirections[i] = -Direction;
	}

	for (int i = 0; i < SKY_SHADOWMAP_COUNT; i++) {
		SkyShadowingMaps[i].Create(384, 384);
	}
}

void Candela::ShadowHandler::UpdateDirectShadowMaps(int Frame, const glm::vec3& Origin, const glm::vec3& Direction, const std::vector<Entity*> Entities, float DistanceMultiplier, int UpdateRate)
{
	ShadowDistanceMult = DistanceMultiplier;
		
	std::array<int, 8> UpdateList;

	UpdateList = { 0, 1, 2, 0, 1, 0, 3, (rand() % 4) >= 3 ? 1 : 4 };

	if (UpdateRate == 1) {
		UpdateList = { 0, 1, 2, 0, 1, 0, 3, (rand() % 4) >= 3 ? 1 : 4 };
	}

	if (UpdateRate == 2) {
		UpdateList = { 0, 1, 2, 3, 1, 2, 3, (rand() % 4) >= 3 ? 1 : 4 };
	}

	if (UpdateRate == 3) {
		UpdateList = { 0, 1, 2, 3, 4, 1, 0, 3 };
	}

	if (UpdateRate == 4) {
		UpdateList = { 0, 1, 2, 3, 4, 0, 1, 2 };
	}

	if (UpdateRate == 5) {
		UpdateList = { 0, 1, 2, 3, 4, 0, 1, 2 };
	}

	int id = UpdateList[Frame % 8];

	ShadowRenderer::RenderShadowMap(Shadowmaps[id], Origin, Direction, Entities, CascadeDistances[id] * DistanceMultiplier, ProjectionMatrices[id], ViewMatrices[id]);
}

void Candela::ShadowHandler::UpdateSkyShadowMaps(int Frame, const glm::vec3& Origin, const std::vector<Entity*> Entities)
{
	if (Frame % 16 == 0) {
		std::cout << "\Sky map rendered";
	}

	int id = Frame % 32;
	float Distance = 64.0f;
	glm::vec3 Direction = SkyShadowmapDirections[id];
	ShadowRenderer::RenderShadowMap(SkyShadowingMaps[id], Origin, Direction, Entities, 
									Distance, SkyProjectionMatrices[id], SkyViewMatrices[id]);
}

GLuint Candela::ShadowHandler::GetDirectShadowmap(int n)
{
	if (n >= 5)
		throw "Invalid shadow map requested";

	return Shadowmaps[n].GetDepthTexture();
}

GLuint Candela::ShadowHandler::GetSkyShadowmap(int n)
{
	if (n >= SKY_SHADOWMAP_COUNT)
		throw "Invalid shadow map requested";

	return SkyShadowingMaps[n].GetDepthTexture();
}

const Candela::Shadowmap& Candela::ShadowHandler::GetSkyShadowmapRef(int n)
{
	if (n >= SKY_SHADOWMAP_COUNT)
		throw "Invalid shadow map requested";

	return SkyShadowingMaps[n];
}

glm::mat4 Candela::ShadowHandler::GetShadowViewMatrix(int n)
{
	return ViewMatrices[n];
}

glm::mat4 Candela::ShadowHandler::GetShadowProjectionMatrix(int n)
{
	return ProjectionMatrices[n];
}

glm::mat4 Candela::ShadowHandler::GetShadowViewProjectionMatrix(int n)
{
	return ProjectionMatrices[n] * ViewMatrices[n];
}

glm::mat4 Candela::ShadowHandler::GetSkyShadowViewMatrix(int n)
{
	return SkyViewMatrices[n];
}

glm::mat4 Candela::ShadowHandler::GetSkyShadowProjectionMatrix(int n)
{
	return SkyProjectionMatrices[n];
}

glm::mat4 Candela::ShadowHandler::GetSkyShadowViewProjectionMatrix(int n)
{
	return SkyProjectionMatrices[n] * SkyViewMatrices[n];
}

void Candela::ShadowHandler::CalculateClipPlanes(const glm::mat4& Projection)
{
	for (int i = 0; i < 5; i++) {

		glm::vec4 ViewSpacePosition = glm::vec4(0.0f, 0.0f, CascadeDistances[i] * ShadowDistanceMult, 1.0f);
		glm::vec4 Projected = Projection * ViewSpacePosition;

		Projected /= Projected.w;

		ClipPlanes[i] = Projected.z;

	}
}

float Candela::ShadowHandler::GetShadowCascadeDistance(int n)
{
	if (n >= 5)
		throw "Invalid shadow map requested";

	return CascadeDistances[n] * ShadowDistanceMult;
}

//float Candela::ShadowHandler::GetClipPlane(int n)
//{
//	if (n >= 5)
//		throw "Invalid shadow map requested";
//
//	return ClipPlanes[n];
//}

