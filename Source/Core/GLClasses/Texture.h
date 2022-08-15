#pragma once

#include "stb_image.h"
#include <unordered_map>
#include <glad/glad.h>

#include <string>
#include <array>

namespace GLClasses
{
	using namespace std;

	struct _TextureCacheEntry
	{
		std::string path;
		GLuint id;
		GLuint64 handle;

		int width;
		int height;
		int bpp;
		GLenum intformat;
		GLenum type;

		int id_;
	};

	struct ExtractedImageData
	{
		unsigned char* image_data;
		int width;
		int height;
		int channels;
	};

	class Texture
	{
	public:

		Texture()
		{
			m_clean_up = true;
			m_width = 0;
			m_height = 0;
			m_Texture = 0;
			m_type = GL_TEXTURE_2D;
			m_intformat = GL_RGBA;
			m_BPP = 0;
			m_delete_texture = true;
		}

		~Texture()
		{
			if (this->m_delete_texture == 1)
			{
				glDeleteTextures(1, &m_Texture);
			}

			else
			{
				// Don't delete
			}
		}

		Texture(const Texture&) = delete;
		Texture operator=(Texture const&) = delete;
		Texture(Texture&& v)
		{
			m_clean_up = v.m_clean_up;
			m_width = v.m_width;
			m_height = v.m_height;
			m_BPP = v.m_BPP;
			m_intformat = v.m_intformat;
			m_Texture = v.m_Texture;
			m_type = v.m_type;
			m_path = v.m_path;

			v.m_Texture = 0;
		}

		void CreateTexture(const string& path, bool hdr = false, bool mipmap = false, bool flip = false, GLenum type = GL_TEXTURE_2D,
			GLenum min_filter = GL_LINEAR, GLenum mag_filter = GL_LINEAR,
			GLenum texwrap_s = GL_REPEAT, GLenum texwrap_t = GL_REPEAT, bool clean_up = true);

		inline int GetWidth() const
		{
			return m_width;
		}

		inline int GetHeight() const
		{
			return m_height;
		}

		inline void Bind(int slot = 0) const
		{
			glActiveTexture(GL_TEXTURE0 + slot);
			glBindTexture(this->m_type, m_Texture);
		}

		inline bool IsCreated() const
		{
			return m_Texture != 0;
		}

		inline void Unbind() const
		{
			glBindTexture(m_type, 0);
		}

		inline GLuint GetTextureID() const
		{
			return m_Texture;
		};

		inline GLuint GetID() const
		{
			return m_Texture;
		};

		inline string GetTexturePath() const
		{
			return m_path;
		}

		int m_delete_texture;

	private:

		bool m_clean_up;

		int m_width;
		int m_height;
		int m_BPP;
		GLenum m_intformat;
		GLuint m_Texture = 0;
		GLenum m_type;
		string m_path;
		GLuint64 m_TextureHandle = 0;
	};

	ExtractedImageData ExtractTextureData(const std::string& path);

	GLuint GetTextureIDForPath(const std::string& path);
	_TextureCacheEntry GetTextureCachedDataForPath(const std::string& path, bool&);
}