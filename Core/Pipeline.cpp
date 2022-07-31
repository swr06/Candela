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

#include "Player.h"

#include "BloomRenderer.h"
#include "BloomFBO.h"

#include "Physics.h"

#include "PhysicsIntegrator.h"

#include "../Dependencies/imguizmo/ImGuizmo.h"

// Externs.
int __TotalMeshesRendered = 0;
int __MainViewMeshesRendered = 0;

Candela::RayIntersector<Candela::BVH::StacklessTraversalNode> Intersector;

Candela::Player Player;
Candela::FPSCamera& Camera = Player.Camera;

static bool vsync = false;
static float SunTick = 50.0f;
static glm::vec3 _SunDirection = glm::vec3(0.1f, -1.0f, 0.1f);

// Options

static bool DoFrustumCulling = false;
static bool DoFaceCulling = true;

static float ShadowDistanceMultiplier = 1.0f;

static bool DoMultiBounce = true;
static bool DoInfiniteBounceGI = true;

static bool UpdateIrradianceVolume = true;
static bool FilterIrradianceVolume = true;

static bool DoRoughSpecular = true;
static bool DoFullRTSpecular = false;

static bool DoCheckering = true;

static bool DoTAA = true;

static bool DoCAS = true;

static bool DoTemporal = true;

static bool DoSpatial = true;
static float SVGFStrictness = 0.2f;

static bool DoSpatialUpscaling = true;

static bool DoVolumetrics = true;
static float VolumetricsGlobalStrength = 1.0f;
static float VolumetricsDirectStrength = 1.0f;
static float VolumetricsIndirectStrength = 1.25f;
static int VolumetricsSteps = 24;
static bool VolumetricsTemporal = true;
static bool VolumetricsSpatial = true;

// DOF
static bool DoDOF = false;
static bool HQDOFBlur = false;
static bool PerformanceDOF = false;
static glm::vec2 DOFFocusPoint;
static float FocusDepthSmooth = 1.0f;;
static float DOFBlurRadius = 10.0f;

// Chromatic Aberration 
static float CAScale = 0.04f;

// Film Grain
static float GrainStrength = 0.0f;

// Barrel/Pincushion Distortion
static bool DoDistortion = false;
static float DistortionK = 0.0f;

// Hemispherical Shadow Mapping 
// (Experiment)
const bool DoHSM = false;

// Timings
float CurrentTime = glfwGetTime();
float Frametime = 0.0f;
float DeltaTime = 0.0f;

// 
// Edit mode 
static bool EditMode = false;
static bool ShouldDrawGrid = true;
static bool DrawProbeGridDebug = false;
static int EditOperation = 0;

static Candela::Entity* SelectedEntity = nullptr;
static ImGuizmo::MODE Mode = ImGuizmo::MODE::LOCAL;
static bool UseSnap = true;
static glm::vec3 SnapSize = glm::vec3(0.5f);

// Render list 
std::vector<Candela::Entity*> EntityRenderList;

// GBuffers
GLClasses::Framebuffer GBuffers[2] = { GLClasses::Framebuffer(16, 16, {{GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}, {GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}, {GL_R16I, GL_RED_INTEGER, GL_SHORT, false, false}}, false, true),GLClasses::Framebuffer(16, 16, {{GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}, {GL_RGBA, GL_RGBA, GL_UNSIGNED_BYTE, false, false}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false}, {GL_R16I, GL_RED_INTEGER, GL_SHORT, false, false}}, false, true) };
GLClasses::Framebuffer GlassGBuffer = GLClasses::Framebuffer(16, 16, { {GL_RGBA16F, GL_RGBA, GL_FLOAT, false, false} }, false, true);

// Draws editor grid 
void DrawGrid(const glm::mat4 CameraMatrix, const glm::mat4& ProjectionMatrix, const glm::vec3& GridBasis, float size) 
{
	glm::mat4 CurrentMatrix = glm::mat4(1.0f);
	//CurrentMatrix *= glm::translate(CurrentMatrix, glm::vec3(0.0f, -1.0f, 0.0f));
	//CurrentMatrix *= glm::rotate(CameraMatrix, glm::radians(90.0f), GridBasis);
	//CurrentMatrix = glm::translate(glm::mat4(1.0f), glm::vec3(Camera.GetPosition().x, Camera.GetPosition().y - 20.0f, Camera.GetPosition().z));
	ImGuizmo::DrawGrid(glm::value_ptr(CameraMatrix), glm::value_ptr(ProjectionMatrix), value_ptr(CurrentMatrix), size);
}

