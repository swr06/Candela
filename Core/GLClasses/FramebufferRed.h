#pragma once

#include <iostream>
#include <string>
#include <glad/glad.h>
#include "../Application/Logger.h"

namespace GLClasses
{
	class FramebufferRed
	{
	public:
		FramebufferRed(unsigned int w = 16, unsigned int h = 16);
		~FramebufferRed();

		FramebufferRed(const FramebufferRed&) = delete;
		FramebufferRed operator=(FramebufferRed const&) = delete;

		FramebufferRed& operator=(FramebufferRed&& other)
		{
			std::swap(*this, other);
			return *this;
		}

		FramebufferRed(FramebufferRed&& v) 
		{
			m_FBO = v.m_FBO;
			m_TextureAttachment = v.m_TextureAttachment;
			m_FBWidth = v.m_FBWidth;
			m_FBHeight = v.m_FBHeight;

			v.m_FBO = 0;
			v.m_TextureAttachment = 0;
		}

		void Bind() const
		{
			glBindFramebuffer(GL_FRAMEBUFFER, m_FBO);
			glViewport(0, 0, m_FBWidth, m_FBHeight);
		}


		void Unbind() const
		{
			glBindFramebuffer(GL_FRAMEBUFFER, 0);
		}

		void SetSize(uint32_t width, uint32_t height)
		{
			if (width != m_FBWidth || height != m_FBHeight)
			{
				glDeleteFramebuffers(1, &m_FBO);
				glDeleteTextures(1, &m_TextureAttachment);

				m_FBO = 0;
				m_TextureAttachment = 0;
				m_FBWidth = width;
				m_FBHeight = height;
				CreateFramebuffer();
			}
		}

		inline GLuint GetTexture() const
		{
			return m_TextureAttachment;
		}

		inline GLuint GetFramebuffer() const noexcept { return m_FBO; }
		inline unsigned int GetWidth() const noexcept { return m_FBWidth; }
		inline unsigned int GetHeight() const noexcept { return m_FBHeight; }

		float GetExposure() const noexcept
		{
			return m_Exposure;
		}

		// Creates the framebuffer with the appropriate settings
		void CreateFramebuffer();

	private:

		GLuint m_FBO; // The Framebuffer object
		GLuint m_TextureAttachment; // The actual texture attachment
		int m_FBWidth;
		int m_FBHeight;
		float m_Exposure = 0.0f;
	};
}