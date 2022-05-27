#include "Pipeline.h"

#include "FpsCamera.h"
#include "GLClasses/Shader.h"
#include "Object.h"
#include "Entity.h"
#include "ModelFileLoader.h"
#include "ModelRenderer.h"
#include "GLClasses/Fps.h"
#include "GLClasses/Framebuffer.h"
#include "GLClasses/ComputeShader.h"
#include "ShaderManager.h"
#include "GLClasses/DepthBuffer.h"
#include "ShadowRenderer.h"
#include "GLClasses/CubeTextureMap.h"

#include "ProbeMap.h"

#include <string>

#include "ShadowMapHandler.h"

#include "BVH/BVHConstructor.h"
#include "BVH/Intersector.h"


//Lumen::RayIntersector<Lumen::BVH::StacklessTraversalNode> Intersector;
Lumen::RayIntersector<Lumen::BVH::StacklessTraversalNode> Intersector;

Lumen::FPSCamera Camera(90.0f, 800.0f / 600.0f, 0.05f, 750.0f);

static bool vsync = false;
static float SunTick = 50.0f;
static glm::vec3 SunDirection = glm::vec3(0.1f, -1.0f, 0.1f);

GLClasses::ComputeShader DiffuseShader;

class RayTracerApp : public Lumen::Application
{
public:

	RayTracerApp()
	{
		m_Width = 800;
		m_Height = 600;
	}

	void OnUserCreate(double ts) override
	{
	
	}

	void OnUserUpdate(double ts) override
	{
		glfwSwapInterval((int)vsync);

		GLFWwindow* window = GetWindow();
		float camera_speed = 0.25f * ((glfwGetKey(window, GLFW_KEY_TAB) == GLFW_PRESS ? 3.0f : 1.0f));

		if (GetCursorLocked()) {
			if (glfwGetKey(window, GLFW_KEY_W) == GLFW_PRESS)
				Camera.ChangePosition(Camera.GetFront() * camera_speed);

			if (glfwGetKey(window, GLFW_KEY_S) == GLFW_PRESS)
				Camera.ChangePosition(-(Camera.GetFront() * camera_speed));

			if (glfwGetKey(window, GLFW_KEY_A) == GLFW_PRESS)
				Camera.ChangePosition(-(Camera.GetRight() * camera_speed));

			if (glfwGetKey(window, GLFW_KEY_D) == GLFW_PRESS)
				Camera.ChangePosition(Camera.GetRight() * camera_speed);

			if (glfwGetKey(window, GLFW_KEY_SPACE) == GLFW_PRESS)
				Camera.ChangePosition(Camera.GetUp() * camera_speed);

			if (glfwGetKey(window, GLFW_KEY_LEFT_SHIFT) == GLFW_PRESS)
				Camera.ChangePosition(-(Camera.GetUp() * camera_speed));

		}
	}

	void OnImguiRender(double ts) override
	{
		ImGui::Text("Position : %f,  %f,  %f", Camera.GetPosition().x, Camera.GetPosition().y, Camera.GetPosition().z);
		ImGui::Text("Front : %f,  %f,  %f", Camera.GetFront().x, Camera.GetFront().y, Camera.GetFront().z);
		ImGui::SliderFloat("Sun Time ", &SunTick, 0.1f, 256.0f);
		ImGui::SliderFloat3("Sun Dir : ", &SunDirection[0], -1.0f, 1.0f);
		
		if (ImGui::Button("BENCH")) {
			Camera.SetPosition(glm::vec3(10.0f, 2.0f, 0.125f));
			Camera.SetFront(glm::normalize(glm::vec3(-0.99f, -0.03f, 0.05f)));
		}
	}

