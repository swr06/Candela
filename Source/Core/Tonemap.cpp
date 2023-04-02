#include "Tonemap.h"

void Candela::Tonemapper::Initialize(std::string Path, GLuint& DataTexture)
{
	// for tony mcmapface tonemapper 

    std::ifstream file(Path, std::ios::binary); 

    if (!file.is_open() || !file.good()) {
        throw "Couldn't open tonemapping lut";
    }

    file.seekg(148, std::ios::beg);

    char* Bytes = new char[1769472];
    file.read(Bytes, 1769472);

	DataTexture = 0;

	glGenTextures(1, &DataTexture);
	glBindTexture(GL_TEXTURE_3D, DataTexture);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_3D, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
	glTexImage3D(GL_TEXTURE_3D, 0, GL_RGBA32F, 48, 48, 48, 0, GL_RGBA, GL_FLOAT, (void*)Bytes);
}
