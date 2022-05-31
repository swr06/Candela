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
#include "DDGI.h"

#include "ProbeMap.h"

#include <string>

#include "ShadowMapHandler.h"

#include "BVH/BVHConstructor.h"
#include "BVH/Intersector.h"

#include "Utility.h"


Lumen::RayIntersector<Lumen::BVH::StacklessTraversalNode> Intersector;

Lumen::FPSCamera Camera(90.0f, 800.0f / 600.0f, 0.05f, 750.0f);

static bool vsync = false;
static float SunTick = 50.0f;
static glm::vec3 _SunDirection = glm::vec3(0.1f, -1.0f, 0.1f);

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
		ImGui::SliderFloat3("Sun Dir : ", &_SunDirection[0], -1.0f, 1.0f);
		
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
		}

		if (e.type == Lumen::EventTypes::KeyPress && e.key == GLFW_KEY_V && this->GetCurrentFrame() > 5)
		{
			vsync = !vsync;
		}

	}


};


void RenderEntityList(const std::vector<Lumen::Entity*> EntityList, GLClasses::Shader& shader) {
	for (auto& e : EntityList) {
		Lumen::RenderEntity(*e, shader);
	}
}

template <typename T>
void SetCommonUniforms(T& shader, CommonUniforms& uniforms) {
	shader.SetFloat("u_Time", glfwGetTime());
	shader.SetInteger("u_Frame", uniforms.Frame);
	shader.SetInteger("u_CurrentFrame", uniforms.Frame);
	shader.SetMatrix4("u_ViewProjection", Camera.GetViewProjection());
	shader.SetMatrix4("u_Projection", uniforms.Projection);
	shader.SetMatrix4("u_View", uniforms.View);
	shader.SetMatrix4("u_InverseProjection", uniforms.InvProjection);
	shader.SetMatrix4("u_InverseView", uniforms.InvView);
	shader.SetMatrix4("u_PrevProjection", uniforms.PrevProj);
	shader.SetMatrix4("u_PrevView", uniforms.PrevView);
	shader.SetMatrix4("u_PrevInverseProjection", uniforms.InvPrevProj);
	shader.SetMatrix4("u_PrevInverseView", uniforms.InvPrevView);
	shader.SetMatrix4("u_InversePrevProjection", uniforms.InvPrevProj);
	shader.SetMatrix4("u_InversePrevView", uniforms.InvPrevView);
	shader.SetVector3f("u_ViewerPosition", glm::vec3(uniforms.InvView[3]));
	shader.SetVector3f("u_Incident", glm::vec3(uniforms.InvView[3]));
	shader.SetVector3f("u_SunDirection", uniforms.SunDirection);
	shader.SetFloat("u_zNear", Camera.GetNearPlane());
	shader.SetFloat("u_zFar", Camera.GetFarPlane());
}


GLClasses::Framebuffer GBuffers[2] = { GLClasses::Framebuffer(16, 16, {{GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}, {GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}}, false, true),GLClasses::Framebuffer(16, 16, {{GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}, {GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}}, false, true) };
GLClasses::Framebuffer LightingPass(16, 16, {GL_RGB16F, GL_RGB, GL_FLOAT, true, true}, false, true);

GLClasses::Framebuffer DiffuseCheckerboardBuffers[2]{ GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true), GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true) };
GLClasses::Framebuffer DiffuseUpscaled(16, 16, { GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true }, false, true);
GLClasses::Framebuffer DiffuseTemporalBuffers[2]{ GLClasses::Framebuffer(16, 16, { {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_R16F, GL_RED, GL_FLOAT, true, true} }, false, true), GLClasses::Framebuffer(16, 16, { {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_R16F, GL_RED, GL_FLOAT, true, true} }, false, true) };

