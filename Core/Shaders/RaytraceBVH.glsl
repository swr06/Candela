#version 430 core

layout(local_size_x = 16, local_size_y = 16) in;

layout(rgba16f, binding = 0) uniform image2D o_OutputData;

uniform vec3 u_ViewerPosition;
uniform vec3 u_LightDirection;
uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_LightVP;
uniform vec2 u_Dims;

const float INFINITY = 10000000.0f;
const float INF = INFINITY;
const float EPS = 0.001f;


struct FlattenedNode {
	vec4 Min;
	vec4 Max;
	uint StartIdx;
	uint TriangleCount;
	uint Axis;
	uint SecondChildIndex;
};

struct Triangle {
	vec4 Position[3];
};

layout (std430, binding = 1) buffer SSBO_BVHTriangles {
	Triangle BVHTriangles[];
};

layout (std430, binding = 2) buffer SSBO_BVHNodes {
	FlattenedNode BVHNodes[];
};

float max3(vec3 val) 
{
    return max(max(val.x, val.y), val.z);
}

float min3(vec3 val)
{
    return min(min(val.x, val.y), val.z);
}

// By Inigo Quilez
// Returns T, U, V
vec3 RayTriangle(in vec3 ro, in vec3 rd, in vec3 v0, in vec3 v1, in vec3 v2)
{
    vec3 v1v0 = v1 - v0;
    vec3 v2v0 = v2 - v0;
    vec3 rov0 = ro - v0;

    vec3  n = cross(v1v0, v2v0);
    vec3  q = cross(rov0, rd);
    float d = 1.0f / dot(rd, n);
    float u = d * dot(-q, v2v0);
    float v = d * dot( q, v1v0);
    float t = d * dot(-n, rov0);

    if(u < 0.0f || v < 0.0f || (u + v) > 1.0f) {
		t = -1.0;
	}

    return vec3(t, u, v);
}


float RayBounds(vec3 min_, vec3 max_, vec3 ray_origin, vec3 ray_inv_dir, float t_min, float t_max)
{
    vec3 aabb_min = min_;
    vec3 aabb_max = max_;
    vec3 t0 = (aabb_min - ray_origin) * ray_inv_dir;
    vec3 t1 = (aabb_max - ray_origin) * ray_inv_dir;
    float tmin = max(max3(min(t0, t1)), t_min);
    float tmax = min(min3(max(t0, t1)), t_max);
    return (tmax >= tmin) ? tmin : INFINITY;
}

vec3 DEBUG_COLOR = vec3(0.,1.,0.);

void RayTraceBVH(vec3 RayOrigin, vec3 RayDirection) {

	uint Stack[32];
	uint StackPointer = 0;
	uint CurrentNode = 0;

	vec3 InverseDirection = 1.0f / RayDirection;

	float TMax = INFINITY;
	vec3 IntersectionUVW = vec3(-1.0f);

	int Iterations = 0;

	while (Iterations < 128) {

		Iterations++;
		FlattenedNode Node = BVHNodes[CurrentNode];
		
		// Leaf node 
		if (Node.TriangleCount > 0) {
			
			// Intersect triangles 
			for (uint tri = 0 ; tri < Node.TriangleCount  ; tri++)  {
					
					uint triangle = tri + Node.StartIdx;
					vec3 Intersection = RayTriangle(RayOrigin, RayDirection, BVHTriangles[triangle].Position[0].xyz,  BVHTriangles[triangle].Position[1].xyz,  BVHTriangles[triangle].Position[2].xyz);

					if (Intersection.x > 0.0f && Intersection.x < TMax) {
						
						TMax = Intersection.x;
						IntersectionUVW = Intersection;

						// DEBUG
						DEBUG_COLOR = vec3(1.,0.,0.); return;
						// DEBUG 
					}
			}

			// Move stack pointer back, explore pushed nodes 
			if (StackPointer <= 0) {
				break;
			}

			CurrentNode = Stack[--StackPointer];
		}

		// Node index that will be traversed
		uint TraversalNode = CurrentNode + 1;
		uint OtherTraversalNode = Node.SecondChildIndex;

		// Intersect both child nodes 
		FlattenedNode LeftNode = BVHNodes[CurrentNode + 1];
		FlattenedNode RightNode = BVHNodes[Node.SecondChildIndex];

		float TransversalA = RayBounds(LeftNode.Min.xyz, LeftNode.Max.xyz, RayOrigin, InverseDirection, 0.000001f, TMax);
		float TransversalB = RayBounds(RightNode.Min.xyz, RightNode.Max.xyz, RayOrigin, InverseDirection, 0.000001f, TMax);

		// Check right node, if it's closer, traverse that first.
		if (TransversalB < TransversalA) {
			
			OtherTraversalNode = TraversalNode; // TraversalNode already has the index of the left node 
			TraversalNode = Node.SecondChildIndex;
			
			// Swap transversals 
			float Closest = TransversalA;
			TransversalA = TransversalB;
			TransversalB = Closest;
		}

		// No intersection with both nodes 
		if (TransversalA >= TMax) {

			// Move stack pointer, explore pushed nodes 
			if (StackPointer <= 0) {
				break;
			}

			CurrentNode = Stack[--StackPointer];
		}

		else {
			

			// Traverse the closest node next, push the other one on the stack if it was intersected 
			CurrentNode = TraversalNode;

			// If we intersected the other node, push it onto the stack

			if (TransversalB < (INFINITY - EPS)) {
				Stack[StackPointer++] = OtherTraversalNode;
			}

			if (StackPointer > 32) {

				// DEBUG
				DEBUG_COLOR = vec3(0.,0.,1.); return;
				// DEBUG 

			}
		}


	}


	return;
}

vec3 GetRayDirectionAt(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}



void main() {

	ivec2 Pixel = ivec2(gl_GlobalInvocationID.xy);
	vec2 TexCoords = vec2(Pixel) / u_Dims;

	vec3 rD = normalize(GetRayDirectionAt(TexCoords).xyz);
	vec3 rO = u_InverseView[3].xyz;

	float s = 1.0f;
	
	RayTraceBVH(rO, rD);
	
	vec3 o_Color = DEBUG_COLOR;
	imageStore(o_OutputData, Pixel, vec4(o_Color, 1.0f));
}