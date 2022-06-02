#include "DDGI.h"

#include "ShaderManager.h"

#include "ShadowMapHandler.h"

namespace Lumen {
	namespace DDGI {

		struct Ray {
			glm::vec4 RayOrigin;
			glm::vec4 RayDirection;
		};

		const int ProbeGridX = 48;
		const int ProbeGridY = 24;
		const int ProbeGridZ = 48;

		//const int ProbeGridX = 64;
		//const int ProbeGridY = 32;
		//const int ProbeGridZ = 64;

		//const glm::vec3 ProbeBoxSize = glm::vec3(12.0f, 6.0f, 12.0f);
		const glm::vec3 ProbeBoxSize = glm::vec3(24.0f, 12.0f, 24.0f);
		//const glm::vec3 ProbeBoxSize = glm::vec3(32.0f, 16.0f, 32.0f);

		static GLuint _ProbeDataTexture = 0;
		static GLuint _PrevProbeDataTexture = 0;
		static GLuint _ProbeMapSSBO = 0;
		static GLuint ProbeDataTexture = 0;

		static glm::vec3 LastOrigin = glm::vec3(0.0f);
		static glm::vec3 _PreviousOrigin = glm::vec3(0.0f);
	}
}

void Lumen::DDGI::Initialize()
{
	glGenTextures(1, &_ProbeDataTexture);
	glBindTexture(GL_TEXTURE_3D, _ProbeDataTexture);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA16F, ProbeGridX, ProbeGridY, ProbeGridZ, 0, GL_RGBA, GL_FLOAT, nullptr);

	glGenTextures(1, &_PrevProbeDataTexture);
	glBindTexture(GL_TEXTURE_3D, _PrevProbeDataTexture);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA16F, ProbeGridX, ProbeGridY, ProbeGridZ, 0, GL_RGBA, GL_FLOAT, nullptr);

	// 8x8 luminance and depth/variance map
	glGenBuffers(1, &_ProbeMapSSBO);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, _ProbeMapSSBO);
	glBufferData(GL_SHADER_STORAGE_BUFFER, (ProbeGridX * ProbeGridY * ProbeGridZ) * sizeof(glm::vec2) * 8 * 8, nullptr, GL_DYNAMIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}

static float Align(float value, float size)
{
	return std::floor(value / size) * size;
}

void Lumen::DDGI::UpdateProbes(int Frame, RayIntersector<BVH::StacklessTraversalNode>& Intersector, CommonUniforms& uniforms, GLuint Skymap)
{
	GLClasses::ComputeShader& ProbeUpdate = ShaderManager::GetComputeShader("PROBE_UPDATE");

	GLuint CurrentVolume = (Frame % 2 == 0) ? _ProbeDataTexture : _PrevProbeDataTexture;
	GLuint PreviousVolume = (Frame % 2 == 0) ? _PrevProbeDataTexture : _ProbeDataTexture;

	ProbeDataTexture = CurrentVolume;

	ProbeUpdate.Use();

	_PreviousOrigin = LastOrigin;

	LastOrigin = glm::vec3(uniforms.InvView[3]);
	LastOrigin.x = Align(LastOrigin.x, 1.0f);
	LastOrigin.y = Align(LastOrigin.y, 1.0f);
	LastOrigin.z = Align(LastOrigin.z, 1.0f);

	ProbeUpdate.SetVector3f("u_SunDirection", uniforms.SunDirection);
	ProbeUpdate.SetVector3f("u_BoxOrigin", LastOrigin);
	ProbeUpdate.SetVector3f("u_Resolution", glm::vec3(ProbeGridX,ProbeGridY,ProbeGridZ));
	ProbeUpdate.SetVector3f("u_Size", ProbeBoxSize);
	ProbeUpdate.SetVector3f("u_PreviousOrigin", _PreviousOrigin);
	ProbeUpdate.SetFloat("u_Time", glfwGetTime());
	ProbeUpdate.SetInteger("u_History", 3);
	ProbeUpdate.SetInteger("u_Skymap", 4);

	for (int i = 0; i < 5; i++) {

		const int BindingPointStart = 8;

		std::string Name = "u_ShadowMatrices[" + std::to_string(i) + "]";
		std::string NameClip = "u_ShadowClipPlanes[" + std::to_string(i) + "]";
		std::string NameTex = "u_ShadowTextures[" + std::to_string(i) + "]";

		ProbeUpdate.SetMatrix4(Name, ShadowHandler::GetShadowViewProjectionMatrix(i));
		ProbeUpdate.SetInteger(NameTex, i + BindingPointStart);
		ProbeUpdate.SetFloat(NameClip, ShadowHandler::GetShadowCascadeDistance(i));

		glActiveTexture(GL_TEXTURE0 + i + BindingPointStart);
		glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetShadowmap(i));
	}

	glActiveTexture(GL_TEXTURE3);
	glBindTexture(GL_TEXTURE_3D, PreviousVolume);

	glActiveTexture(GL_TEXTURE4);
	glBindTexture(GL_TEXTURE_CUBE_MAP, Skymap);

	glBindImageTexture(0, CurrentVolume, 0, GL_TRUE, 0, GL_READ_WRITE, GL_RGBA16F);

	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, _ProbeMapSSBO);

	Intersector.BindEverything(ProbeUpdate, uniforms.Frame < 128);

	glDispatchCompute(ProbeGridX / 8, ProbeGridY / 4, ProbeGridZ / 8);

	glUseProgram(0);
}

glm::vec3 Lumen::DDGI::GetProbeGridSize()
{
	return ProbeBoxSize;
}

glm::vec3 Lumen::DDGI::GetProbeGridRes()
{
	return glm::vec3(ProbeGridX, ProbeGridY, ProbeGridZ);
}

glm::vec3 Lumen::DDGI::GetProbeBoxOrigin()
{
	return LastOrigin;
}

GLuint Lumen::DDGI::GetVolume()
{
	return ProbeDataTexture;
}

GLuint Lumen::DDGI::GetProbeDataSSBO()
{
	return _ProbeMapSSBO;
}