	void OnEvent(Lumen::Event e) override
	{
		if (e.type == Lumen::EventTypes::MouseMove && GetCursorLocked())
		{
			Camera.UpdateOnMouseMovement(e.mx, e.my);
		}

		if (e.type == Lumen::EventTypes::WindowResize)
		{
			Camera.SetAspect((float)e.wx / (float)e.wy);
		}

		if (e.type == Lumen::EventTypes::KeyPress && e.key == GLFW_KEY_ESCAPE) {
			exit(0);
		}

		if (e.type == Lumen::EventTypes::KeyPress && e.key == GLFW_KEY_F1)
		{
			this->SetCursorLocked(!this->GetCursorLocked());
		}

		if (e.type == Lumen::EventTypes::KeyPress && e.key == GLFW_KEY_F2 && this->GetCurrentFrame() > 5)
		{
			Lumen::ShaderManager::RecompileShaders();
			Intersector.Recompile();
			DiffuseShader.Recompile();
		}

		if (e.type == Lumen::EventTypes::KeyPress && e.key == GLFW_KEY_V && this->GetCurrentFrame() > 5)
		{
			vsync = !vsync;
		}

	}


};

void UnbindEverything() {
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glUseProgram(0);
}

void RenderEntityList(const std::vector<Lumen::Entity*> EntityList, GLClasses::Shader& shader) {
	for (auto& e : EntityList) {
		Lumen::RenderEntity(*e, shader);
	}
}


GLClasses::Framebuffer GBuffer(16, 16, { {GL_RGB, GL_RGB, GL_UNSIGNED_BYTE, true, true}, {GL_RGB16F, GL_RGB, GL_FLOAT, true, true}, {GL_RGB, GL_RGB, GL_UNSIGNED_BYTE, false, false} }, false, true);
GLClasses::Framebuffer LightingPass(16, 16, {GL_RGB16F, GL_RGB, GL_FLOAT, true, true}, false, true);

