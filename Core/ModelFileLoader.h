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

namespace Lumen
{
	namespace FileLoader
	{
		struct _TexturePaths {
			std::string Albedo;
			std::string Normal;
		};

		void LoadModelFile(Object* object, const std::string& filepath);
		std::vector<_TexturePaths> GetMeshTexturePaths();
	}
}