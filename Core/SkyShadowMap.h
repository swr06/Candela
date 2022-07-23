#pragma once 

#include <glm/glm.hpp>

#include <glad/glad.h>

#include <iostream>

#include <array>

#include "Macros.h"

namespace Candela {

	class SkyShadowmap
	{
	public:
		SkyShadowmap() {}
		~SkyShadowmap();
		SkyShadowmap(const SkyShadowmap&) = delete;
		SkyShadowmap operator=(SkyShadowmap const&) = delete;

		SkyShadowmap& operator=(SkyShadowmap&& other)
		{
			std::swap(*this, other);
			return *this;
		}

		SkyShadowmap(SkyShadowmap&& v)
		{
			m_DepthMaps = v.m_DepthMaps;
			m_DepthMapFBOs = v.m_DepthMapFBOs;
			m_Width = v.m_Width;
			m_Height = v.m_Height;

			memset(v.m_DepthMaps.data(), 0, sizeof(GLuint) * SKY_SHADOWMAP_COUNT);
			memset(v.m_DepthMapFBOs.data(), 0, sizeof(GLuint) * SKY_SHADOWMAP_COUNT);
		}

		void Create(int, int);

		inline GLuint GetDepthTexture(int n) const
		{
			if (n < 0 || n >= SKY_SHADOWMAP_COUNT) {
				throw "bro what";
			}

			return m_DepthMaps[n];
		}

		void Bind(int n) const
		{
			if (n < 0 || n >= SKY_SHADOWMAP_COUNT) {
				throw "bro what";
			}

			glBindFramebuffer(GL_FRAMEBUFFER, m_DepthMapFBOs[n]);
			glViewport(0, 0, m_Width, m_Height);
		}

		void Unbind() const
		{
			glBindFramebuffer(GL_FRAMEBUFFER, 0);
		}

		inline unsigned int GetWidth() const noexcept { return m_Width; }
		inline unsigned int GetHeight() const noexcept { return m_Height; }

	private:
		std::array<GLuint, SKY_SHADOWMAP_COUNT> m_DepthMaps;
		std::array<GLuint, SKY_SHADOWMAP_COUNT> m_DepthMapFBOs;
		int m_Width = 0;
		int m_Height = 0;
	};
}