class RayTracerApp : public Candela::Application
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
		float camera_speed = DeltaTime * 23.0f * ((glfwGetKey(window, GLFW_KEY_TAB) == GLFW_PRESS ? 3.0f : 1.0f));

		Player.OnUpdate(window, DeltaTime, camera_speed, GetCurrentFrame());
	}

	void OnImguiRender(double ts) override
	{
		ImGuiIO& io = ImGui::GetIO();

		if (EditMode) {

			if (ImGui::Begin("Debug/Edit Mode")) {

				std::string OperationLabels[4] = { "Translation", "Rotation", "Scaling", "Universal (T/R/S)" };
				
				static bool space = 1;
				ImGui::Text("Editor Options");
				ImGui::Checkbox("Work in Local Space?", &space);
				ImGui::Checkbox("Draw Grid?", &ShouldDrawGrid);
				ImGui::Checkbox("Use Snap?", &UseSnap);
				if (UseSnap) {
					ImGui::SliderFloat3("Snap Size", &SnapSize[0], 0.01f, 4.0f);
				}
				ImGui::NewLine();
				ImGui::Text("Current Operation : %s", OperationLabels[EditOperation].c_str());

				Mode = space ? ImGuizmo::MODE::LOCAL : ImGuizmo::MODE::WORLD;

				ImGui::NewLine();
				ImGui::NewLine();
				ImGui::Text("Other Debug Views");
				ImGui::Checkbox("Draw Probe Grid Debug View?", &DrawProbeGridDebug);
			} ImGui::End();

			// Draw editor

			ImGuizmo::BeginFrame();

			ImGuizmo::SetOrthographic(false);
			ImGuizmo::SetRect(0, 0, GetWidth(), GetHeight());
			
			if (ShouldDrawGrid) {
				DrawGrid(Camera.GetViewMatrix(), Camera.GetProjectionMatrix(), glm::vec3(0.0f, 1.0f, 0.0f), 75.0f);
			}

			if (SelectedEntity) {

				const ImGuizmo::OPERATION Ops[4] = {ImGuizmo::OPERATION::TRANSLATE, ImGuizmo::OPERATION::ROTATE, ImGuizmo::OPERATION::SCALE, ImGuizmo::OPERATION::UNIVERSAL};

				glm::mat4 ModelMatrix = glm::mat4(1.0f);

				glm::vec3 Offset;

				{
					glm::vec3 tMin = SelectedEntity->m_Object->Min;
					glm::vec3 tMax = SelectedEntity->m_Object->Max;

					tMin = glm::vec3(ModelMatrix * glm::vec4(tMin, 1.0f));
					tMax = glm::vec3(ModelMatrix * glm::vec4(tMax, 1.0f));

					Offset = (tMin + tMax) * 0.5f;
				}

				ModelMatrix = glm::translate(SelectedEntity->m_Model, Offset);

				ImGuizmo::Manipulate(glm::value_ptr(Camera.GetViewMatrix()), glm::value_ptr(Camera.GetProjectionMatrix()),
									 Ops[glm::clamp(EditOperation, 0, 3)], Mode, glm::value_ptr(ModelMatrix), nullptr , UseSnap ? glm::value_ptr(SnapSize) : nullptr);

				SelectedEntity->m_Model = glm::translate(ModelMatrix, -Offset);

				bool Hovered = ImGuizmo::IsOver();
				bool Using = ImGuizmo::IsUsing();

				if (Hovered || Using) {
					glm::vec3 P, S, R;
					ImGuizmo::DecomposeMatrixToComponents(glm::value_ptr(SelectedEntity->m_Model), glm::value_ptr(P), glm::value_ptr(R), glm::value_ptr(S));
				
					if (SelectedEntity->m_IsPhysicsObject) {

						//SelectedEntity->m_PhysicsObject.Position = P;

					}
				}
			}
		}

		if (ImGui::Begin("Options")) {
			ImGui::Text("Position : %f,  %f,  %f", Camera.GetPosition().x, Camera.GetPosition().y, Camera.GetPosition().z);
			ImGui::Text("Front : %f,  %f,  %f", Camera.GetFront().x, Camera.GetFront().y, Camera.GetFront().z);
			ImGui::NewLine();
			ImGui::Text("Number of Meshes Rendered (For the main view) : %d", __MainViewMeshesRendered);
			ImGui::Text("Total Number of Meshes Rendered : %d", __TotalMeshesRendered);
			ImGui::NewLine();
			ImGui::NewLine();
			ImGui::SliderFloat3("Sun Direction", &_SunDirection[0], -1.0f, 1.0f);
			ImGui::NewLine();
			ImGui::Checkbox("Frustum Culling?", &DoFrustumCulling);
			ImGui::Checkbox("Face Culling?", &DoFaceCulling);
			ImGui::NewLine();
			ImGui::SliderFloat("Shadow Distance Multiplier", &ShadowDistanceMultiplier, 0.1f, 4.0f);
			ImGui::NewLine();
			ImGui::Checkbox("Checkerboard Lighting? (effectively computes lighting for half the pixels)", &DoCheckering);
			ImGui::NewLine();
			ImGui::Checkbox("Update Irradiance Volume?", &UpdateIrradianceVolume);
			ImGui::Checkbox("Temporally Filter Irradiance Volume?", &FilterIrradianceVolume);
			ImGui::NewLine();
			ImGui::Checkbox("Do Diffuse Multi Bounce?", &DoMultiBounce);

			if (DoMultiBounce)
				ImGui::Checkbox("Infinite Bounce GI?", &DoInfiniteBounceGI);

			ImGui::NewLine();
			ImGui::Checkbox("Rough Specular?", &DoRoughSpecular);
			ImGui::Checkbox("Full Worldspace RT Specular GI?", &DoFullRTSpecular);
			ImGui::NewLine();
			ImGui::Checkbox("Temporal Filtering?", &DoTemporal);
			ImGui::NewLine();
			ImGui::Checkbox("Spatial Filtering?", &DoSpatial);
			ImGui::SliderFloat("SVGF Strictness", &SVGFStrictness, 0.0f, 5.0f);
			ImGui::NewLine();
			ImGui::Checkbox("Spatial Upscaling?", &DoSpatialUpscaling);
			ImGui::NewLine();

			ImGui::Checkbox("Volumetrics?", &DoVolumetrics);

			if (DoVolumetrics) {
				ImGui::SliderFloat("Volumetrics Strength", &VolumetricsGlobalStrength, 0.1f, 6.0f);
				ImGui::SliderFloat("Volumetrics Direct Strength", &VolumetricsDirectStrength, 0.0f, 8.0f);
				ImGui::SliderFloat("Volumetrics Indirect Strength", &VolumetricsIndirectStrength, 0.0f, 8.0f);
				ImGui::SliderInt("Volumetrics Steps", &VolumetricsSteps, 4, 128);

				if (DoTemporal) {
					ImGui::Checkbox("Temporally Filter Volumetrics? (Cleaner, more temporal lag)", &VolumetricsTemporal);
				}

				if (DoSpatial) {
					ImGui::Checkbox("Spatially Filter Volumetrics?", &VolumetricsSpatial);
				}
			}

			ImGui::NewLine();
			ImGui::Checkbox("DOF?", &DoDOF);
			if (DoDOF) {
				ImGui::SliderFloat("DOF Blur Size", &DOFBlurRadius, 2.0f, 16.0f);
				ImGui::Checkbox("Performance DOF?", &PerformanceDOF);
				ImGui::Checkbox("High Quality DOF Bokeh?", &HQDOFBlur);
			}

			ImGui::NewLine();
			ImGui::SliderFloat("Chromatic Aberration Strength", &CAScale, 0.0f, 0.50f);
			ImGui::SliderFloat("Film Grain Strength", &GrainStrength, 0.0f, 1.0f);
			
			ImGui::NewLine();
			ImGui::Checkbox("Distortion? (Barrel/Pincushion)", &DoDistortion);
			
			if (DoDistortion)
				ImGui::SliderFloat("Distortion Coefficient (Pincushion if -ve and Barrel if +ve)", &DistortionK, -1.0f, 1.0f);
			
			ImGui::NewLine();

			ImGui::Checkbox("TAA?", &DoTAA);
			ImGui::Checkbox("CAS?", &DoCAS);
		} ImGui::End();

		__TotalMeshesRendered = 0;
		__MainViewMeshesRendered = 0;
	}

	void OnEvent(Candela::Event e) override
	{
		ImGuiIO& io = ImGui::GetIO();
		
		if (e.type == Candela::EventTypes::MousePress && EditMode && !ImGui::GetIO().WantCaptureMouse)
		{
			if (!this->GetCursorLocked()) {

				if (!ImGuizmo::IsUsing() && !ImGuizmo::IsOver()) {
					double mxx, myy;
					glfwGetCursorPos(this->m_Window, &mxx, &myy);
					myy = (double)this->GetHeight() - myy;

					short data = 0;
					glBindFramebuffer(GL_FRAMEBUFFER, GBuffers[0].GetFramebuffer());
					glReadBuffer(GL_COLOR_ATTACHMENT0 + 4);
					glReadPixels((int)mxx, (int)myy, 1, 1, GL_RED_INTEGER, GL_SHORT, &data);

					if (data >= 2) {
						data -= 2;
						SelectedEntity = EntityRenderList[data];
					}
				}
			}
		}

		if (e.type == Candela::EventTypes::MouseMove && GetCursorLocked())
		{
			Camera.UpdateOnMouseMovement(e.mx, e.my);
		}


		if (e.type == Candela::EventTypes::MouseScroll)
		{
			float Sign = e.msy < 0.0f ? 1.0f : -1.0f;
			Camera.SetFov(Camera.GetFov() + 2.0f * Sign);
			Camera.SetFov(glm::clamp(Camera.GetFov(), 1.0f, 89.0f));
		}

		if (e.type == Candela::EventTypes::WindowResize)
		{
			Camera.SetAspect((float)e.wx / (float)e.wy);
		}

		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_ESCAPE) {
			exit(0);
		}

		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_F1)
		{
			this->SetCursorLocked(!this->GetCursorLocked());
		}

		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_F2 && this->GetCurrentFrame() > 5)
		{
			Candela::ShaderManager::RecompileShaders();
			Intersector.Recompile();
		}

		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_F3 && this->GetCurrentFrame() > 5)
		{
			Candela::ShaderManager::ForceRecompileShaders();
			Intersector.Recompile();
		}
		
		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_F5 && this->GetCurrentFrame() > 5)
		{
			EditMode = !EditMode;
		}

		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_F6 && this->GetCurrentFrame() > 5) {
			EditOperation = 0;
		}

		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_F7 && this->GetCurrentFrame() > 5) {
			EditOperation = 1;
		}

		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_F8 && this->GetCurrentFrame() > 5) {
			EditOperation = 2;
		}

		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_F9 && this->GetCurrentFrame() > 5) {
			EditOperation = 3;
		}

		if (e.type == Candela::EventTypes::KeyPress && e.key == GLFW_KEY_V && this->GetCurrentFrame() > 5)
		{
			vsync = !vsync;
		}

		if (e.type == Candela::EventTypes::MousePress && !ImGui::GetIO().WantCaptureMouse)
		{
			if (!this->GetCursorLocked()) {
				double mxx, myy;
				glfwGetCursorPos(this->m_Window, &mxx, &myy);
				myy = (double)this->GetHeight() - myy;
				DOFFocusPoint = glm::vec2((float)mxx, (float)myy);
			}
		}
	}


};