void Lumen::StartPipeline()
{
	const glm::mat4 ZOrientMatrix = glm::mat4(glm::vec4(1.0f, 0.0f, 0.0f, 0.0f), glm::vec4(0.0f, 0.0f, 1.0f, 0.0f), glm::vec4(0.0f, 1.0f, 0.0f, 0.0f), glm::vec4(1.0f));
	const glm::mat4 ZOrientMatrixNegative = glm::mat4(glm::vec4(1.0f, 0.0f, 0.0f, 0.0f), glm::vec4(0.0f, 0.0f, 1.0f, 0.0f), glm::vec4(0.0f, -1.0f, 0.0f, 0.0f), glm::vec4(1.0f));

	using namespace BVH;

	RayTracerApp app;
	app.Initialize();
	app.SetCursorLocked(true);

	// Scene setup 
	Object Sponza;
	//Object Mitsuba;
	//Object Dragon;

	FileLoader::LoadModelFile(&Sponza, "Models/sponza-2/sponza.obj");
	//FileLoader::LoadModelFile(&Mitsuba, "Models/knob/mitsuba.obj");
	//FileLoader::LoadModelFile(&Sponza, "Models/sponza-pbr/Sponza.gltf");
	//FileLoader::LoadModelFile(&Sponza, "Models/csgo/scene.gltf");
	//FileLoader::LoadModelFile(&Sponza, "Models/dragon_2/dragon.obj");
	//FileLoader::LoadModelFile(&Dragon, "Models/dragon/dragon.obj");


	Intersector.Initialize();

	Intersector.AddObject(Sponza);
	//Intersector.AddObject(Mitsuba);
	//Intersector.AddObject(Dragon);
	
	Intersector.BufferData();

	Intersector.GenerateMeshTextureReferences();


	Entity SponzaEntity(&Sponza);

	//SponzaEntity.m_Model = glm::scale(glm::mat4(1.0f), glm::vec3(0.01f));
	//SponzaEntity.m_Model = ZOrientMatrixNegative;

	//Entity MitsubaEntity(&Mitsuba);
	//Entity DragonEntity(&Dragon);

	std::vector<Entity*> EntityRenderList = { &SponzaEntity };

	GLClasses::VertexBuffer ScreenQuadVBO;
	GLClasses::VertexArray ScreenQuadVAO;
	GLClasses::Texture BlueNoise;
	GLClasses::CubeTextureMap Skymap;

	Skymap.CreateCubeTextureMap(
		{
		"Res/Skymap/right.bmp",
		"Res/Skymap/left.bmp",
		"Res/Skymap/top.bmp",
		"Res/Skymap/bottom.bmp",
		"Res/Skymap/front.bmp",
		"Res/Skymap/back.bmp"
		}, true
	);

	BlueNoise.CreateTexture("Res/blue_noise.png", false, false);

	// Setup screensized quad for rendering
	{
		unsigned long long CurrentFrame = 0;
		float QuadVertices_NDC[] =
		{
			-1.0f,  1.0f,  0.0f, 1.0f, -1.0f, -1.0f,  0.0f, 0.0f,
			 1.0f, -1.0f,  1.0f, 0.0f, -1.0f,  1.0f,  0.0f, 1.0f,
			 1.0f, -1.0f,  1.0f, 0.0f,  1.0f,  1.0f,  1.0f, 1.0f
		};

		ScreenQuadVAO.Bind();
		ScreenQuadVBO.Bind();
		ScreenQuadVBO.BufferData(sizeof(QuadVertices_NDC), QuadVertices_NDC, GL_STATIC_DRAW);
		ScreenQuadVBO.VertexAttribPointer(0, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), 0);
		ScreenQuadVBO.VertexAttribPointer(1, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));
		ScreenQuadVAO.Unbind();
	}


	// Create Shaders
	ShaderManager::CreateShaders();
	GLClasses::Shader& GBufferShader = ShaderManager::GetShader("GBUFFER");
	GLClasses::Shader& LightingShader = ShaderManager::GetShader("LIGHTING_PASS");
	GLClasses::Shader& FinalShader = ShaderManager::GetShader("FINAL");
	GLClasses::Shader& ProbeForwardShader = ShaderManager::GetShader("PROBE_FORWARD");

	DiffuseShader.CreateComputeShader("Core/Shaders/DiffuseTrace.glsl");
	DiffuseShader.Compile();

	GLClasses::Framebuffer RayTraceOutput(app.GetWidth(), app.GetHeight(), { GL_RGBA16F, GL_RGBA, GL_FLOAT }, true);
	RayTraceOutput.CreateFramebuffer();

	ShadowHandler::GenerateShadowMaps();

	while (!glfwWindowShouldClose(app.GetWindow()))
	{
		GBuffer.SetSize(app.GetWidth(), app.GetHeight());
		LightingPass.SetSize(app.GetWidth(), app.GetHeight());

		RayTraceOutput.SetSize(app.GetWidth(), app.GetHeight());

		// App update 
		app.OnUpdate();

		// Render shadow maps
		ShadowHandler::UpdateShadowMaps(app.GetCurrentFrame(), Camera.GetPosition(), SunDirection, EntityRenderList);
		ShadowHandler::CalculateClipPlanes(Camera.GetProjectionMatrix());

		// Render GBuffer
		glDisable(GL_CULL_FACE);
		glEnable(GL_DEPTH_TEST);

		GBuffer.Bind();
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		GBufferShader.Use();
		GBufferShader.SetMatrix4("u_ViewProjection", Camera.GetViewProjection());
		GBufferShader.SetInteger("u_AlbedoMap", 0);
		GBufferShader.SetInteger("u_NormalMap", 1);
		GBufferShader.SetInteger("u_RoughnessMap", 2);
		GBufferShader.SetInteger("u_MetalnessMap", 3);
		GBufferShader.SetInteger("u_MetalnessRoughnessMap", 5);

		RenderEntityList(EntityRenderList, GBufferShader);
		UnbindEverything();

		// Post processing passes here : 
		glDisable(GL_CULL_FACE);
		glDisable(GL_DEPTH_TEST);

		// Raytrace
		Intersector.PushEntities(EntityRenderList);
		Intersector.BufferEntities();


		DiffuseShader.Use();
		RayTraceOutput.Bind();

		DiffuseShader.SetVector2f("u_Dims", glm::vec2(RayTraceOutput.GetWidth(), RayTraceOutput.GetHeight()));
		DiffuseShader.SetMatrix4("u_View", Camera.GetViewMatrix());
		DiffuseShader.SetMatrix4("u_Projection", Camera.GetProjectionMatrix());
		DiffuseShader.SetMatrix4("u_InverseView", glm::inverse(Camera.GetViewMatrix()));
		DiffuseShader.SetMatrix4("u_InverseProjection", glm::inverse(Camera.GetProjectionMatrix()));

		DiffuseShader.SetInteger("u_DepthTexture", 1);
		DiffuseShader.SetInteger("u_NormalTexture", 2);
		DiffuseShader.SetInteger("u_Skymap", 3);

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(1));

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_CUBE_MAP, Skymap.GetID());

		Intersector.BindEverything(DiffuseShader);
		glBindImageTexture(0, RayTraceOutput.GetTexture(), 0, GL_TRUE, 0, GL_READ_WRITE, GL_RGBA16F);


		glDispatchCompute((int)floor(float(RayTraceOutput.GetWidth()) / 16.0f), (int)floor(float(RayTraceOutput.GetHeight())) / 16.0f, 1);


		//Intersector.IntersectPrimary(RayTraceOutput.GetTexture(), RayTraceOutput.GetWidth(), RayTraceOutput.GetHeight(), Camera);

		// Lighting pass : 

		LightingShader.Use();
		LightingPass.Bind();

		LightingShader.SetInteger("u_AlbedoTexture", 0);
		LightingShader.SetInteger("u_NormalTexture", 1);
		LightingShader.SetInteger("u_PBRTexture", 2);
		LightingShader.SetInteger("u_DepthTexture", 3);
		LightingShader.SetInteger("u_BlueNoise", 5);
		LightingShader.SetInteger("u_Skymap", 6);
		LightingShader.SetInteger("u_Trace", 7);

		LightingShader.SetMatrix4("u_Projection", Camera.GetProjectionMatrix());
		LightingShader.SetMatrix4("u_View", Camera.GetViewMatrix());
		LightingShader.SetMatrix4("u_InverseProjection", glm::inverse(Camera.GetProjectionMatrix()));
		LightingShader.SetMatrix4("u_InverseView", glm::inverse(Camera.GetViewMatrix()));
		LightingShader.SetMatrix4("u_LightVP",ShadowHandler::GetShadowViewProjectionMatrix(0));
		LightingShader.SetVector2f("u_Dims", glm::vec2(app.GetWidth(), app.GetHeight()));


		LightingShader.SetVector3f("u_LightDirection", SunDirection);
		LightingShader.SetVector3f("u_ViewerPosition", Camera.GetPosition());

		for (int i = 0; i < 5; i++) {

			const int BindingPointStart = 8;

			std::string Name = "u_ShadowMatrices[" + std::to_string(i) + "]";
			std::string NameClip = "u_ShadowClipPlanes[" + std::to_string(i) + "]";
			std::string NameTex = "u_ShadowTextures[" + std::to_string(i) + "]";

			LightingShader.SetMatrix4(Name, ShadowHandler::GetShadowViewProjectionMatrix(i));
			LightingShader.SetInteger(NameTex, i+BindingPointStart);
			LightingShader.SetFloat(NameClip, ShadowHandler::GetShadowCascadeDistance(i));

			glActiveTexture(GL_TEXTURE0 + i + BindingPointStart);
			glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetShadowmap(i));
		}

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(0));

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(1));

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(2));

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE5);
		glBindTexture(GL_TEXTURE_2D, BlueNoise.GetTextureID());

		glActiveTexture(GL_TEXTURE6);
		glBindTexture(GL_TEXTURE_CUBE_MAP, Skymap.GetID());
		
		glActiveTexture(GL_TEXTURE7);
		glBindTexture(GL_TEXTURE_2D, RayTraceOutput.GetTexture());

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		// Final
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glViewport(0, 0, app.GetWidth(), app.GetHeight());

		FinalShader.Use();
		FinalShader.SetInteger("u_MainTexture", 0);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, LightingPass.GetTexture(0));

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		// Finish : 
		glFinish();
		app.FinishFrame();
		GLClasses::DisplayFrameRate(app.GetWindow(), "Lumen ");

	}
}
