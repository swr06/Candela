#include "SkyShadowMap.h"

namespace Lumen
{
    void SkyShadowmap::Create(int w, int h)
    {
        m_Width = w;
        m_Height = h;

        for (int i = 0; i < SKY_SHADOWMAP_COUNT; i++) {

            glGenTextures(1, &m_DepthMaps[i]);
            glBindTexture(GL_TEXTURE_2D, m_DepthMaps[i]);
            glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, w, h, 0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_BORDER);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_BORDER);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);
            float col[] = { 1.0f, 1.0f, 1.0f, 1.0f };
            glTexParameterfv(GL_TEXTURE_2D, GL_TEXTURE_BORDER_COLOR, col);

            glGenFramebuffers(1, &m_DepthMapFBOs[i]);
            glBindFramebuffer(GL_FRAMEBUFFER, m_DepthMapFBOs[i]);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, m_DepthMaps[i], 0);

            glDrawBuffer(GL_NONE);
            glReadBuffer(GL_NONE);

            if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
            {
                throw "Shadowmap creation failed!";
            }

            glBindFramebuffer(GL_FRAMEBUFFER, 0);
        }
    }

    SkyShadowmap::~SkyShadowmap()
    {
        for (int i = 0; i < SKY_SHADOWMAP_COUNT; i++)
        {
            glDeleteTextures(1, &m_DepthMaps[i]);
            glDeleteFramebuffers(1, &m_DepthMapFBOs[i]);
        }
    }


}