void RenderEntityList(const std::vector<Candela::Entity*> EntityList, GLClasses::Shader& shader) {

	int En = 0;
		
	for (auto& e : EntityList) {
		Candela::RenderEntity(*e, shader, Player.CameraFrustum, DoFrustumCulling, En);
		En++;
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
GLClasses::Framebuffer LightingPass(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true);

// Post 
GLClasses::Framebuffer Composited(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true);
GLClasses::Framebuffer PFXComposited(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true);
GLClasses::Framebuffer DOF(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true);
GLClasses::Framebuffer VolumetricsCheckerboardBuffers[2]{ GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true), GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true) };

// For temporal 
GLClasses::Framebuffer MotionVectors(16, 16, { GL_RG16F, GL_RG, GL_FLOAT, true, true }, false, true);

// Raw output 
GLClasses::Framebuffer DiffuseCheckerboardBuffers[2]{ GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true), GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true) };
GLClasses::Framebuffer SpecularCheckerboardBuffers[2]{ GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true), GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, true) };

// Upscaling 
GLClasses::Framebuffer CheckerboardUpscaled(16, 16, { { GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true },{ GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true }, { GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true } }, false, true);
GLClasses::Framebuffer TemporalBuffersIndirect[2]{ GLClasses::Framebuffer(16, 16, { {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_RG16F, GL_RED, GL_FLOAT, true, true}, {GL_RG16F, GL_RG, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true},  {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}}, false, true), GLClasses::Framebuffer(16, 16, { {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_RG16F, GL_RED, GL_FLOAT, true, true}, {GL_RG16F, GL_RG, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true},  {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true} }, false, true) };

