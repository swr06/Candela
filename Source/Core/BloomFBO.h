#pragma once

#include <iostream>
#include <glad/glad.h>

namespace Candela
{
	class BloomFBO
	{
	public :
		BloomFBO(int w, int h);
		~BloomFBO();

		BloomFBO(const BloomFBO&) = delete;
		BloomFBO operator=(BloomFBO const&) = delete;

		BloomFBO(BloomFBO&& v)
		{
			m_Framebuffer = v.m_Framebuffer;
			m_Mips[0] = v.m_Mips[0];
			m_Mips[1] = v.m_Mips[1];
			m_Mips[2] = v.m_Mips[2];
			m_Mips[3] = v.m_Mips[3];
			m_Mips[4] = v.m_Mips[4];
			m_w = v.m_w;
			m_h = v.m_h;

			v.m_Framebuffer = 0;
			v.m_Mips[0] = 0;
			v.m_Mips[1] = 0;
			v.m_Mips[2] = 0;
			v.m_Mips[3] = 0;
			v.m_Mips[4] = 0;
			v.m_w = -1;
			v.m_h = -1;
		}

		void SetSize(int w, int h)
		{
			if (w != m_w || h != m_h)
			{
				DeleteEverything();
				Create(w, h);
				m_w = w;
				m_h = h;
			}
		}

		GLuint m_Framebuffer;
		GLuint m_Mips[5];

		inline int GetWidth() const { return m_w; }
		inline int GetHeight() const { return m_h; }

		void BindMip(int v);

		const float m_MipScales[5] = { 1.0f, 0.5f, 0.25f, 0.125f, 0.1f };

	private :
		void DeleteEverything();
		void Create(int w, int h);

		int m_w = -1, m_h = -1;
	};
}