#pragma once

#include <iostream>
#include <string>
#include <glad/glad.h>
#include "../Application/Logger.h"
#include <vector>

#include <glm/glm.hpp>

namespace GLClasses
{
	struct FORMAT
	{
		GLenum Format;
		GLenum InternalFormat;
		GLenum Type;
		bool MinFilter = true; // false = nearest; true = linear
		bool MagFilter = true; // false = nearest; true = linear
		bool ClampToBorder = false;
	};

	class Framebuffer
	{
	public :
		Framebuffer(unsigned int w, unsigned int h, std::vector<FORMAT> format, bool create_on_construct, bool has_depth_attachment = false);
		Framebuffer(unsigned int w, unsigned int h, FORMAT format, bool create_on_construct, bool has_depth_attachment = false);
		~Framebuffer();

		Framebuffer(const Framebuffer&) = delete;
		Framebuffer operator=(Framebuffer const&) = delete;

		Framebuffer& operator=(Framebuffer&& other)
		{
			std::swap(*this, other);
			return *this;
		}

		Framebuffer(Framebuffer&& v) : m_HasDepthMap(v.m_HasDepthMap)
		{
			m_FBO = v.m_FBO;
			m_TextureAttachments = v.m_TextureAttachments;
			m_DepthBuffer = v.m_DepthBuffer;
			m_FBWidth = v.m_FBWidth;
			m_FBHeight = v.m_FBHeight;
			m_Format = v.m_Format;

			v.m_FBO = 0;
			v.m_TextureAttachments.clear();
			v.m_Format.clear();
			v.m_DepthBuffer = 0;
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
				std::cout << "\nFramebuffer resize! : ID : " << m_FBO << " !" << "\n";

				glDeleteFramebuffers(1, &m_FBO);

				for (int i = 0; i < m_TextureAttachments.size(); i++)
				{
					glDeleteTextures(1, &m_TextureAttachments[i]);
					m_TextureAttachments[i];
				}
				glDeleteRenderbuffers(1, &m_DepthBuffer);

				m_FBO = 0;
				m_DepthBuffer = 0;
				m_FBWidth = width;
				m_FBHeight = height;
				CreateFramebuffer();
			}
		}

		inline GLuint GetTexture(int n = 0) const
		{
			if (n >= m_TextureAttachments.size())
			{
				throw "invalid texture attachment queried";
			}

			return m_TextureAttachments.at(n);
		}

		inline GLuint GetDepthBuffer() const
		{
			if (m_DepthBuffer == 0)
				throw "Depth buffer tried to be accessed when it doesn't exist!";

			return m_DepthBuffer;
		}

		inline GLuint GetFramebuffer() const noexcept { return m_FBO; }
		inline unsigned int GetWidth() const noexcept { return m_FBWidth; }
		inline unsigned int GetHeight() const noexcept { return m_FBHeight; }

		glm::vec2 GetDimensions() const noexcept { return glm::vec2(GetWidth(), GetHeight()); }

		// Creates the framebuffer with the appropriate settings
		void CreateFramebuffer();

	private :

		GLuint m_FBO; // The Framebuffer object
		std::vector<GLuint> m_TextureAttachments; // The actual texture attachment
		GLuint m_DepthBuffer;
		int m_FBWidth;
		int m_FBHeight;
		const bool m_HasDepthMap;
		std::vector<FORMAT> m_Format;
	};
}