// Denoiser 
GLClasses::Framebuffer SpatialVariance(16, 16, { { GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true }, { GL_R16F, GL_RED, GL_FLOAT, true, true } }, false, true);
GLClasses::Framebuffer SpatialUpscaled(16, 16, { { GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true }, { GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true }, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true} }, false, true);
GLClasses::Framebuffer SpatialBuffers[2]{ GLClasses::Framebuffer(16, 16, {{GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_R16F, GL_RED, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}}, false, true),GLClasses::Framebuffer(16, 16, {{GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_R16F, GL_RED, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}}, false, true) };

// Antialiasing 
GLClasses::Framebuffer TAABuffers[2] = { GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, false), GLClasses::Framebuffer(16, 16, {GL_RGBA16F, GL_RGBA, GL_FLOAT, true, true}, false, false) };

// Entry point 
void Candela::StartPipeline()
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
	Object MetalObject;
	
	//FileLoader::LoadModelFile(&MainModel, "Models/living_room/living_room.obj");
	//FileLoader::LoadModelFile(&MainModel, "Models/sponza-pbr/sponza.gltf");
	//FileLoader::LoadModelFile(&MetalObject, "Models/monke/Suzanne.gltf");
	FileLoader::LoadModelFile(&MetalObject, "Models/ball/scene.gltf");
	//FileLoader::LoadModelFile(&MainModel, "Models/gitest/multibounce_gi_test_scene.gltf");
	FileLoader::LoadModelFile(&MainModel, "Models/sponza-2/sponza.obj");
	FileLoader::LoadModelFile(&Dragon, "Models/dragon/dragon.obj");
	//FileLoader::LoadModelFile(&MainModel, "Models/csgo/scene.gltf");
	//FileLoader::LoadModelFile(&MainModel, "Models/fireplace_room/fireplace_room.obj");
	//FileLoader::LoadModelFile(&MainModel, "Models/mc/scene.gltf");
	
	// Handle rt stuff 
	Intersector.Initialize();
	Intersector.AddObject(MainModel);
	Intersector.AddObject(Dragon);
	Intersector.AddObject(MetalObject);
	Intersector.BufferData(true);
	Intersector.GenerateMeshTextureReferences();

	// Create entities 
	Entity MainModelEntity(&MainModel);
	//MainModelEntity.m_Model = glm::scale(glm::mat4(1.0f), glm::vec3(0.01f));
	//MainModelEntity.m_Model = glm::scale(glm::mat4(1.0f), glm::vec3(0.35f));
	//MainModelEntity.m_Model *= ZOrientMatrixNegative;

	Entity DragonEntity(&Dragon);
	DragonEntity.m_EmissiveAmount = 15.0f;
	DragonEntity.m_Model = glm::translate(glm::mat4(1.), glm::vec3(-0.7f, 0.5f, -4.5f));
	DragonEntity.m_Model *= glm::scale(glm::mat4(1.), glm::vec3(0.14f));

	Entity GlassDragon(&Dragon);
	GlassDragon.m_EmissiveAmount = 0.0f;
	GlassDragon.m_TranslucencyAmount = 0.5f;
	GlassDragon.m_Model = glm::translate(glm::mat4(1.), glm::vec3(-4.25f, 0.5f, -0.5f));
	GlassDragon.m_Model *= glm::scale(glm::mat4(1.), glm::vec3(0.14f));

	Entity MetalObjectEntity(&MetalObject);
	glm::vec3 MetalObjectStartPosition = glm::vec3(-1.0f, 1.25f, -2.0f);
	MetalObjectEntity.m_Model = glm::translate(glm::mat4(1.0f), MetalObjectStartPosition);

	EntityRenderList = { &MainModelEntity, &DragonEntity, &MetalObjectEntity, &GlassDragon };

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
	GLClasses::Shader& TemporalFilterShader = ShaderManager::GetShader("TEMPORAL");
	GLClasses::Shader& MotionVectorShader = ShaderManager::GetShader("MOTION_VECTORS");
	GLClasses::Shader& SpatialVarianceShader = ShaderManager::GetShader("SVGF_VARIANCE");
	GLClasses::Shader& SpatialFilterShader = ShaderManager::GetShader("SPATIAL_FILTER");
	GLClasses::Shader& TAAShader = ShaderManager::GetShader("TAA");
	GLClasses::Shader& CASShader = ShaderManager::GetShader("CAS");
	GLClasses::Shader& VolumetricsShader = ShaderManager::GetShader("VOLUMETRICS");
	GLClasses::Shader& SpatialUpscaleShader = ShaderManager::GetShader("SPATIAL_UPSCALE");
	GLClasses::ComputeShader& DiffuseShader = ShaderManager::GetComputeShader("DIFFUSE_TRACE");
	GLClasses::ComputeShader& SpecularShader = ShaderManager::GetComputeShader("SPECULAR_TRACE");
	GLClasses::ComputeShader& CollisionShader = ShaderManager::GetComputeShader("COLLISIONS");

	GLClasses::Shader& CompositeShader = ShaderManager::GetShader("COMPOSITE");
	GLClasses::Shader& PostFXCombineShader = ShaderManager::GetShader("PFX_COMBINE");
	GLClasses::Shader& DOFShader = ShaderManager::GetShader("DOF");

	// Matrices
	glm::mat4 PreviousView;
	glm::mat4 PreviousProjection;
	glm::mat4 View;
	glm::mat4 Projection;
	glm::mat4 InverseView;
	glm::mat4 InverseProjection;

	// Collisions 
	GLuint CollisionQuerySSBO = 0;
	glGenBuffers(1, &CollisionQuerySSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, CollisionQuerySSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(CollisionQuery) * 16, nullptr, GL_DYNAMIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	GLuint CollisionResultSSBO = 0;
	glGenBuffers(1, &CollisionResultSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, CollisionResultSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(glm::ivec4) * 16, nullptr, GL_DYNAMIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	// DOF 
	GLuint DOFSSBO = 0;
	float DOFDATA = 0.;
	glGenBuffers(1, &DOFSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, DOFSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, sizeof(float) * 1, &DOFDATA, GL_DYNAMIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);


	// Generate shadow maps
	ShadowHandler::GenerateShadowMaps();

	// Initialize radiance probes
	ProbeGI::Initialize();

	// TAA
	GenerateJitterStuff();

	// Bloom
	const float BloomResolution = 0.25f;
	BloomFBO BloomBufferA(16, 16);
	BloomFBO BloomBufferB(16, 16);
	BloomRenderer::Initialize();

	// Misc 
	GLClasses::Framebuffer* FinalDenoiseBufferPtr = &SpatialBuffers[0];

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
		MotionVectors.SetSize(app.GetWidth(), app.GetHeight());

		// Lighting
		LightingPass.SetSize(app.GetWidth(), app.GetHeight());
		
		// Antialiasing
		TAABuffers[0].SetSize(app.GetWidth(), app.GetHeight());
		TAABuffers[1].SetSize(app.GetWidth(), app.GetHeight());

		// Diffuse FBOs
		int Denominator = DoCheckering ? 4 : 2;
		DiffuseCheckerboardBuffers[0].SetSize(app.GetWidth() / Denominator, app.GetHeight() / 2);
		DiffuseCheckerboardBuffers[1].SetSize(app.GetWidth() / Denominator, app.GetHeight() / 2);
		SpecularCheckerboardBuffers[0].SetSize(app.GetWidth() / Denominator, app.GetHeight() / 2);
		SpecularCheckerboardBuffers[1].SetSize(app.GetWidth() / Denominator, app.GetHeight() / 2);

		// Volumetrics
		VolumetricsCheckerboardBuffers[0].SetSize(app.GetWidth() / Denominator, app.GetHeight() / 2);
		VolumetricsCheckerboardBuffers[1].SetSize(app.GetWidth() / Denominator, app.GetHeight() / 2);

		// Temporal/Spatial resolve buffers
		SpatialUpscaled.SetSize(app.GetWidth(), app.GetHeight());
		CheckerboardUpscaled.SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		SpatialVariance.SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		SpatialBuffers[0].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		SpatialBuffers[1].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		TemporalBuffersIndirect[0].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);
		TemporalBuffersIndirect[1].SetSize(app.GetWidth() / 2, app.GetHeight() / 2);

		// Other post buffers
		Composited.SetSize(app.GetWidth(), app.GetHeight());
		PFXComposited.SetSize(app.GetWidth(), app.GetHeight());
		DOF.SetSize(app.GetWidth() / (PerformanceDOF ? 2 : 1), app.GetHeight() / (PerformanceDOF ? 2 : 1));

		if (app.GetCursorLocked()) {
			DOFFocusPoint = glm::vec2(app.GetWidth() / 2, app.GetHeight() / 2);
		}

		BloomBufferA.SetSize(app.GetWidth() * BloomResolution, app.GetHeight() * BloomResolution);
		BloomBufferB.SetSize(app.GetWidth() * BloomResolution, app.GetHeight() * BloomResolution);
		
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

		// Collide

		if (false) {
			CollisionQuery Query;
			Query.Min = glm::vec4(Camera.GetPosition() - 0.1f, 1.0f);
			Query.Max = glm::vec4(Camera.GetPosition() + 0.1f, 1.0f);
			glBindBuffer(GL_SHADER_STORAGE_BUFFER, CollisionQuerySSBO);
			glBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(CollisionQuery) * 1, &Query);

			CollisionShader.Use();
			CollisionShader.SetInteger("u_QueryCount", 1);
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, CollisionQuerySSBO);
			glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, CollisionResultSSBO);
			Intersector.BindEverything(CollisionShader, false);
			glDispatchCompute(1, 1, 1);

			glm::ivec4 Retrieved;
			glBindBuffer(GL_SHADER_STORAGE_BUFFER, CollisionResultSSBO);
			glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(glm::ivec4) * 1, &Retrieved);;
			glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

			if (app.GetCurrentFrame() % 16 == 0)
				std::cout << "\nPlayer Collision Test Result : " << Retrieved.x << "  " << Retrieved.y << "  " << Retrieved.z << "  " << Retrieved.w << "  ";
		}

		if (false) {
			std::cout << Physics::CollideBox(Camera.GetPosition() - 0.5f, Camera.GetPosition() + 0.5f, Intersector) << "\n";
		}

		// Physics Simulation
		Physics::Integrate(EntityRenderList, DeltaTime);

		app.OnUpdate(); 

		// Set matrices
		Projection = Camera.GetProjectionMatrix();
		View = Camera.GetViewMatrix();
		InverseProjection = glm::inverse(Camera.GetProjectionMatrix());
		InverseView = glm::inverse(Camera.GetViewMatrix());

		CommonUniforms UniformBuffer = { View, Projection, InverseView, InverseProjection, PreviousProjection, PreviousView, glm::inverse(PreviousProjection), glm::inverse(PreviousView), (int)app.GetCurrentFrame(), SunDirection};

		// Render shadow maps
		ShadowHandler::UpdateDirectShadowMaps(app.GetCurrentFrame(), Camera.GetPosition(), SunDirection, EntityRenderList, ShadowDistanceMultiplier);
		ShadowHandler::CalculateClipPlanes(Camera.GetProjectionMatrix());
		
		if (DoHSM) {
			ShadowHandler::UpdateSkyShadowMaps(app.GetCurrentFrame(), Camera.GetPosition(), EntityRenderList);
		}

		// Update probes
		if (UpdateIrradianceVolume) {
			ProbeGI::UpdateProbes(app.GetCurrentFrame(), Intersector, UniformBuffer, Skymap.GetID(), FilterIrradianceVolume);
		}

		// Render GBuffer

		if (DoFaceCulling) {
			glEnable(GL_CULL_FACE);
		}

		else {
			glDisable(GL_CULL_FACE);
		}

		glEnable(GL_DEPTH_TEST);

		glm::mat4 TAAMatrix = DoTAA ? GetTAAJitterMatrix(app.GetCurrentFrame(), GBuffer.GetDimensions()) : glm::mat4(1.0f);

		GBuffer.Bind();
		glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		GBufferShader.Use();
		GBufferShader.SetMatrix4("u_ViewProjection", TAAMatrix * Camera.GetViewProjection());
		GBufferShader.SetInteger("u_AlbedoMap", 0);
		GBufferShader.SetInteger("u_NormalMap", 1);
		GBufferShader.SetInteger("u_RoughnessMap", 2);
		GBufferShader.SetInteger("u_MetalnessMap", 3);
		GBufferShader.SetInteger("u_MetalnessRoughnessMap", 5);
		GBufferShader.SetVector3f("u_ViewerPosition", Camera.GetPosition());
		GBufferShader.SetVector2f("u_Dimensions", glm::vec2(GBuffer.GetWidth(), GBuffer.GetHeight()));

		RenderEntityList(EntityRenderList, GBufferShader);
		UnbindEverything();

		// Glass passes 

		GlassGBuffer.Bind();



		GlassGBuffer.Unbind();

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

		if (DoVolumetrics) {
			VolumetricsTemporal = VolumetricsTemporal && DoTemporal;

			VolumetricsShader.Use();
			Volumetrics.Bind();

			VolumetricsShader.SetVector2f("u_Dims", glm::vec2(Volumetrics.GetWidth(), Volumetrics.GetHeight()));
			VolumetricsShader.SetInteger("u_DepthTexture", 0);
			VolumetricsShader.SetInteger("u_NormalTexture", 1);
			VolumetricsShader.SetInteger("u_Skymap", 2);
			VolumetricsShader.SetInteger("u_Steps", VolumetricsSteps);

			VolumetricsShader.SetVector3f("u_ProbeBoxSize", PROBE_GRID_SIZE);
			VolumetricsShader.SetVector3f("u_ProbeGridResolution", PROBE_GRID_RES);
			VolumetricsShader.SetVector3f("u_ProbeBoxOrigin", ProbeGI::GetProbeBoxOrigin());
			VolumetricsShader.SetInteger("u_ProbeRadiance", 14);
			VolumetricsShader.SetFloat("u_Strength", VolumetricsGlobalStrength);
			VolumetricsShader.SetFloat("u_DStrength", VolumetricsDirectStrength);
			VolumetricsShader.SetFloat("u_IStrength", VolumetricsIndirectStrength);
			VolumetricsShader.SetBool("u_Checker", DoCheckering);

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
				glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetDirectShadowmap(i));
			}

			glActiveTexture(GL_TEXTURE14);
			glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeColorTexture());

			ScreenQuadVAO.Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			ScreenQuadVAO.Unbind();

			Volumetrics.Unbind();
		}

		// Indirect diffuse raytracing

		DiffuseShader.Use();
		DiffuseTrace.Bind();

		DiffuseShader.SetVector2f("u_Dims", glm::vec2(DiffuseTrace.GetWidth(), DiffuseTrace.GetHeight()));
		DiffuseShader.SetInteger("u_DepthTexture", 0);
		DiffuseShader.SetInteger("u_NormalTexture", 1);
		DiffuseShader.SetInteger("u_Skymap", 2);

		DiffuseShader.SetVector3f("u_ProbeBoxSize", PROBE_GRID_SIZE);
		DiffuseShader.SetVector3f("u_ProbeGridResolution", PROBE_GRID_RES);
		DiffuseShader.SetVector3f("u_ProbeBoxOrigin", ProbeGI::GetProbeBoxOrigin());
		DiffuseShader.SetInteger("u_SHDataA", 14);
		DiffuseShader.SetInteger("u_SHDataB", 15);
		DiffuseShader.SetInteger("u_Albedo", 16);
		DiffuseShader.SetBool("u_Checker", DoCheckering);
		DiffuseShader.SetBool("u_SecondBounce", DoMultiBounce);
		DiffuseShader.SetBool("u_SecondBounceRT", !DoInfiniteBounceGI);

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
			glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetDirectShadowmap(i));
		}

		glActiveTexture(GL_TEXTURE14);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().x);

		glActiveTexture(GL_TEXTURE15);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().y);

		glActiveTexture(GL_TEXTURE16);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(0));

		Intersector.BindEverything(DiffuseShader, true);
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
		SpecularShader.SetVector3f("u_ProbeBoxSize", PROBE_GRID_SIZE);
		SpecularShader.SetVector3f("u_ProbeGridResolution", PROBE_GRID_RES);
		SpecularShader.SetVector3f("u_ProbeBoxOrigin", ProbeGI::GetProbeBoxOrigin());
		SpecularShader.SetInteger("u_SHDataA", 14);
		SpecularShader.SetInteger("u_SHDataB", 15);
		SpecularShader.SetBool("u_Checker", DoCheckering);
		SpecularShader.SetBool("u_FullRT", DoFullRTSpecular);
		SpecularShader.SetBool("u_RoughSpec", DoRoughSpecular);

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
			glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetDirectShadowmap(i));
		}

		// 6 - 10 used by shadow textures, start binding further textures from index 12

		glActiveTexture(GL_TEXTURE12);
		glBindTexture(GL_TEXTURE_CUBE_MAP, Skymap.GetID());

		glActiveTexture(GL_TEXTURE14);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().x);

		glActiveTexture(GL_TEXTURE15);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().y);

		SetCommonUniforms<GLClasses::ComputeShader>(SpecularShader, UniformBuffer);

		Intersector.BindEverything(SpecularShader, true);
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
		CheckerReconstructShader.SetBool("u_Enabled", DoCheckering);
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
		TemporalFilterShader.SetInteger("u_VolumetricsCurrent", 12);
		TemporalFilterShader.SetInteger("u_VolumetricsHistory", 13);
		TemporalFilterShader.SetBool("u_DoVolumetrics", DoVolumetrics && VolumetricsTemporal);
		TemporalFilterShader.SetBool("u_Enabled", DoTemporal);
		TemporalFilterShader.SetBool("u_RoughSpec", DoRoughSpecular);

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

		glActiveTexture(GL_TEXTURE12);
		glBindTexture(GL_TEXTURE_2D, CheckerboardUpscaled.GetTexture(2));

		glActiveTexture(GL_TEXTURE13);
		glBindTexture(GL_TEXTURE_2D, PreviousIndirectTemporal.GetTexture(4));

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
			SpatialVarianceShader.SetBool("u_Enabled", DoSpatial);

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
				SpatialFilterShader.SetBool("u_FilterVolumetrics", InitialPass && DoVolumetrics && VolumetricsSpatial);
				SpatialFilterShader.SetBool("u_Enabled", DoSpatial);
				SpatialFilterShader.SetFloat("u_SqrtStepSize", glm::sqrt(float(StepSizes[Pass])));
				SpatialFilterShader.SetFloat("u_PhiLMult", 1.0f/glm::max(SVGFStrictness,0.01f));
				SpatialFilterShader.SetBool("u_RoughSpec", DoRoughSpecular);

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
				glBindTexture(GL_TEXTURE_2D, InitialPass ? IndirectTemporal.GetTexture(4) : SpatialPrevious.GetTexture(3));

				ScreenQuadVAO.Bind();
				glDrawArrays(GL_TRIANGLES, 0, 6);
				ScreenQuadVAO.Unbind();
			}
		}

		// Spatial Upscale 

		SpatialUpscaleShader.Use();
		SpatialUpscaled.Bind();

		SpatialUpscaleShader.SetInteger("u_Depth", 0);
		SpatialUpscaleShader.SetInteger("u_Normals", 1);

		SpatialUpscaleShader.SetInteger("u_Diffuse", 2);
		SpatialUpscaleShader.SetInteger("u_Specular", 3);
		SpatialUpscaleShader.SetInteger("u_Volumetrics", 4);

		SpatialUpscaleShader.SetInteger("u_PBR", 5);
		SpatialUpscaleShader.SetInteger("u_NormalsHF", 6);
		SpatialUpscaleShader.SetBool("u_Enabled", DoSpatialUpscaling);

		SetCommonUniforms<GLClasses::Shader>(SpatialUpscaleShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, FinalDenoiseBufferPtr->GetTexture(0));

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, FinalDenoiseBufferPtr->GetTexture(2));

		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, FinalDenoiseBufferPtr->GetTexture(3));

		glActiveTexture(GL_TEXTURE5);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(2));

		glActiveTexture(GL_TEXTURE6);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(1));

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		SpatialUpscaled.Unbind();

		// Light Combiner 

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

		LightingShader.SetVector3f("u_ProbeBoxSize", PROBE_GRID_SIZE);
		LightingShader.SetVector3f("u_ProbeGridResolution", PROBE_GRID_RES);
		LightingShader.SetVector3f("u_ProbeBoxOrigin", ProbeGI::GetProbeBoxOrigin());

		LightingShader.SetInteger("u_SHDataA", 15);
		LightingShader.SetInteger("u_SHDataB", 16);
		LightingShader.SetInteger("u_Volumetrics", 17);
		LightingShader.SetInteger("u_NormalLFTexture", 18);
		LightingShader.SetInteger("u_VoxelVolume", 19);
		LightingShader.SetBool("u_DoVolumetrics", DoVolumetrics);
		LightingShader.SetBool("u_DrawProbeGridDebug", DrawProbeGridDebug && EditMode);

		LightingShader.SetVector2f("u_FocusPoint", DOFFocusPoint / glm::vec2(app.GetWidth(), app.GetHeight()));

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
			glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetDirectShadowmap(i));
		}

		if (DoHSM) {
			for (int i = 0; i < SKY_SHADOWMAP_COUNT; i++) {
				std::string Name = "SkyHemisphericalShadowmaps[" + std::to_string(i) + "]";
				std::string NameM = "u_SkyShadowMatrices[" + std::to_string(i) + "]";
				glProgramUniformHandleui64ARB(LightingShader.GetProgram(), LightingShader.FetchUniformLocation(Name), ShadowHandler::GetSkyShadowmapRef(i).GetHandle());
				LightingShader.SetMatrix4(NameM, ShadowHandler::GetSkyShadowViewProjectionMatrix(i));
			}
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
		glBindTexture(GL_TEXTURE_2D, SpatialUpscaled.GetTexture(0));

		glActiveTexture(GL_TEXTURE8);
		glBindTexture(GL_TEXTURE_2D, SpatialUpscaled.GetTexture(1));
		

		// 8 - 13 occupied by shadow textures 

		glActiveTexture(GL_TEXTURE15);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().x);

		glActiveTexture(GL_TEXTURE16);
		glBindTexture(GL_TEXTURE_3D, ProbeGI::GetProbeDataTextures().y);
		

		glActiveTexture(GL_TEXTURE17);
		glBindTexture(GL_TEXTURE_2D, SpatialUpscaled.GetTexture(2));

		glActiveTexture(GL_TEXTURE18);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 4, ProbeGI::GetProbeDataSSBO());
		glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, DOFSSBO);

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		// find center depth 
		float DownloadedCenterDepth = 0.0f;

		glBindBuffer(GL_SHADER_STORAGE_BUFFER, DOFSSBO);
		glGetBufferSubData(GL_SHADER_STORAGE_BUFFER, 0, sizeof(float), &DownloadedCenterDepth);;
		glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

		FocusDepthSmooth = glm::mix(DownloadedCenterDepth, FocusDepthSmooth, 0.75f);

		//if (app.GetCurrentFrame() % 1 == 0)
		//{
		//	std::cout << "\n\nFocus Pos : " << DOFFocusPoint.x << "   " << DOFFocusPoint.y;
		//	std::cout << "\nCenter Depth (Temporal) : " << FocusDepthSmooth;
		//	std::cout << "\n\n";
		//}

		// Temporal Anti Aliasing 

		TAAShader.Use();
		TAA.Bind();

		TAAShader.SetInteger("u_CurrentColorTexture", 0);
		TAAShader.SetInteger("u_PreviousColorTexture", 1);
		TAAShader.SetInteger("u_DepthTexture", 2);
		TAAShader.SetInteger("u_PreviousDepthTexture", 3);
		TAAShader.SetInteger("u_MotionVectors", 4);
		TAAShader.SetBool("u_Enabled", DoTAA);
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

		// Bloom 

		GLuint BrightTex = 0;
		BloomRenderer::RenderBloom(TAA.GetTexture(), GBuffer.GetTexture(3), BloomBufferA, BloomBufferB, BrightTex, true);

		// Combine Post FX (excluding DOF.)

		PFXComposited.Bind();
		PostFXCombineShader.Use();

		PostFXCombineShader.SetInteger("u_MainTexture", 0);

		PostFXCombineShader.SetInteger("u_BloomMips[0]", 1);
		PostFXCombineShader.SetInteger("u_BloomMips[1]", 2);
		PostFXCombineShader.SetInteger("u_BloomMips[2]", 3);
		PostFXCombineShader.SetInteger("u_BloomMips[3]", 4);
		PostFXCombineShader.SetInteger("u_BloomMips[4]", 5);
		PostFXCombineShader.SetInteger("u_BloomBrightTexture", 6);
		PostFXCombineShader.SetInteger("u_Depth", 7);
		PostFXCombineShader.SetFloat("u_CAScale", CAScale);

		SetCommonUniforms<GLClasses::Shader>(PostFXCombineShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, TAA.GetTexture(0));

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, BloomBufferA.m_Mips[0]);

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, BloomBufferA.m_Mips[1]);

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, BloomBufferA.m_Mips[2]);

		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, BloomBufferA.m_Mips[3]);

		glActiveTexture(GL_TEXTURE5);
		glBindTexture(GL_TEXTURE_2D, BloomBufferA.m_Mips[4]);

		glActiveTexture(GL_TEXTURE6);
		glBindTexture(GL_TEXTURE_2D, BrightTex);

		glActiveTexture(GL_TEXTURE7);
		glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		PFXComposited.Unbind();

		// DOF

		if (DoDOF) {

			DOFShader.Use();
			DOF.Bind();

			DOFShader.SetInteger("u_DepthTexture", 0);
			DOFShader.SetInteger("u_Input", 1);
			DOFShader.SetBool("u_HQ", HQDOFBlur);
			DOFShader.SetBool("u_PerformanceDOF", PerformanceDOF);

			DOFShader.SetVector2f("u_FocusPoint", DOFFocusPoint / glm::vec2(app.GetWidth(), app.GetHeight()));
			DOFShader.SetFloat("u_zVNear", Camera.GetNearPlane());
			DOFShader.SetFloat("u_zVFar", Camera.GetFarPlane());
			DOFShader.SetFloat("u_FocusDepth", FocusDepthSmooth);
			DOFShader.SetFloat("u_BlurRadius", DOFBlurRadius);

			SetCommonUniforms<GLClasses::Shader>(DOFShader, UniformBuffer);

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

			glActiveTexture(GL_TEXTURE1);
			glBindTexture(GL_TEXTURE_2D, PFXComposited.GetTexture(0));

			ScreenQuadVAO.Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			ScreenQuadVAO.Unbind();

			DOF.Unbind();
		}

		// Tonemap

		Composited.Bind();

		CompositeShader.Use();
		CompositeShader.SetInteger("u_MainTexture", 0);
		CompositeShader.SetInteger("u_DOF", 1);
		CompositeShader.SetBool("u_DOFEnabled", DoDOF);
		CompositeShader.SetFloat("u_FocusDepth", FocusDepthSmooth);
		CompositeShader.SetBool("u_PerformanceDOF", PerformanceDOF);
		CompositeShader.SetFloat("u_GrainStrength", GrainStrength);

		SetCommonUniforms<GLClasses::Shader>(CompositeShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, PFXComposited.GetTexture(0));

		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, DOF.GetTexture());

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		glBindFramebuffer(GL_FRAMEBUFFER, 0);

		// CAS + Gamma correct 

		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glViewport(0, 0, app.GetWidth(), app.GetHeight());

		CASShader.Use();

		CASShader.SetBool("u_Enabled", DoCAS);
		CASShader.SetBool("u_DoDistortion", DoDistortion);
		CASShader.SetFloat("u_GrainStrength", GrainStrength);
		CASShader.SetFloat("u_DistortionK", DistortionK);

		SetCommonUniforms<GLClasses::Shader>(CASShader, UniformBuffer);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, Composited.GetTexture(0));

		ScreenQuadVAO.Bind();
		glDrawArrays(GL_TRIANGLES, 0, 6);
		ScreenQuadVAO.Unbind();

		// Finish 

		glFinish();
		app.FinishFrame();

		CurrentTime = glfwGetTime();
		DeltaTime = CurrentTime - Frametime;
		Frametime = glfwGetTime();

		GLClasses::DisplayFrameRate(app.GetWindow(), "Candela ");
	}
}
