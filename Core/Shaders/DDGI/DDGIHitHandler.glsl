#version 430 core 

layout (location = 0) out vec4 o_Radiance;

uniform int u_RayCount;
uniform vec3 u_ProbeGridDimensions;
uniform vec2 u_ProbeGridDimensionsFactors;

layout (std430, binding = 1) readonly buffer ProbeData {
	vec4 Pixels[];
};

ivec3 Get3DIdx(int idx)
{
    ivec3 GridSize = ivec3(u_ProbeGridDimensions);
	int z = idx / (GridSize.x * GridSize.y);
	idx -= (z * GridSize.x * GridSize.y);
	int y = idx / GridSize.x;
	int x = idx % GridSize.x;
	return ivec3(x, y, z);
}

int Get1DIdx(ivec3 index)
{
    ivec3 GridSize = ivec3(u_ProbeGridDimensions);
    return (index.z * GridSize.x * GridSize.y) + (index.y * GridSize.x) + GridSize.x;
}

int Get1DIdx(ivec2 index, ivec2 plane)
{
	return index.x * plane.x + index.y;
}

void main() {

	ivec2 Pixel = ivec2(gl_FragCoord.xy);
	ivec2 ProbeResolution = ivec2(8, 4);

	ivec2 LocalPixel = Pixel % ProbeResolution;
	ivec2 ProbeIndex = Pixel / ProbeResolution;
	int IndexLocal1D = Get1DIdx(LocalPixel, ProbeResolution);
	int ProbeIndex1D = Get1DIdx(ProbeIndex, ivec2(u_ProbeGridDimensionsFactors));
	ivec3 ProbeIndex3D = Get3DIdx(ProbeIndex1D);
	int ProbePixelOffset = ProbeIndex1D * ProbeResolution.x * ProbeResolution.y;
	int ProbePixel = ProbePixelOffset + IndexLocal1D;

	vec4 ProbeRadiance = Pixels[ProbePixel];
	o_Radiance = ProbeRadiance;
}
