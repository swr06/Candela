#include "FramebufferRed.h"

#ifndef NULL
#define NULL 0
#endif

namespace GLClasses
{
    FramebufferRed::FramebufferRed(unsigned int w, unsigned int h) :
        m_FBO(0), m_FBWidth(w), m_FBHeight(h)
    {
        // CreateFramebuffer();
    }

    FramebufferRed::~FramebufferRed()
    {
        glDeleteFramebuffers(1, &m_FBO);
    }

    void FramebufferRed::CreateFramebuffer()
    {
        int w = m_FBWidth;
        int h = m_FBHeight;

        glGenFramebuffers(1, &m_FBO);
        glBindFramebuffer(GL_FRAMEBUFFER, m_FBO);

        glGenTextures(1, &m_TextureAttachment);
        glBindTexture(GL_TEXTURE_2D, m_TextureAttachment);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, w, h, 0, GL_RED, GL_FLOAT, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, m_TextureAttachment, 0);

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        {
            Candela::Logger::Log("Fatal error! Framebuffer creation failed!");
        }

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }


}