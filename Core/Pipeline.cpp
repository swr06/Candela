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
#include "ProbeGI.h"

#include "ProbeMap.h"

#include <string>

#include "ShadowMapHandler.h"

#include "BVH/BVHConstructor.h"
#include "BVH/Intersector.h"

#include "TAAJitter.h"

#include "Utility.h"


Lumen::RayIntersector<Lumen::BVH::StacklessTraversalNode> Intersector;

Lumen::FPSCamera Camera(90.0f, 800.0f / 600.0f, 0.05f, 750.0f);

static bool vsync = false;
static float SunTick = 50.0f;
static glm::vec3 _SunDirection = glm::vec3(0.1f, -1.0f, 0.1f);

// Timings
float CurrentTime = glfwGetTime();
float Frametime = 0.0f;
float DeltaTime = 0.0f;

static glm::vec3 DragonSlider = glm::vec3(0.);

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
		float camera_speed = DeltaTime * 6.0f * ((glfwGetKey(window, GLFW_KEY_TAB) == GLFW_PRESS ? 3.0f : 1.0f));

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
		ImGui::SliderFloat3("Dragon Slider : ", &DragonSlider[0], -15.0f, 15.0f);
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

		if (e.type == Lumen::EventTypes::KeyPress && e.key == GLFW_KEY_F3 && this->GetCurrentFrame() > 5)
		{
			Lumen::ShaderManager::ForceRecompileShaders();
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

void UnbindEverything() {
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glUseProgram(0);
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
	shader.SetVector3f("u_LightDirection", uniforms.SunDirection);
	shader.SetFloat("u_zNear", Camera.GetNearPlane());
	shader.SetFloat("u_zFar", Camera.GetFarPlane());
}

// Deferred
GLClasses::Framebuffer GBuffers[2] = { GLClasses::Framebuffer(16, 16, {{GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}, {GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}}, false, true),GLClasses::Framebuffer(16, 16, {{GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}, {GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}}, false, true) };
GLClasses::Framebuffer LightingPass(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true);

// Post 
GLClasses::Framebuffer Tonemapped(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true);
GLClasses::Framebuffer VolumetricsCheckerboardBuffers[2]{ GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true), GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true) };

// For temporal 
GLClasses::Framebuffer MotionVectors(16, 16, { GL_RG16F, GL_RG, GL_FLOAT, true, true }, false, true);

// Raw output 
GLClasses::Framebuffer DiffuseCheckerboardBuffers[2]{ GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true), GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true) };
GLClasses::Framebuffer SpecularCheckerboardBuffers[2]{ GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true), GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true) };

// Upscaling 
GLClasses::Framebuffer CheckerboardUpscaled(16, 16, { { GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true },{ GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true }, { GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true } }, false, true);
GLClasses::Framebuffer TemporalBuffersIndirect[2]{ GLClasses::Framebuffer(16, 16, { {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_RG16F, GL_RED, GL_FLOAT, true, true}, {GL_RG16F, GL_RG, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true} }, false, true), GLClasses::Framebuffer(16, 16, { {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_RG16F, GL_RED, GL_FLOAT, true, true}, {GL_RG16F, GL_RG, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true} }, false, true) };

// Denoiser 
GLClasses::Framebuffer SpatialVariance(16, 16, { { GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true }, { GL_R16F, GL_RED, GL_FLOAT, true, true } }, false, true);
GLClasses::Framebuffer SpatialBuffers[2]{ GLClasses::Framebuffer(16, 16, {{GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_R16F, GL_RED, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}}, false, true),GLClasses::Framebuffer(16, 16, {{GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_R16F, GL_RED, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}}, false, true) };

// Antialiasing 
GLClasses::Framebuffer TAABuffers[2] = { GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, false), GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, false) };

