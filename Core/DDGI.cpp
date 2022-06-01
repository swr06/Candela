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

		const glm::vec3 ProbeBoxSize = glm::vec3(12.0f, 12.0f, 12.0f);

		static GLuint _ProbeDataTexture = 0;
		static GLuint _PrevProbeDataTexture = 0;
		static GLuint ProbeDataTexture = 0;

		static glm::vec3 LastOrigin = glm::vec3(0.0f);
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
}


void Lumen::DDGI::UpdateProbes(int Frame, RayIntersector<BVH::StacklessTraversalNode>& Intersector, CommonUniforms& uniforms)
{
	GLClasses::ComputeShader& ProbeUpdate = ShaderManager::GetComputeShader("PROBE_UPDATE");

	GLuint CurrentVolume = (Frame % 2 == 0) ? _ProbeDataTexture : _PrevProbeDataTexture;
	GLuint PreviousVolume = (Frame % 2 == 0) ? _PrevProbeDataTexture : _ProbeDataTexture;

	ProbeDataTexture = CurrentVolume;

	ProbeUpdate.Use();

	LastOrigin = glm::vec3(0.0f); //glm::vec3(uniforms.InvView[3]);

	ProbeUpdate.SetVector3f("u_SunDirection", uniforms.SunDirection);
	ProbeUpdate.SetVector3f("u_BoxOrigin", LastOrigin);
	ProbeUpdate.SetVector3f("u_Resolution", glm::vec3(ProbeGridX,ProbeGridY,ProbeGridZ));
	ProbeUpdate.SetVector3f("u_Size", ProbeBoxSize);
	ProbeUpdate.SetFloat("u_Time", glfwGetTime());
	ProbeUpdate.SetInteger("u_History", 3);

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

	glBindImageTexture(0, CurrentVolume, 0, GL_TRUE, 0, GL_READ_WRITE, GL_RGBA16F);

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

