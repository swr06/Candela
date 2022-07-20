#pragma once

#include <glad/glad.h>
#include <iostream>

namespace Lumen
{
	class Shadowmap
	{
	public:
		Shadowmap() {}
		~Shadowmap();
		Shadowmap(const Shadowmap&) = delete;
		Shadowmap operator=(Shadowmap const&) = delete;

		Shadowmap& operator=(Shadowmap&& other)
		{
			std::swap(*this, other);
			return *this;
		}

		Shadowmap(Shadowmap&& v)
		{
			m_DepthMap = v.m_DepthMap;
			m_DepthMapFBO = v.m_DepthMapFBO;
			m_Width = v.m_Width;
			m_Height = v.m_Height;

			v.m_DepthMap = 0;
			v.m_DepthMapFBO = 0;
		}

		void Create(int,int);

		inline GLuint GetDepthTexture() const
		{
			return m_DepthMap;
		}

		void Bind() const
		{
			glBindFramebuffer(GL_FRAMEBUFFER, m_DepthMapFBO);
			glViewport(0, 0, m_Width, m_Height);
		}

		void Unbind() const
		{
			glBindFramebuffer(GL_FRAMEBUFFER, 0);
		}

		GLuint GetHandle() const noexcept { return m_Handle; }

		inline unsigned int GetWidth() const noexcept { return m_Width; }
		inline unsigned int GetHeight() const noexcept { return m_Height; }

	private:
		GLuint m_DepthMap = 0;
		GLuint m_DepthMapFBO = 0;
		GLuint m_Handle = 0;
		int m_Width = 0;
		int m_Height = 0;
	};
}