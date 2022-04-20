#pragma once

#include <glad/glad.h>
#include "../Application/Logger.h"
#include <iostream>

namespace GLClasses
{
	class DepthBuffer
	{
	public:
		DepthBuffer(unsigned int w, unsigned int h);
		~DepthBuffer();
		DepthBuffer(const DepthBuffer&) = delete;
		DepthBuffer operator=(DepthBuffer const&) = delete;

		DepthBuffer& operator=(DepthBuffer&& other)
		{
			std::swap(*this, other);
			return *this;
		}

		DepthBuffer(DepthBuffer&& v)
		{
			m_DepthMap = v.m_DepthMap;
			m_DepthMapFBO = v.m_DepthMapFBO;
			m_Width = v.m_Width;
			m_Height = v.m_Height;

			v.m_DepthMap = 0;
			v.m_DepthMapFBO = 0;
		}

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

		void OnUpdate()
		{
			Bind();
			glClear(GL_DEPTH_BUFFER_BIT);
		}

		inline unsigned int GetWidth() const noexcept { return m_Width; }
		inline unsigned int GetHeight() const noexcept { return m_Height; }

	private:
		GLuint m_DepthMap = 0;
		GLuint m_DepthMapFBO = 0;
		int m_Width = 0;
		int m_Height = 0;
	};
}