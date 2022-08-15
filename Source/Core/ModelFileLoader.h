#pragma once

#include <glad/glad.h>

#include <iostream>
#include <vector>
#include <filesystem>
#include <sstream>
#include <cstdio>
#include <cstdlib> 

#include "Mesh.h"
#include "Object.h"

#include <glm/glm.hpp>

namespace Candela
{
	namespace FileLoader
	{
		struct _MeshMaterialData {
			std::string Albedo;
			std::string Normal;
			glm::vec3 ModelColor;
		};

		void LoadModelFile(Object* object, const std::string& filepath);
		std::vector<_MeshMaterialData> GetMeshTexturePaths();
	}
}