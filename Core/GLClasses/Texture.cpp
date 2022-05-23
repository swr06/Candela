#include "Texture.h"

#include <fstream>

#include <iostream>

namespace GLClasses
{
	static int LastID = 0;

	std::unordered_map<std::string, _TextureCacheEntry> CreatedTextures;
	std::vector<_TextureCacheEntry> CreatedTexturesArray;

	static bool FileExists(const std::string& str) {
		std::ifstream file(str);

		if (file.is_open() && file.good())
		{
			file.close();
			return true;
		}

		return false;

	}


	void Texture::CreateTexture(const string& path, bool hdr, bool mipmap, bool flip, GLenum type, GLenum min_filter, GLenum mag_filter, GLenum texwrap_s, GLenum texwrap_t, bool clean_up)
	{
		/*
		Check if the texture is already created, if it is, then use the existing texture. Else create a new one :)
		*/
		auto exists = CreatedTextures.find(path);

		if (exists == CreatedTextures.end())
		{
			if (!FileExists(path)) {
				return;
			}

			if (flip)
				stbi_set_flip_vertically_on_load(true);
			else
				stbi_set_flip_vertically_on_load(false);

			GLenum internalformat = 0;
			GLenum _internalformat = 0;

			m_delete_texture = true;
			m_clean_up = clean_up;
			m_type = type;
			m_path = path;

			glGenTextures(1, &m_Texture);
			glBindTexture(type, m_Texture);
			glTexParameteri(type, GL_TEXTURE_WRAP_S, texwrap_s);
			glTexParameteri(type, GL_TEXTURE_WRAP_T, texwrap_t);

			glTexParameteri(type, GL_TEXTURE_MIN_FILTER, mipmap ? GL_LINEAR_MIPMAP_LINEAR : min_filter);
			glTexParameteri(type, GL_TEXTURE_MAG_FILTER, mag_filter);
			

			if (mipmap) {
				GLfloat value, max_anisotropy = 8.0f; 
				glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, &value);
				value = (value > max_anisotropy) ? max_anisotropy : value;
				glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, value);
			}

			// Force 4 bytes per pixel 
			unsigned char* image = stbi_load(path.c_str(), &m_width, &m_height, &m_BPP, 4);
			m_BPP = 4;

			if (m_BPP == 1)
			{
				internalformat = GL_RED;
				_internalformat = GL_RED;
			}

			else if (m_BPP == 3)
			{
				internalformat = GL_RGB;
				_internalformat = hdr ? GL_SRGB : GL_RGB;
			}

			else if (m_BPP == 4)
			{
				internalformat = GL_RGBA;
				_internalformat = hdr ? GL_SRGB_ALPHA : GL_RGBA;
			}

			if (image)
			{
				_TextureCacheEntry data =
				{
					path,
					m_Texture, m_TextureHandle,
					m_width,
					m_height,
					m_BPP,
					internalformat,
					type, LastID
				};

				LastID += 1;

				glTexImage2D(type, 0, _internalformat, m_width, m_height, 0, internalformat, GL_UNSIGNED_BYTE, image);
				
				if (mipmap)
				{
					glGenerateMipmap(type);
				}

				if (clean_up)
				{
					stbi_image_free(image);
				}

				// texture handle generate mado
				m_TextureHandle = glGetTextureHandleARB(m_Texture);
				glMakeTextureHandleResidentARB(m_TextureHandle);
				
				data.handle = m_TextureHandle;

				CreatedTextures[path] = data;

				CreatedTexturesArray.push_back(data);
			}
		}

		else
		{
			const _TextureCacheEntry& tex = CreatedTextures.at(path);
			m_Texture = tex.id;
			m_BPP = tex.bpp;
			m_path = tex.path;
			m_width = tex.width;
			m_height = tex.height;
			m_intformat = tex.intformat;
			m_TextureHandle = tex.handle;
		}

		
	}

	ExtractedImageData ExtractTextureData(const std::string& path)
	{
		ExtractedImageData return_val;

		return_val.image_data = stbi_load(path.c_str(), &return_val.width, &return_val.height, &return_val.channels, 0);
		return return_val;
	}

	GLuint GetTextureIDForPath(const std::string& path)
	{
		auto exists = CreatedTextures.find(path);

		if (exists == CreatedTextures.end()) {
			return 0;
		}

		const _TextureCacheEntry& tex = CreatedTextures.at(path);

		return tex.id;
	}

	_TextureCacheEntry GetTextureCachedDataForPath(const std::string& path, bool& valid)
	{
		valid = true;

		auto exists = CreatedTextures.find(path);

		if (exists == CreatedTextures.end()) {
			//throw "wtf";

			valid = false;

			for (auto& e : CreatedTextures) {
				return e.second;
			}

		}

		const _TextureCacheEntry& tex = CreatedTextures.at(path);

		return tex;
	}
}