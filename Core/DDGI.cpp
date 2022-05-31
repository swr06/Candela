#include "DDGI.h"

#include "ShaderManager.h"

#include "ShadowMapHandler.h"

namespace Lumen {
	namespace DDGI {

		struct Ray {
			glm::vec4 RayOrigin;
			glm::vec4 RayDirection;
		};

		const int ProbeGridX = 12;
		const int ProbeGridY = 8;
		const int ProbeGridZ = 12;
		
		// These should multiply to ProbeGridX * ProbeGridY * ProbeGridZ
		const int FactorPairX = 24;
		const int FactorPairY = 48;

		const int RayCount = 32; // <- Number of rays to cast, per probe, per frame

		static GLuint ProbeGridData; // each probe consisting of 12 * 12 pixels 
		static GLuint RayBuffer; // each probe consisting of 12 * 12 pixels 
	}
}

void Lumen::DDGI::Initialize()
{
	glGenBuffers(1, &ProbeGridData);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, ProbeGridData);
	glBufferData(GL_SHADER_STORAGE_BUFFER, ProbeGridX * ProbeGridY * ProbeGridZ * sizeof(glm::vec4) * 8 * 4, nullptr, GL_STATIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);

	glGenBuffers(1, &RayBuffer);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, RayBuffer);
	glBufferData(GL_SHADER_STORAGE_BUFFER, ((ProbeGridX * ProbeGridY * ProbeGridZ)+1) * RayCount * sizeof(Lumen::DDGI::Ray), nullptr, GL_DYNAMIC_DRAW);
	glBindBuffer(GL_SHADER_STORAGE_BUFFER, 0);
}


void Lumen::DDGI::UpdateProbes(int Frame, RayIntersector<BVH::StacklessTraversalNode>& Intersector)
{
	glm::vec3 GridDims = glm::vec3(ProbeGridX, ProbeGridY, ProbeGridZ);

	GLClasses::ComputeShader& DDGIRayGen = ShaderManager::GetComputeShader("DDGI_RAYGEN");
	GLClasses::ComputeShader& DDGIRaytrace = ShaderManager::GetComputeShader("DDGI_RT");

	// First, generate rays 
	DDGIRayGen.Use();
	DDGIRayGen.SetInteger("u_Rays", RayCount);
	DDGIRayGen.SetInteger("u_Frame", Frame);
	DDGIRayGen.SetVector3f("u_ProbeGridDimensions", GridDims);

	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, RayBuffer);
	glDispatchCompute(ProbeGridX / 8, ProbeGridY / 4, ProbeGridZ / 8);

	glUseProgram(0);

	// Intersect 

	int TotalRayCount = ProbeGridX * ProbeGridY * ProbeGridZ * RayCount;

	DDGIRaytrace.Use();

	DDGIRaytrace.SetInteger("u_RayCount", TotalRayCount);

	for (int i = 0; i < 5; i++) {

		const int BindingPointStart = 4;

		std::string Name = "u_ShadowMatrices[" + std::to_string(i) + "]";
		std::string NameClip = "u_ShadowClipPlanes[" + std::to_string(i) + "]";
		std::string NameTex = "u_ShadowTextures[" + std::to_string(i) + "]";

		DDGIRaytrace.SetMatrix4(Name, ShadowHandler::GetShadowViewProjectionMatrix(i));
		DDGIRaytrace.SetInteger(NameTex, i + BindingPointStart);
		DDGIRaytrace.SetFloat(NameClip, ShadowHandler::GetShadowCascadeDistance(i));

		glActiveTexture(GL_TEXTURE0 + i + BindingPointStart);
		glBindTexture(GL_TEXTURE_2D, ShadowHandler::GetShadowmap(i));
	}

	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, RayBuffer);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, ProbeGridData);
	Intersector.BindEverything(DDGIRaytrace, Frame < 60);

	glDispatchCompute(TotalRayCount / 256, 1, 1);

	//u_ProbeGridDimensionsFactors
}