// Entry point 
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
	//FileLoader::LoadModelFile(&MainModel, "Models/gitest/multibounce_gi_test_scene.gltf");
	//FileLoader::LoadModelFile(&MainModel, "Models/sponza-2/sponza.obj");
	FileLoader::LoadModelFile(&Dragon, "Models/dragon/dragon.obj");
	//FileLoader::LoadModelFile(&MainModel, "Models/csgo/scene.gltf");
	//FileLoader::LoadModelFile(&MainModel, "Models/fireplace_room/fireplace_room.obj");
	//FileLoader::LoadModelFile(&MainModel, "Models/mc/scene.gltf");
	
	// Handle rt stuff 
	Intersector.Initialize();
	Intersector.AddObject(MainModel);
	Intersector.AddObject(Dragon);
	Intersector.BufferData();
	Intersector.GenerateMeshTextureReferences();

	// Create entities 
	Entity MainModelEntity(&MainModel);
	MainModelEntity.m_Model = glm::scale(glm::mat4(1.0f), glm::vec3(0.01f));
	//MainModelEntity.m_Model = glm::scale(glm::mat4(1.0f), glm::vec3(0.35f));
	//MainModelEntity.m_Model *= ZOrientMatrixNegative;

	Entity DragonEntity(&Dragon);

	std::vector<Entity*> EntityRenderList = { &MainModelEntity, &DragonEntity };

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
	GLClasses::Shader& TonemapShader = ShaderManager::GetShader("TONEMAP");
	GLClasses::Shader& TemporalFilterShader = ShaderManager::GetShader("TEMPORAL");
	GLClasses::Shader& MotionVectorShader = ShaderManager::GetShader("MOTION_VECTORS");
	GLClasses::Shader& SpatialVarianceShader = ShaderManager::GetShader("SVGF_VARIANCE");
	GLClasses::Shader& SpatialFilterShader = ShaderManager::GetShader("SPATIAL_FILTER");
	GLClasses::Shader& TAAShader = ShaderManager::GetShader("TAA");
	GLClasses::Shader& CASShader = ShaderManager::GetShader("CAS");
	GLClasses::Shader& VolumetricsShader = ShaderManager::GetShader("VOLUMETRICS");
	GLClasses::ComputeShader& DiffuseShader = ShaderManager::GetComputeShader("DIFFUSE_TRACE");
	GLClasses::ComputeShader& SpecularShader = ShaderManager::GetComputeShader("SPECULAR_TRACE");

	// Matrices
	glm::mat4 PreviousView;
	glm::mat4 PreviousProjection;
	glm::mat4 View;
	glm::mat4 Projection;
	glm::mat4 InverseView;
	glm::mat4 InverseProjection;

	// Generate shadow maps
	ShadowHandler::GenerateShadowMaps();

	// Initialize radiance probes
	ProbeGI::Initialize();

	// TAA
	GenerateJitterStuff();

	// Misc 
	GLClasses::Framebuffer* FinalDenoiseBufferPtr = &SpatialBuffers[0];

	while (!glfwWindowShouldClose(app.GetWindow()))
	{
		// Prepare 
		bool FrameMod2 = app.GetCurrentFrame() % 2 == 0;
		glm::vec3 SunDirection = glm::normalize(_SunDirection);
		DragonEntity.m_Model = glm::translate(glm::mat4(1.), DragonSlider);
		DragonEntity.m_Model *= glm::scale(glm::mat4(1.), glm::vec3(0.3f));

		// Prepare Intersector
		Intersector.PushEntities(EntityRenderList);
		Intersector.BufferEntities();

		// Resize FBOs
		GBuffers[0].SetSize(app.GetWidth(), app.GetHeight());
		GBuffers[1].SetSize(app.GetWidth(), app.GetHeight());
		MotionVectors.SetSize(app.GetWidth(), app.GetHeight());

		// Lighting
		LightingPass.SetSize(app.GetWidth(), app.GetHeight());
		
		// Antialiasing
		TAABuffers[0].SetSize(app.GetWidth(), app.GetHeight());
		TAABuffers[1].SetSize(app.GetWidth(), app.GetHeight());

		// Diffuse FBOs
		DiffuseCheckerboardBuffers[0].SetSize(app.GetWidth() / 4, app.GetHeight() / 2);
		DiffuseCheckerboardBuffers[1].SetSize(app.GetWidth() / 4, app.GetHeight() / 2);
		SpecularCheckerboardBuffers[0].SetSize(app.GetWidth() / 4, app.GetHeight() / 2);
		SpecularCheckerboardBuffers[1].SetSize(app.GetWidth() / 4, app.GetHeight() / 2);

		// Volumetrics
		VolumetricsCheckerboardBuffers[0].SetSize(app.GetWidth() / 4, app.GetHeight() / 2);
		VolumetricsCheckerboardBuffers[1].SetSize(app.GetWidth() / 4, app.GetHeight() / 2);

		// Temporal/Spatial resolve buffers
		CheckerboardUpscaled.SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		SpatialVariance.SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		SpatialBuffers[0].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		SpatialBuffers[1].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		TemporalBuffersIndirect[0].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		TemporalBuffersIndirect[1].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);

		// Other post buffers
		Tonemapped.SetSize(app.GetWidth(), app.GetHeight());
		
		// Set FBO references
		GLClasses::Framebuffer& GBuffer = FrameMod2 ? GBuffers[0] : GBuffers[1];
		GLClasses::Framebuffer& PrevGBuffer = FrameMod2 ? GBuffers[1] : GBuffers[0];

		GLClasses::Framebuffer& DiffuseTrace = FrameMod2 ? DiffuseCheckerboardBuffers[0] : DiffuseCheckerboardBuffers[1];
		GLClasses::Framebuffer& PreviousDiffuseTrace = FrameMod2 ? DiffuseCheckerboardBuffers[1] : DiffuseCheckerboardBuffers[0];
		
		GLClasses::Framebuffer& SpecularTrace = FrameMod2 ? SpecularCheckerboardBuffers[0] : SpecularCheckerboardBuffers[1];
		GLClasses::Framebuffer& PreviousSpecularTrace = FrameMod2 ? SpecularCheckerboardBuffers[1] : SpecularCheckerboardBuffers[0];
		
		GLClasses::Framebuffer& IndirectTemporal = FrameMod2 ? TemporalBuffersIndirect[0] : TemporalBuffersIndirect[1];
		GLClasses::Framebuffer& PreviousIndirectTemporal = FrameMod2 ? TemporalBuffersIndirect[1] : TemporalBuffersIndirect[0];

		GLClasses::Framebuffer& Volumetrics = FrameMod2 ? VolumetricsCheckerboardBuffers[0] : VolumetricsCheckerboardBuffers[1];
		GLClasses::Framebuffer& PreviousVolumetrics = FrameMod2 ? VolumetricsCheckerboardBuffers[1] : VolumetricsCheckerboardBuffers[0];

		GLClasses::Framebuffer& TAA = FrameMod2 ? TAABuffers[0] : TAABuffers[1];
		GLClasses::Framebuffer& PrevTAA = FrameMod2 ? TAABuffers[1] : TAABuffers[0];

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

		// Update probes
		ProbeGI::UpdateProbes(app.GetCurrentFrame(), Intersector, UniformBuffer, Skymap.GetID());

		// Render GBuffer
		glEnable(GL_CULL_FACE);
		glEnable(GL_DEPTH_TEST);

		glm::mat4 TAAMatrix = GetTAAJitterMatrix(app.GetCurrentFrame(), GBuffer.GetDimensions());

		GBuffer.Bind();
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		GBufferShader.Use();
		GBufferShader.SetMatrix4("u_ViewProjection", TAAMatrix * Camera.GetViewProjection());
		GBufferShader.SetInteger("u_AlbedoMap", 0);
		GBufferShader.SetInteger("u_NormalMap", 1);
		GBufferShader.SetInteger("u_RoughnessMap", 2);
		GBufferShader.SetInteger("u_MetalnessMap", 3);
		GBufferShader.SetInteger("u_MetalnessRoughnessMap", 5);
		GBufferShader.SetVector3f("u_ViewerPosition", Camera.GetPosition());

		RenderEntityList(EntityRenderList, GBufferShader);
		UnbindEverything();

		// Post processing passes here : 
		glDisable(GL_CULL_FACE);
		glDisable(GL_DEPTH_TEST);

		// Motion vectors 
		MotionVectors.Bind();
		MotionVectorShader.Use();
		MotionVectorShader.SetInteger("u_Depth", 0);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		SetCommonUniforms<GLClasses::Shader>(MotionVectorShader, UniformBuffer);

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		MotionVectors.Unbind();

		// Volumetrics 

		VolumetricsShader.Use();
		Volumetrics.Bind();

		VolumetricsShader.SetVector2f("u_Dims", glm::vec2(Volumetrics.GetWidth(), Volumetrics.GetHeight()));
		VolumetricsShader.SetInteger("u_DepthTexture", 0);
		VolumetricsShader.SetInteger("u_NormalTexture", 1);
		VolumetricsShader.SetInteger("u_Skymap", 2);

		VolumetricsShader.SetVector3f("u_ProbeBoxSize", ProbeGI::GetProbeGridSize());
		VolumetricsShader.SetVector3f("u_ProbeGridResolution", ProbeGI::GetProbeGridRes());
		VolumetricsShader.SetVector3f("u_ProbeBoxOrigin", ProbeGI::GetProbeBoxOrigin());
		VolumetricsShader.SetInteger("u_ProbeRadiance", 14);

		SetCommonUniforms<GLClasses::Shader>(VolumetricsShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_CUBE_MAP, Skymap.GetID());

		for (int i = 0; i < 5; i++) {

			const int BindingPointStart = 4;

			std::string Name = "u_ShadowMatrices[" + std::to_string(i) + "]";
			std::string NameClip = "u_ShadowClipPlanes[" + std::to_string(i) + "]";
			std::string NameTex = "u_ShadowTextures[" + std::to_string(i) + "]";

			VolumetricsShader.SetMatrix4(Name, ShadowHandler::GetShadowViewProjectionMatrix(i));
			VolumetricsShader.SetInteger(NameTex, i + BindingPointStart);
			VolumetricsShader.SetFloat(NameClip, ShadowHandler::GetShadowCascadeDistance(i));

			glActiveTexture(GL_TEXTURE0 + i + BindingPointStart);
			glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetShadowmap(i));
		}

		glActiveTexture(GL_TEXTURE14);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeColorTexture());

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		Volumetrics.Unbind();

		// Indirect diffuse raytracing

		DiffuseShader.Use();
		DiffuseTrace.Bind();

		DiffuseShader.SetVector2f("u_Dims", glm::vec2(DiffuseTrace.GetWidth(), DiffuseTrace.GetHeight()));
		DiffuseShader.SetInteger("u_DepthTexture", 0);
		DiffuseShader.SetInteger("u_NormalTexture", 1);
		DiffuseShader.SetInteger("u_Skymap", 2);

		DiffuseShader.SetVector3f("u_ProbeBoxSize", ProbeGI::GetProbeGridSize());
		DiffuseShader.SetVector3f("u_ProbeGridResolution", ProbeGI::GetProbeGridRes());
		DiffuseShader.SetVector3f("u_ProbeBoxOrigin", ProbeGI::GetProbeBoxOrigin());
		DiffuseShader.SetInteger("u_SHDataA", 14);
		DiffuseShader.SetInteger("u_SHDataB", 15);

		SetCommonUniforms<GLClasses::ComputeShader>(DiffuseShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

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

		glActiveTexture(GL_TEXTURE14);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().x);

		glActiveTexture(GL_TEXTURE15);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().y);

		Intersector.BindEverything(DiffuseShader, app.GetCurrentFrame() < 60);
		glBindImageTexture(0, DiffuseTrace.GetTexture(), 0, GL_TRUE, 0, GL_READ_WRITE, GL_RGBA16F);
		glDispatchCompute((int)floor(float(DiffuseTrace.GetWidth()) / 16.0f) + 1, (int)(floor(float(DiffuseTrace.GetHeight())) / 16.0f) + 1, 1);

		// Indirect specular raytracing 

		SpecularShader.Use();
		SpecularTrace.Bind();

		SpecularShader.SetInteger("u_Depth", 0);
		SpecularShader.SetInteger("u_HFNormals", 1);
		SpecularShader.SetInteger("u_LFNormals", 2);
		SpecularShader.SetInteger("u_PBR", 3);
		SpecularShader.SetInteger("u_Albedo", 4);
		SpecularShader.SetInteger("u_IndirectDiffuse", 5);
		SpecularShader.SetInteger("u_SkyCube", 12);
		SpecularShader.SetVector2f("u_Dimensions", glm::vec2(SpecularTrace.GetWidth(), SpecularTrace.GetHeight()));
		SpecularShader.SetVector3f("u_ProbeBoxSize", ProbeGI::GetProbeGridSize());
		SpecularShader.SetVector3f("u_ProbeGridResolution", ProbeGI::GetProbeGridRes());
		SpecularShader.SetVector3f("u_ProbeBoxOrigin", ProbeGI::GetProbeBoxOrigin());
		SpecularShader.SetInteger("u_SHDataA", 14);
		SpecularShader.SetInteger("u_SHDataB", 15);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(1));

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(2));

		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(0));

		glActiveTexture(GL_TEXTURE5);
		glBindTexture(GL_TEXTURE_2D, FinalDenoiseBufferPtr->GetTexture(0));

		for (int i = 0; i < 5; i++) {

			const int BindingPointStart = 6;

			std::string Name = "u_ShadowMatrices[" + std::to_string(i) + "]";
			std::string NameClip = "u_ShadowClipPlanes[" + std::to_string(i) + "]";
			std::string NameTex = "u_ShadowTextures[" + std::to_string(i) + "]";

			SpecularShader.SetMatrix4(Name, ShadowHandler::GetShadowViewProjectionMatrix(i));
			SpecularShader.SetInteger(NameTex, i + BindingPointStart);
			SpecularShader.SetFloat(NameClip, ShadowHandler::GetShadowCascadeDistance(i));

			glActiveTexture(GL_TEXTURE0 + i + BindingPointStart);
			glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetShadowmap(i));
		}

		// 6 - 10 used by shadow textures, start binding further textures from index 12

		glActiveTexture(GL_TEXTURE12);
		glBindTexture(GL_TEXTURE_CUBE_MAP, Skymap.GetID());

		glActiveTexture(GL_TEXTURE14);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().x);

		glActiveTexture(GL_TEXTURE15);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().y);

		SetCommonUniforms<GLClasses::ComputeShader>(SpecularShader, UniformBuffer);

		Intersector.BindEverything(SpecularShader, app.GetCurrentFrame() < 60);
		glBindImageTexture(0, SpecularTrace.GetTexture(), 0, GL_TRUE, 0, GL_READ_WRITE, GL_RGBA16F);
		glDispatchCompute((int)floor(float(SpecularTrace.GetWidth()) / 16.0f) + 1, (int)(floor(float(SpecularTrace.GetHeight())) / 16.0f) + 1, 1);


		// Spatio-temporal Checkerboard reconstruction

		CheckerboardUpscaled.Bind();
		CheckerReconstructShader.Use();

		CheckerReconstructShader.SetInteger("u_Depth", 0);
		CheckerReconstructShader.SetInteger("u_Normals", 1);
		CheckerReconstructShader.SetInteger("u_CurrentFrameTexture", 2);
		CheckerReconstructShader.SetInteger("u_PreviousFrameTexture", 3);
		CheckerReconstructShader.SetInteger("u_PreviousDepth", 4);
		CheckerReconstructShader.SetInteger("u_PreviousNormals", 5);
		CheckerReconstructShader.SetInteger("u_MotionVectors", 6);
		CheckerReconstructShader.SetInteger("u_CurrentFrameSpecular", 7);
		CheckerReconstructShader.SetInteger("u_PreviousFrameSpecular", 8);
		CheckerReconstructShader.SetInteger("u_CurrentFrameVolumetrics", 9);
		CheckerReconstructShader.SetInteger("u_PreviousFrameVolumetrics", 10);
		CheckerReconstructShader.SetVector2f("u_Dimensions", glm::vec2(CheckerboardUpscaled.GetWidth(), CheckerboardUpscaled.GetHeight()));

		SetCommonUniforms<GLClasses::Shader>(CheckerReconstructShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, DiffuseTrace.GetTexture());

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, PreviousDiffuseTrace.GetTexture());

		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, PrevGBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE5);
		glBindTexture(GL_TEXTURE_2D, PrevGBuffer.GetTexture(3));

		glActiveTexture(GL_TEXTURE6);
		glBindTexture(GL_TEXTURE_2D, MotionVectors.GetTexture());

		glActiveTexture(GL_TEXTURE7);
		glBindTexture(GL_TEXTURE_2D, SpecularTrace.GetTexture());

		glActiveTexture(GL_TEXTURE8);
		glBindTexture(GL_TEXTURE_2D, PreviousSpecularTrace.GetTexture());

		glActiveTexture(GL_TEXTURE9);
		glBindTexture(GL_TEXTURE_2D, Volumetrics.GetTexture());

		glActiveTexture(GL_TEXTURE10);
		glBindTexture(GL_TEXTURE_2D, PreviousVolumetrics.GetTexture());

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		CheckerboardUpscaled.Unbind();

		// Temporal 

		TemporalFilterShader.Use();
		IndirectTemporal.Bind();

		TemporalFilterShader.SetInteger("u_Depth", 0);
		TemporalFilterShader.SetInteger("u_Normals", 1);
		TemporalFilterShader.SetInteger("u_DiffuseCurrent", 2);
		TemporalFilterShader.SetInteger("u_DiffuseHistory", 3);
		TemporalFilterShader.SetInteger("u_PreviousDepth", 4);
		TemporalFilterShader.SetInteger("u_PreviousNormals", 5);
		TemporalFilterShader.SetInteger("u_MotionVectors", 6);
		TemporalFilterShader.SetInteger("u_Utility", 7);
		TemporalFilterShader.SetInteger("u_MomentsHistory", 8);
		TemporalFilterShader.SetInteger("u_SpecularCurrent", 9);
		TemporalFilterShader.SetInteger("u_SpecularHistory", 10);
		TemporalFilterShader.SetInteger("u_PBR", 11);

		SetCommonUniforms<GLClasses::Shader>(TemporalFilterShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, CheckerboardUpscaled.GetTexture());

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, PreviousIndirectTemporal.GetTexture());

		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, PrevGBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE5);
		glBindTexture(GL_TEXTURE_2D, PrevGBuffer.GetTexture(3));

		glActiveTexture(GL_TEXTURE6);
		glBindTexture(GL_TEXTURE_2D, MotionVectors.GetTexture());

		glActiveTexture(GL_TEXTURE7);
		glBindTexture(GL_TEXTURE_2D, PreviousIndirectTemporal.GetTexture(1));

		glActiveTexture(GL_TEXTURE8);
		glBindTexture(GL_TEXTURE_2D, PreviousIndirectTemporal.GetTexture(2));

		glActiveTexture(GL_TEXTURE9);
		glBindTexture(GL_TEXTURE_2D, CheckerboardUpscaled.GetTexture(1));

		glActiveTexture(GL_TEXTURE10);
		glBindTexture(GL_TEXTURE_2D, PreviousIndirectTemporal.GetTexture(3));

		glActiveTexture(GL_TEXTURE11);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(2));

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		IndirectTemporal.Unbind();

		// SVGF 

		{
			SpatialVariance.Bind();
			SpatialVarianceShader.Use();

			SpatialVarianceShader.SetInteger("u_Depth", 0);
			SpatialVarianceShader.SetInteger("u_Normals", 1);
			SpatialVarianceShader.SetInteger("u_Diffuse", 2);
			SpatialVarianceShader.SetInteger("u_FrameCounters", 3);
			SpatialVarianceShader.SetInteger("u_TemporalMoments", 4);

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

			glActiveTexture(GL_TEXTURE1);
			glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

			glActiveTexture(GL_TEXTURE2);
			glBindTexture(GL_TEXTURE_2D, IndirectTemporal.GetTexture());

			glActiveTexture(GL_TEXTURE3);
			glBindTexture(GL_TEXTURE_2D, IndirectTemporal.GetTexture(1));

			glActiveTexture(GL_TEXTURE4);
			glBindTexture(GL_TEXTURE_2D, IndirectTemporal.GetTexture(2));

			SetCommonUniforms<GLClasses::Shader>(SpatialVarianceShader, UniformBuffer);

			ScreenQuadVAO.Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			ScreenQuadVAO.Unbind();

			glUseProgram(0);
		}

		// Atrous passes 
		{
			// We use a small 3x3 kernel, so we use more passes
			// This is actually faster due to fewer cache hits
			const int Passes = 5; 
			const int StepSizes[6] = { 1, 2, 4, 8, 16, 32 };

			for (int Pass = 0; Pass < Passes; Pass++) {

				auto& CurrentBuffer = SpatialBuffers[(Pass % 2 == 0) ? 0 : 1];
				auto& SpatialPrevious = SpatialBuffers[(Pass % 2 == 0) ? 1 : 0];

				FinalDenoiseBufferPtr = &CurrentBuffer;

				bool InitialPass = Pass == 0;

				CurrentBuffer.Bind();
				SpatialFilterShader.Use();

				SpatialFilterShader.SetInteger("u_Depth", 0);
				SpatialFilterShader.SetInteger("u_Normals", 1);
				SpatialFilterShader.SetInteger("u_Diffuse", 2);
				SpatialFilterShader.SetInteger("u_Variance", 3);
				SpatialFilterShader.SetInteger("u_FrameCounters", 4);
				SpatialFilterShader.SetInteger("u_Specular", 5);
				SpatialFilterShader.SetInteger("u_NormalsHF", 6);
				SpatialFilterShader.SetInteger("u_PBR", 7);
				SpatialFilterShader.SetInteger("u_Volumetrics", 8);
				SpatialFilterShader.SetInteger("u_StepSize", StepSizes[Pass]);
				SpatialFilterShader.SetInteger("u_Pass", Pass);
				SpatialFilterShader.SetBool("u_FilterVolumetrics", InitialPass);
				SpatialFilterShader.SetFloat("u_SqrtStepSize", glm::sqrt(float(StepSizes[Pass])));
				SetCommonUniforms<GLClasses::Shader>(SpatialFilterShader, UniformBuffer);

				glActiveTexture(GL_TEXTURE0);
				glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

				glActiveTexture(GL_TEXTURE1);
				glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

				glActiveTexture(GL_TEXTURE2);
				glBindTexture(GL_TEXTURE_2D, InitialPass ? SpatialVariance.GetTexture() : SpatialPrevious.GetTexture());

				glActiveTexture(GL_TEXTURE3);
				glBindTexture(GL_TEXTURE_2D, InitialPass ? SpatialVariance.GetTexture(1) : SpatialPrevious.GetTexture(1));

				glActiveTexture(GL_TEXTURE4);
				glBindTexture(GL_TEXTURE_2D, IndirectTemporal.GetTexture(1));

				glActiveTexture(GL_TEXTURE5);
				glBindTexture(GL_TEXTURE_2D, InitialPass ? IndirectTemporal.GetTexture(3) : SpatialPrevious.GetTexture(2));

				glActiveTexture(GL_TEXTURE6);
				glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(1));

				glActiveTexture(GL_TEXTURE7);
				glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(2));

				glActiveTexture(GL_TEXTURE8);
				glBindTexture(GL_TEXTURE_2D, InitialPass ? CheckerboardUpscaled.GetTexture(2) : SpatialPrevious.GetTexture(3));

				ScreenQuadVAO.Bind();
				glDrawArrays(GL_TRIANGLES, 0, 6);
				ScreenQuadVAO.Unbind();
			}
		}


		// Lighting pass : 

		LightingShader.Use();
		LightingPass.Bind();

		LightingShader.SetInteger("u_AlbedoTexture", 0);
		LightingShader.SetInteger("u_NormalTexture", 1);
		LightingShader.SetInteger("u_PBRTexture", 2);
		LightingShader.SetInteger("u_DepthTexture", 3);
		LightingShader.SetInteger("u_BlueNoise", 5);
		LightingShader.SetInteger("u_Skymap", 6);
		LightingShader.SetInteger("u_IndirectDiffuse", 7);
		LightingShader.SetInteger("u_IndirectSpecular", 8);

		LightingShader.SetMatrix4("u_LightVP",ShadowHandler::GetShadowViewProjectionMatrix(0));
		LightingShader.SetVector2f("u_Dims", glm::vec2(app.GetWidth(), app.GetHeight()));

		LightingShader.SetVector3f("u_ProbeBoxSize", ProbeGI::GetProbeGridSize());
		LightingShader.SetVector3f("u_ProbeGridResolution", ProbeGI::GetProbeGridRes());
		LightingShader.SetVector3f("u_ProbeBoxOrigin", ProbeGI::GetProbeBoxOrigin());

		LightingShader.SetInteger("u_SHDataA", 15);
		LightingShader.SetInteger("u_SHDataB", 16);
		LightingShader.SetInteger("u_Volumetrics", 17);

		SetCommonUniforms<GLClasses::Shader>(LightingShader, UniformBuffer);

		for (int i = 0; i < 5; i++) {

			const int BindingPointStart = 9;

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
		glBindTexture(GL_TEXTURE_2D, FinalDenoiseBufferPtr->GetTexture(0));

		glActiveTexture(GL_TEXTURE8);
		glBindTexture(GL_TEXTURE_2D, FinalDenoiseBufferPtr->GetTexture(2));
		

		// 8 - 13 occupied by shadow textures 

		glActiveTexture(GL_TEXTURE15);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().x);

		glActiveTexture(GL_TEXTURE16);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().y);
		
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 4, ProbeGI::GetProbeDataSSBO());

		glActiveTexture(GL_TEXTURE17);
		glBindTexture(GL_TEXTURE_2D, FinalDenoiseBufferPtr->GetTexture(3));

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		// Temporal Anti Aliasing 

		TAAShader.Use();
		TAA.Bind();

		TAAShader.SetInteger("u_CurrentColorTexture", 0);
		TAAShader.SetInteger("u_PreviousColorTexture", 1);
		TAAShader.SetInteger("u_DepthTexture", 2);
		TAAShader.SetInteger("u_PreviousDepthTexture", 3);
		TAAShader.SetInteger("u_MotionVectors", 4);
		TAAShader.SetVector2f("u_CurrentJitter", GetTAAJitter(app.GetCurrentFrame()));

		SetCommonUniforms<GLClasses::Shader>(TAAShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, LightingPass.GetTexture());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, PrevTAA.GetTexture());

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, PrevGBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, MotionVectors.GetTexture());

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();


		// Tonemap

		Tonemapped.Bind();

		TonemapShader.Use();
		TonemapShader.SetInteger("u_MainTexture", 0);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, TAA.GetTexture(0));

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		glBindFramebuffer(GL_FRAMEBUFFER, 0);

		// CAS + Gamma correct 

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glViewport(0, 0, app.GetWidth(), app.GetHeight());

		CASShader.Use();

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, Tonemapped.GetTexture(0));

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		// Finish 

		glFinish();
		app.FinishFrame();

		CurrentTime = glfwGetTime();
		DeltaTime = CurrentTime - Frametime;
		Frametime = glfwGetTime();

		GLClasses::DisplayFrameRate(app.GetWindow(), "Lumen ");

	}
}
