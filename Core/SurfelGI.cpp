#include "SurfelGI.h"

#include "ShaderManager.h"

const glm::ivec3 SurfelVolumeSize = glm::ivec3(32, 16, 32);
const int MaxSurfelsInCell = 8; 

Lumen::SurfelGIHandler::SurfelGIHandler()
{

}

void Lumen::SurfelGIHandler::Initialize()
{
	std::vector<Surfel> Zerodata;

	Zerodata.resize(SurfelVolumeSize.x * SurfelVolumeSize.y * SurfelVolumeSize.z * MaxSurfelsInCell);

	for (int i = 0; i < Zerodata.size(); i++) {
		Zerodata[i].Position = glm::vec4(0.0f);
		Zerodata[i].Normal = glm::vec4(0.0f);
		Zerodata[i].Radiance = glm::vec4(0.0f);
		Zerodata[i].Extra = glm::vec4(0.0f);
	}
	 
	glGenBuffers(1, &m_SurfelCellVolume);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, m_SurfelCellVolume);
	glBufferData(GL_SHADER_STORAGE_BUFFER, SurfelVolumeSize.x * SurfelVolumeSize.y * SurfelVolumeSize.z * sizeof(Surfel) * MaxSurfelsInCell, Zerodata.data(), GL_DYNAMIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	Zerodata.clear();
}

void Lumen::SurfelGIHandler::UpdateSurfels(int Frame, GLClasses::Framebuffer& GBuffer, const CommonUniforms& Uniforms, FPSCamera& Camera)
{
	// Surfelize

	float Time = glfwGetTime();

	GLClasses::ComputeShader& SurfelSpawnShader = ShaderManager::GetComputeShader("SURFEL_SPAWN");

	SurfelSpawnShader.Use();
	SurfelSpawnShader.SetInteger("u_Depth", 0);
	SurfelSpawnShader.SetInteger("u_Normals", 1);
	SurfelSpawnShader.SetMatrix4("u_InverseView", Uniforms.InvView);
	SurfelSpawnShader.SetMatrix4("u_InverseProjection", Uniforms.InvProjection);
	SurfelSpawnShader.SetMatrix4("u_Projection", Uniforms.Projection);
	SurfelSpawnShader.SetMatrix4("u_View", Uniforms.View);
	SurfelSpawnShader.SetFloat("u_Time", Time);
	SurfelSpawnShader.SetFloat("u_zNear", Camera.GetNearPlane());
	SurfelSpawnShader.SetFloat("u_zFar", Camera.GetFarPlane());

	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D, GBuffer.GetDepthBuffer());

	glActiveTexture(GL_TEXTURE1);
	glBindTexture(GL_TEXTURE_2D, GBuffer.GetTexture(3));

	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, m_SurfelCellVolume);

	glDispatchCompute((int)floor(float(GBuffer.GetWidth()) / 16.0f), (int)(floor(float(GBuffer.GetHeight())) / 16.0f), 1);

}

