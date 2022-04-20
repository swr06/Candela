#pragma once

#include <glad/glad.h>
#include <iostream>
#include <vector>
#include <string>
#include <cstdio>
#include <cassert>
#include "Application/Logger.h"

#include <glm/glm.hpp>

namespace Lumen
{
	class ProbeMap
	{
	public :

		ProbeMap(GLuint res);

		ProbeMap(const ProbeMap&) = delete;
		ProbeMap operator=(ProbeMap const&) = delete;

		ProbeMap(ProbeMap&& v)
		{
			m_FBO = v.m_FBO;
			m_CubemapTexture = v.m_CubemapTexture;
			m_Resolution = v.m_Resolution;
			m_DepthCubemap = v.m_DepthCubemap;
			m_DepthBuffer = v.m_DepthBuffer;
			NormalPBRPackedCubemap = v.NormalPBRPackedCubemap;
			v.m_FBO = 0;
			v.m_CubemapTexture = 0;
			v.m_DepthCubemap = 0;
			v.m_DepthBuffer = 0;
			v.NormalPBRPackedCubemap = 0;
		}

		void Bind() const
		{
			glBindFramebuffer(GL_FRAMEBUFFER, m_FBO);
			glViewport(0, 0, m_Resolution, m_Resolution);
		}

		void BindFace(GLuint face, bool clear) const
		{
			assert(!(face >= 6));
			assert(!(m_CubemapTexture == 0));
			assert(!(m_DepthCubemap == 0));
			assert(!(NormalPBRPackedCubemap == 0));

			Bind();
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_POSITIVE_X + face, m_CubemapTexture, 0);
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_CUBE_MAP_POSITIVE_X + face, m_DepthCubemap, 0);
			glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_CUBE_MAP_POSITIVE_X + face, NormalPBRPackedCubemap, 0);
			
			glViewport(0, 0, m_Resolution, m_Resolution);

			if (clear) {
				glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
			}

		}

		void Unbind() const
		{
			glBindFramebuffer(GL_FRAMEBUFFER, 0);
			glBindTexture(GL_TEXTURE_CUBE_MAP, 0);
		}

		inline GLuint GetTexture() const
		{
			return m_CubemapTexture;
		}

		inline GLuint GetFramebuffer() const
		{
			return m_FBO;
		}

		inline GLuint GetResolution() const
		{
			return m_Resolution;
		}

		GLuint m_FBO = 0;
		GLuint m_DepthBuffer = 0;

		// Cubemaps 
		GLuint m_CubemapTexture = 0;
		GLuint m_DepthCubemap = 0;
		GLuint NormalPBRPackedCubemap = 0; 

	private :
		GLuint m_Resolution;

		
	};
}