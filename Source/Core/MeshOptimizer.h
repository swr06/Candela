#pragma once

#include <glm/glm.hpp>
#include <iostream>
#include <array>
#include "Mesh.h"
#include "Object.h"

namespace Candela {

	void SoftwareUpsample(char* pixels, uint8_t type, int w, int h, int nw, int nh);
	void PartialOptimize(Object& object);
}