void Lumen::StartPipeline()
{
	const glm::mat4 ZOrientMatrix = glm::mat4(glm::vec4(1.0f, 0.0f, 0.0f, 0.0f), glm::vec4(0.0f, 0.0f, 1.0f, 0.0f), glm::vec4(0.0f, 1.0f, 0.0f, 0.0f), glm::vec4(1.0f));
	const glm::mat4 ZOrientMatrixNegative = glm::mat4(glm::vec4(1.0f, 0.0f, 0.0f, 0.0f), glm::vec4(0.0f, 0.0f, 1.0f, 0.0f), glm::vec4(0.0f, -1.0f, 0.0f, 0.0f), glm::vec4(1.0f));

	using namespace BVH;

	RayTracerApp app;
	app.Initialize();
	app.SetCursorLocked(true);

	// Create VBO and VAO for drawing the screen-sized quad.
	GLClasses::VertexBuffer ScreenQuadVBO;
	GLClasses::VertexArray ScreenQuadVAO;
	GLClasses::CubeTextureMap Skymap;

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

	// Scene setup 
	Object MainModel;
	Object Dragon;

	//FileLoader::LoadModelFile(&MainModel, "Models/living_room/living_room.obj");
	FileLoader::LoadModelFile(&MainModel, "Models/sponza-pbr/sponza.gltf");
	//FileLoader::LoadModelFile(&MainModel, "Models/csgo/scene.gltf");
	//FileLoader::LoadModelFile(&MainModel, "Models/fireplace_room/fireplace_room.obj");
	FileLoader::LoadModelFile(&Dragon, "Models/dragon/dragon.obj");
	
	// Handle rt stuff 
	Intersector.Initialize();
	Intersector.AddObject(MainModel);
	Intersector.AddObject(Dragon);
	Intersector.BufferData();
	Intersector.GenerateMeshTextureReferences();

	// Create entities 
	Entity MainModelEntity(&MainModel);
	MainModelEntity.m_Model = glm::scale(glm::mat4(1.0f), glm::vec3(0.01f));
	//MainModelEntity.m_Model = ZOrientMatrixNegative;
	std::vector<Entity*> EntityRenderList = { &MainModelEntity };

	// Textures
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

	GLClasses::Texture BlueNoise;
	BlueNoise.CreateTexture("Res/blue_noise.png", false, false);

	// Create Shaders
	ShaderManager::CreateShaders();
	GLClasses::Shader& GBufferShader = ShaderManager::GetShader("GBUFFER");
	GLClasses::Shader& LightingShader = ShaderManager::GetShader("LIGHTING_PASS");
	GLClasses::Shader& CheckerReconstructShader = ShaderManager::GetShader("CHECKER_UPSCALE");
	GLClasses::Shader& FinalShader = ShaderManager::GetShader("FINAL");
	GLClasses::Shader& TemporalFilterShader = ShaderManager::GetShader("TEMPORAL");
	GLClasses::ComputeShader& DiffuseShader = ShaderManager::GetComputeShader("DIFFUSE_TRACE");

	// Matrices
	glm::mat4 PreviousView;
	glm::mat4 PreviousProjection;
	glm::mat4 View;
	glm::mat4 Projection;
	glm::mat4 InverseView;
	glm::mat4 InverseProjection;

	ShadowHandler::GenerateShadowMaps();

	while (!glfwWindowShouldClose(app.GetWindow()))
	{
		// Prepare 
		bool FrameMod2 = app.GetCurrentFrame() % 2 == 0;
		glm::vec3 SunDirection = glm::normalize(_SunDirection);

		// Prepare Intersector
		Intersector.PushEntities(EntityRenderList);
		Intersector.BufferEntities();

		// Resize FBOs
		GBuffers[0].SetSize(app.GetWidth(), app.GetHeight());
		GBuffers[1].SetSize(app.GetWidth(), app.GetHeight());
		LightingPass.SetSize(app.GetWidth(), app.GetHeight());

		// Diffuse FBOs
		DiffuseCheckerboardBuffers[0].SetSize(app.GetWidth() / 4, app.GetHeight() / 2);
		DiffuseCheckerboardBuffers[1].SetSize(app.GetWidth() / 4, app.GetHeight() / 2);
		DiffuseUpscaled.SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		DiffuseTemporalBuffers[0].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		DiffuseTemporalBuffers[1].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		
		// Set FBO references
		GLClasses::Framebuffer& GBuffer = FrameMod2 ? GBuffers[0] : GBuffers[1];

		GLClasses::Framebuffer& DiffuseTrace = FrameMod2 ? DiffuseCheckerboardBuffers[0] : DiffuseCheckerboardBuffers[1];
		GLClasses::Framebuffer& PreviousDiffuseTrace = FrameMod2 ? DiffuseCheckerboardBuffers[1] : DiffuseCheckerboardBuffers[0];
		GLClasses::Framebuffer& DiffuseTemporal = FrameMod2 ? DiffuseTemporalBuffers[0] : DiffuseTemporalBuffers[1];
		GLClasses::Framebuffer& PreviousDiffuseTemporal = FrameMod2 ? DiffuseTemporalBuffers[1] : DiffuseTemporalBuffers[0];

		// App update 
		PreviousProjection = Camera.GetProjectionMatrix();
		PreviousView = Camera.GetViewMatrix();

		app.OnUpdate();

		// Set matrices
		Projection = Camera.GetProjectionMatrix();
		View = Camera.GetViewMatrix();
		InverseProjection = glm::inverse(Camera.GetProjectionMatrix());
		InverseView = glm::inverse(Camera.GetViewMatrix());

		CommonUniforms UniformBuffer = { View, Projection, InverseView, InverseProjection, PreviousProjection, PreviousView, glm::inverse(PreviousProjection), glm::inverse(PreviousView), (int)app.GetCurrentFrame(), SunDirection};

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

		// Diffuse raytracing
		DiffuseShader.Use();
		DiffuseTrace.Bind();

		DiffuseShader.SetVector2f("u_Dims", glm::vec2(DiffuseTrace.GetWidth(), DiffuseTrace.GetHeight()));
		DiffuseShader.SetInteger("u_DepthTexture", 0);
		DiffuseShader.SetInteger("u_NormalTexture", 1);
		DiffuseShader.SetInteger("u_Skymap", 2);

		SetCommonUniforms<GLClasses::ComputeShader>(DiffuseShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(1));

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_CUBE_MAP, Skymap.GetID());

		for (int i = 0; i < 5; i++) {

			const int BindingPointStart = 4;

			std::string Name = "u_ShadowMatrices[" + std::to_string(i) + "]";
			std::string NameClip = "u_ShadowClipPlanes[" + std::to_string(i) + "]";
			std::string NameTex = "u_ShadowTextures[" + std::to_string(i) + "]";

			DiffuseShader.SetMatrix4(Name, ShadowHandler::GetShadowViewProjectionMatrix(i));
			DiffuseShader.SetInteger(NameTex, i + BindingPointStart);
			DiffuseShader.SetFloat(NameClip, ShadowHandler::GetShadowCascadeDistance(i));

			glActiveTexture(GL_TEXTURE0 + i + BindingPointStart);
			glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetShadowmap(i));
		}

		Intersector.BindEverything(DiffuseShader, app.GetCurrentFrame() < 60);
		glBindImageTexture(0, DiffuseTrace.GetTexture(), 0, GL_TRUE, 0, GL_READ_WRITE, GL_RGBA16F);
		glDispatchCompute((int)floor(float(DiffuseTrace.GetWidth()) / 16.0f) + 1, (int)(floor(float(DiffuseTrace.GetHeight())) / 16.0f) + 1, 1);

		// Checker reconstruction

		DiffuseUpscaled.Bind();
		CheckerReconstructShader.Use();

		CheckerReconstructShader.SetInteger("u_Depth", 0);
		CheckerReconstructShader.SetInteger("u_Normals", 1);
		CheckerReconstructShader.SetInteger("u_CurrentFrameTexture", 2);
		CheckerReconstructShader.SetInteger("u_PreviousFrameTexture", 3);
		CheckerReconstructShader.SetVector2f("u_Dimensions", glm::vec2(DiffuseUpscaled.GetWidth(), DiffuseUpscaled.GetHeight()));

		SetCommonUniforms<GLClasses::Shader>(CheckerReconstructShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, DiffuseTrace.GetTexture());

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, PreviousDiffuseTrace.GetTexture());

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		DiffuseUpscaled.Unbind();

		// Temporal 

		TemporalFilterShader.Use();
		DiffuseTemporal.Bind();

		TemporalFilterShader.SetInteger("u_Depth", 0);
		TemporalFilterShader.SetInteger("u_Normals", 1);
		TemporalFilterShader.SetInteger("u_DiffuseCurrent", 2);
		TemporalFilterShader.SetInteger("u_DiffuseHistory", 3);

		SetCommonUniforms<GLClasses::Shader>(TemporalFilterShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, DiffuseUpscaled.GetTexture());

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, PreviousDiffuseTemporal.GetTexture());

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		DiffuseTemporal.Unbind();


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
		glBindTexture(GL_TEXTURE_2D, DiffuseTemporal.GetTexture());

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
