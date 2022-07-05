#pragma once

#include <iostream>
#include <memory>
#include <glad/glad.h>

#include "BloomFBO.h"
#include "GLClasses/Shader.h"
#include "GLClasses/Framebuffer.h"
#include "GLClasses/VertexBuffer.h"
#include "GLClasses/VertexArray.h"

namespace Lumen
{
	namespace BloomRenderer
	{
		void Initialize();
		void RenderBloom(GLuint source_tex, GLuint emissivetex, BloomFBO& bloom_fbo, BloomFBO& bloom_fbo_alternate, GLuint& brighttex, bool wide);
	}
}