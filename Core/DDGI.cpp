#include "DDGI.h"

#include "ShaderManager.h"

#include "ShadowMapHandler.h"

namespace Lumen {
	namespace DDGI {

		struct Ray {
			glm::vec4 RayOrigin;
			glm::vec4 RayDirection;
		};

		const int ProbeGridX = 16;
		const int ProbeGridY = 8;
		const int ProbeGridZ = 16;

		const int RayCount = 24; // <- Number of rays to cast, per probe, per frame

		static GLuint ProbeGridData; // each probe consisting of 12 * 12 pixels 
		static GLuint RayBuffer; // each probe consisting of 12 * 12 pixels 
	}
}

void Lumen::DDGI::Initialize()
{
	glGenBuffers(1, &ProbeGridData);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, ProbeGridData);
	glBufferData(GL_SHADER_STORAGE_BUFFER, ProbeGridX * ProbeGridY * ProbeGridZ * sizeof(glm::vec4) * 12 * 12, nullptr, GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	glGenBuffers(1, &RayBuffer);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, RayBuffer);
	glBufferData(GL_SHADER_STORAGE_BUFFER, ((ProbeGridX * ProbeGridY * ProbeGridZ)+1) * RayCount * sizeof(Lumen::DDGI::Ray), nullptr, GL_DYNAMIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}

void Lumen::DDGI::UpdateProbes(int Frame)
{
	glm::vec3 GridDims = glm::vec3(ProbeGridX, ProbeGridY, ProbeGridZ);

	GLClasses::ComputeShader& DDGIRayGen = ShaderManager::GetComputeShader("DDGI_RAYGEN");

	DDGIRayGen.Use();
	DDGIRayGen.SetInteger("u_Rays", RayCount);
	DDGIRayGen.SetInteger("u_Frame", Frame);
	DDGIRayGen.SetVector3f("u_ProbeGridDimensions", GridDims);

	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, RayBuffer);
	glDispatchCompute(ProbeGridX / 8, ProbeGridY / 4, ProbeGridZ / 8);

	glUseProgram(0);
}
