#pragma once

#include "stb_image.h"

#include <glad/glad.h>

#include <string>
#include <vector>
#include <iostream>

namespace GLClasses
{
	using namespace std;

	class CubeTextureMap
	{
	public : 

		void CreateCubeTextureMap(const std::vector<std::string>& cube_face_paths, bool hdr = true);
		inline GLuint GetID() const { return m_TextureID; }

		CubeTextureMap() {}
		CubeTextureMap(const CubeTextureMap&) = delete;
		CubeTextureMap operator=(CubeTextureMap const&) = delete;

		CubeTextureMap(CubeTextureMap&& v)
		{
			m_TextureID = v.m_TextureID;
			m_CubeFacePaths = v.m_CubeFacePaths;
			v.m_TextureID = 0;
		}

		void Bind(int slot = 0) const 
		{
			glActiveTexture(GL_TEXTURE0 + slot);
			glBindTexture(GL_TEXTURE_CUBE_MAP, GetID());
		}

	private :

		GLuint m_TextureID;
		
		std::vector<std::string> m_CubeFacePaths;
	};
}