#pragma once 

#include "Shadowmap.h"
#include "ShadowRenderer.h"

#include <iostream>

namespace Lumen {
	
	namespace ShadowHandler {

		void GenerateShadowMaps();
		void UpdateShadowMaps(int Frame, const glm::vec3& Origin, const glm::vec3& Direction, const std::vector<Entity*> Entities, float DistanceMultiplier);
		GLuint GetShadowmap(int n);
		glm::mat4 GetShadowViewMatrix(int n);
		glm::mat4 GetShadowProjectionMatrix(int n);
		glm::mat4 GetShadowViewProjectionMatrix(int n);
		void CalculateClipPlanes(const glm::mat4& Projection);
		float GetShadowCascadeDistance(int n);
	}

}