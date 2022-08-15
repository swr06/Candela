#version 430 core 

layout(local_size_x = 8, local_size_y = 4, local_size_z = 8) in;

layout(rgba32ui, binding = 2) uniform uimage3D o_SHOutputA;
layout(rgba32ui, binding = 3) uniform uimage3D o_SHOutputB;

uniform usampler3D u_CurrentSHA;
uniform usampler3D u_CurrentSHB;

void main() {
	
	ivec3 Pixel = ivec3(gl_GlobalInvocationID.xyz);

	imageStore(o_SHOutputA, Pixel, texelFetch(u_CurrentSHA, Pixel, 0));
	imageStore(o_SHOutputB, Pixel, texelFetch(u_CurrentSHB, Pixel, 0));
}
