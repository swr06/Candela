#include "BloomFBO.h"
#include <cmath>

namespace Candela
{ 
	BloomFBO::BloomFBO(int w, int h)
	{
		Create(w, h);
	}

	void BloomFBO::Create(int w, int h)
	{
		m_w = w;
		m_h = h;

		int w0, h0, w1, h1, w2, h2, w3, h3, w4, h4;

		w0 = std::floor(w * m_MipScales[0]);
		h0 = std::floor(h * m_MipScales[0]);

		w1 = std::floor(w * m_MipScales[1]);
		h1 = std::floor(h * m_MipScales[1]);

		w2 = std::floor(w * m_MipScales[2]);
		h2 = std::floor(h * m_MipScales[2]);

		w3 = std::floor(w * m_MipScales[3]);
		h3 = std::floor(h * m_MipScales[3]);

		w4 = std::floor(w * m_MipScales[4]);
		h4 = std::floor(h * m_MipScales[4]);

		glGenTextures(1, &m_Mips[0]);
		glBindTexture(GL_TEXTURE_2D, m_Mips[0]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, w0, h0, 0, GL_RGB, GL_FLOAT, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

		glGenTextures(1, &m_Mips[1]);
		glBindTexture(GL_TEXTURE_2D, m_Mips[1]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, w1, h1, 0, GL_RGB, GL_FLOAT, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

		glGenTextures(1, &m_Mips[2]);
		glBindTexture(GL_TEXTURE_2D, m_Mips[2]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, w2, h2, 0, GL_RGB, GL_FLOAT, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

		glGenTextures(1, &m_Mips[3]);
		glBindTexture(GL_TEXTURE_2D, m_Mips[3]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, w3, h3, 0, GL_RGB, GL_FLOAT, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

		glGenTextures(1, &m_Mips[4]);
		glBindTexture(GL_TEXTURE_2D, m_Mips[4]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, w4, h4, 0, GL_RGB, GL_FLOAT, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);

		glGenFramebuffers(1, &m_Framebuffer);
		glBindFramebuffer(GL_FRAMEBUFFER, m_Framebuffer);
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	BloomFBO::~BloomFBO()
	{
		DeleteEverything();
	}

	void BloomFBO::BindMip(int v)
	{
		if (v >= 5)
		{
			throw "Bloom BindMip() called with invalid arg!";
		}

		glBindFramebuffer(GL_FRAMEBUFFER, m_Framebuffer);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_Mips[v], 0);
		glDrawBuffer(GL_COLOR_ATTACHMENT0);
		glViewport(0, 0, floor(m_MipScales[v] * m_w), floor(m_MipScales[v] * m_h));
	}

	void BloomFBO::DeleteEverything()
	{
		glDeleteTextures(1, &m_Mips[0]);
		glDeleteTextures(1, &m_Mips[1]);
		glDeleteTextures(1, &m_Mips[2]);
		glDeleteTextures(1, &m_Mips[3]);
		glDeleteTextures(1, &m_Mips[4]);
		glDeleteFramebuffers(1, &m_Framebuffer);

		m_Mips[0] = 0;
		m_Mips[1] = 0;
		m_Mips[2] = 0;
		m_Mips[3] = 0;
		m_Mips[4] = 0;
		m_Framebuffer = 0;
	}
}