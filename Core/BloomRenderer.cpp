#include "BloomRenderer.h"

#include "ShaderManager.h"

namespace Candela
{
	namespace BloomRenderer
	{
		static std::unique_ptr<GLClasses::VertexBuffer> BloomFBOVBO;
		static std::unique_ptr<GLClasses::VertexArray> BloomFBOVAO;
		static std::unique_ptr<GLClasses::Framebuffer> BloomAlternateFBO;

		void Initialize()
		{
			BloomFBOVBO = std::unique_ptr<GLClasses::VertexBuffer>(new GLClasses::VertexBuffer);
			BloomFBOVAO = std::unique_ptr<GLClasses::VertexArray>(new GLClasses::VertexArray);
			BloomAlternateFBO = std::unique_ptr<GLClasses::Framebuffer>(new GLClasses::Framebuffer(16, 16, { GL_RGB16F, GL_RGB, GL_FLOAT }, false));
			BloomAlternateFBO->CreateFramebuffer();														 

			float QuadVertices[] =
			{
				-1.0f,  1.0f,  0.0f, 1.0f, -1.0f, -1.0f,  0.0f, 0.0f,
				 1.0f, -1.0f,  1.0f, 0.0f, -1.0f,  1.0f,  0.0f, 1.0f,
				 1.0f, -1.0f,  1.0f, 0.0f,  1.0f,  1.0f,  1.0f, 1.0f
			};

			BloomFBOVBO->BufferData(sizeof(QuadVertices), QuadVertices, GL_STATIC_DRAW);
			BloomFBOVAO->Bind();
			BloomFBOVBO->Bind();
			BloomFBOVBO->VertexAttribPointer(0, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), 0);
			BloomFBOVBO->VertexAttribPointer(1, 2, GL_FLOAT, 0, 4 * sizeof(GLfloat), (void*)(2 * sizeof(GLfloat)));
			BloomFBOVAO->Unbind();

			//BloomBlurShader->CreateShaderProgramFromFile("Core/Shaders/FBOVert.glsl", "Core/Shaders/BloomBlurTwoPass.glsl");
			//BloomBlurShader->CompileShaders();
			//
			//BloomMaskShader->CreateShaderProgramFromFile("Core/Shaders/FBOVert.glsl", "Core/Shaders/BloomMaskFrag.glsl");
			//BloomMaskShader->CompileShaders();
		}

		void BlurBloomMip(BloomFBO& bloomfbo, BloomFBO& bloomfbo_alt, int mip_num, GLuint source_tex, GLuint bright_tex, bool hq, bool wide)
		{
			GLClasses::Shader* BloomBlurShader = &(ShaderManager::GetShader("BLOOM_BLUR"));

			bool KernelWideFlags[5] = { false, false, false, true, false };

			if (wide) {
				KernelWideFlags[0] = true;
				KernelWideFlags[1] = false;
				KernelWideFlags[2] = true;
				KernelWideFlags[3] = false;
				KernelWideFlags[4] = true;
			}

			GLClasses::Shader& GaussianBlur = *BloomBlurShader;

			float AspectRatio = bloomfbo.GetWidth() / bloomfbo.GetHeight();

			// Pass 1 ->

			GaussianBlur.Use();

			bloomfbo_alt.BindMip(mip_num);

			GaussianBlur.SetInteger("u_Texture", 0);
			GaussianBlur.SetInteger("u_Lod", mip_num);
			GaussianBlur.SetBool("u_HQ", hq);
			GaussianBlur.SetBool("u_Direction", true);
			GaussianBlur.SetBool("u_Wide", KernelWideFlags[mip_num]);
			GaussianBlur.SetFloat("u_AspectRatioCorrect", AspectRatio);
			GaussianBlur.SetVector2f("u_Dimensions", glm::vec2(bloomfbo.GetWidth() * bloomfbo.m_MipScales[mip_num], bloomfbo.GetHeight() * bloomfbo.m_MipScales[mip_num]));

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, bright_tex);

			BloomFBOVAO->Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			BloomFBOVAO->Unbind();

			glUseProgram(0);

			// Pass 2 ->

			GaussianBlur.Use();

			bloomfbo.BindMip(mip_num);

			GaussianBlur.SetInteger("u_Texture", 0);
			GaussianBlur.SetInteger("u_Lod", mip_num);
			GaussianBlur.SetBool("u_HQ", hq);
			GaussianBlur.SetBool("u_Direction", false);
			GaussianBlur.SetBool("u_Wide", KernelWideFlags[mip_num]);
			GaussianBlur.SetFloat("u_AspectRatioCorrect", AspectRatio);

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, bloomfbo_alt.m_Mips[mip_num]);

			BloomFBOVAO->Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			BloomFBOVAO->Unbind();

			glUseProgram(0);
		}

		void RenderBloom(GLuint source_tex, GLuint emissivetex, BloomFBO& bloom_fbo, BloomFBO& bloom_fbo_alternate, GLuint& brighttex, bool wide)
		{
			GLClasses::Shader* BloomMaskShader = &(ShaderManager::GetShader("BLOOM_MASK"));

			// Render the bright parts to a texture
			GLClasses::Shader& BloomBrightShader = *BloomMaskShader;

			BloomAlternateFBO->SetSize(bloom_fbo.GetWidth() * floor(bloom_fbo.m_MipScales[0] * 2.0f), bloom_fbo.GetHeight() * floor(bloom_fbo.m_MipScales[0] * 2.0f));

			BloomBrightShader.Use();
			BloomAlternateFBO->Bind();
			BloomBrightShader.SetInteger("u_Texture", 0);
			BloomBrightShader.SetInteger("u_EmissiveData", 1);

			glActiveTexture(GL_TEXTURE0);
			glBindTexture(GL_TEXTURE_2D, source_tex);

			glActiveTexture(GL_TEXTURE1);
			glBindTexture(GL_TEXTURE_2D, emissivetex);

			BloomFBOVAO->Bind();
			glDrawArrays(GL_TRIANGLES, 0, 6);
			BloomFBOVAO->Unbind();

			glDisable(GL_DEPTH_TEST);
			glDisable(GL_CULL_FACE);

			brighttex = BloomAlternateFBO->GetTexture();

			// Generate mip maps for the mask texture 
			bool genmip = false;
			if (genmip) {
				glBindTexture(GL_TEXTURE_2D, BloomAlternateFBO->GetTexture(0));
				glGenerateMipmap(GL_TEXTURE_2D);
				glBindTexture(GL_TEXTURE_2D, 0);
			}

			// Blur the mips			
			bool hq = true;
			BlurBloomMip(bloom_fbo, bloom_fbo_alternate, 0, source_tex, BloomAlternateFBO->GetTexture(0), hq, wide);
			BlurBloomMip(bloom_fbo, bloom_fbo_alternate, 1, source_tex, bloom_fbo.m_Mips[0], hq, wide);
			BlurBloomMip(bloom_fbo, bloom_fbo_alternate, 2, source_tex, bloom_fbo.m_Mips[1], hq, wide);
			BlurBloomMip(bloom_fbo, bloom_fbo_alternate, 3, source_tex, bloom_fbo.m_Mips[2], hq, wide);
			BlurBloomMip(bloom_fbo, bloom_fbo_alternate, 4, source_tex, bloom_fbo.m_Mips[3], hq, wide);

			return;
		}

	}
}
