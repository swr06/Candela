#version 430 core 
#define PI 3.14159265354f

layout(local_size_x = 8, local_size_y = 4, local_size_z = 8) in;

uniform int u_Rays;
uniform int u_Frame;
uniform vec3 u_ProbeGridDimensions;

struct Ray {
	vec4 RayOrigin;
	vec4 RayDirection;
};

layout (std430, binding = 0) writeonly buffer OutputRays {
	Ray Rays[];
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

uint Get1DIdx(uvec3 index)
{
    ivec3 GridSize = ivec3(u_ProbeGridDimensions);
    return (index.z * GridSize.x * GridSize.y) + (index.y * GridSize.x) + GridSize.x;
}

// RNG ->
uint RNGSeed = 0u;

void HashRNG()
{
    RNGSeed ^= 2747636419u;
    RNGSeed *= 2654435769u;
    RNGSeed ^= RNGSeed >> 16;
    RNGSeed *= 2654435769u;
    RNGSeed ^= RNGSeed >> 16;
    RNGSeed *= 2654435769u;
}

void InitRNG(vec2 Pixel, vec3 Res)
{
    RNGSeed = uint(Pixel.y * Res.x + Pixel.x) + uint(u_Frame%512) * uint(Res.x) * uint(Res.y) * uint(Res.z) + uint(Res.z) * 4;
    HashRNG();
    HashRNG();
    HashRNG();
}

float Hash1()
{
    HashRNG();
    return float(RNGSeed) / 4294967295.0;
}

float Hash() { return Hash1(); }

vec2 Hash2()
{
   return vec2(Hash1(), Hash1());
}

vec3 Hash3()
{
   return vec3(Hash2(), Hash1());
}

vec3 GetSphereDirection(vec3 Random)
{
    float phi = 2.0 * PI * Random.x;
    float cosTheta = 2.0 * Random.y - 1.0;
    float u = Random.z;
    float theta = acos(cosTheta);
    float r = pow(u, 1.0 / 4.0);
    float x = r * sin(theta) * cos(phi);
    float y = r * sin(theta) * sin(phi);
    float z = r * cos(theta);
    return normalize(vec3(x, y, z));
}

void main() {

    ivec3 Invocation = ivec3(gl_GlobalInvocationID.xyz);
    InitRNG(vec2(Invocation.xy), vec3(8.,4.,8.));

    vec3 Position = vec3(Invocation) - (u_ProbeGridDimensions / 2.0f); 

    int Index1D = int(Get1DIdx(Invocation));
    float FloatBitsIndex = intBitsToFloat(Index1D);

    int WriteIndex = Index1D * int(u_Rays);

	for (int i = 0 ; i < u_Rays ; i++) {

        Ray WriteRay;

        vec3 SphereDirection = GetSphereDirection(Hash3());

        WriteRay.RayOrigin = vec4(Position, 1.0f);
        WriteRay.RayDirection = vec4(SphereDirection, FloatBitsIndex);

		Rays[WriteIndex + i] = WriteRay;
	}

}