#version 430 core
#define PI 3.14159265359

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_AlbedoTexture;
uniform sampler2D u_NormalTexture;
uniform sampler2D u_PBRTexture;
uniform sampler2D u_DepthTexture;
uniform sampler2D u_ShadowTexture;
uniform sampler2D u_BlueNoise;
uniform samplerCube u_Skymap;

uniform vec3 u_ViewerPosition;
uniform vec3 u_LightDirection;
uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;
uniform mat4 u_LightVP;
uniform vec2 u_Dims;

uniform bool u_Mode;
uniform int u_x;



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
    return (tmax >= tmin) ? tmin : -1.0f;
}



vec3 RayTraceBVH(vec3 RayOrigin, vec3 RayDirection) {

	int Stack[64];
	uint StackPointer = 0;
	uint CurrentNode = 0;

	vec3 InverseDirection = 1.0f / RayDirection;
	bvec3 InverseRaySign = bvec3(RayDirection.x < 0.0f, RayDirection.y < 0.0f, RayDirection.z < 0.0f);

	float TMax = 1000000.0f;
	vec3 IntersectionUVW = vec3(-1.0f);

	for (int ITERATION = 0 ; ITERATION < 10000 ; ITERATION++) {

		FlattenedNode Node = BVHNodes[CurrentNode];

		float BoxIntersect = RayBounds(Node.Min.xyz, Node.Max.xyz, RayOrigin, InverseDirection, 0.001f, 1000000.0f);
		if (BoxIntersect < TMax && BoxIntersect > 0.0f) {

			if (Node.TriangleCount > 0) {

				// Leaf node 
				for (uint tri = 0 ; tri < Node.TriangleCount  ; tri++)  {
					
					uint triangle = tri + Node.StartIdx;
					vec3 Intersection = RayTriangle(RayOrigin, RayDirection, BVHTriangles[triangle].Position[0].xyz,  BVHTriangles[triangle].Position[1].xyz,  BVHTriangles[triangle].Position[2].xyz);

					if (Intersection.x > 0.0f && Intersection.x < TMax) {
						
						TMax = Intersection.x;
						IntersectionUVW = Intersection;
					}

				}

				if (StackPointer == 0) {
					break; 
				}

				StackPointer--;
                CurrentNode = Stack[StackPointer];

			}

			else {

				if (InverseRaySign[Node.Axis]) 
				{
				   Stack[StackPointer++] = int(CurrentNode + 1);
				   CurrentNode = Node.SecondChildIndex;
				} 
				
				else 
				{
				   Stack[StackPointer++] = int(Node.SecondChildIndex);
				   CurrentNode++;
				}
			}

		}

		else {
			
			
			if (StackPointer <= 0) {
				break;
			}

			StackPointer--;
			CurrentNode = Stack[StackPointer];
			
		}

	}

	return IntersectionUVW;
}

float HASH2SEED = 0.0f;
vec2 hash2() 
{
    return fract(sin(vec2(HASH2SEED += 0.1, HASH2SEED += 0.1)) * vec2(43758.5453123, 22578.1459123));
}

vec3 RayTraceTrianglesLinear(vec3 RayOrigin, vec3 RayDirection, uint StartIdx, uint Triangles) {

	vec3 IntersectionTUV = vec3(-1., -1., -1.);

	float TMax = 100000.0f;

	float s = 1.0f;

	for (uint i = 0 ; i < Triangles ; i++) {

		uint triangle = uint(StartIdx + i);
		vec3 Intersection = RayTriangle(RayOrigin, RayDirection, BVHTriangles[triangle].Position[0].xyz * s,  BVHTriangles[triangle].Position[1].xyz* s,  BVHTriangles[triangle].Position[2].xyz* s);

		if (Intersection.x > 0.0f && Intersection.x < TMax) {
			TMax = Intersection.x;
			IntersectionTUV = Intersection;
		}
	}

	return IntersectionTUV;
}

vec3 DebugBVHTris(vec3 RayOrigin, vec3 RayDirection, uint Size) {

	vec3 IntersectionTUV = vec3(-1., -1., -1.);

	float TMax = 100000.0f;

	float s = 1.0f;

	for (uint i = 0 ; i < Size ; i++) {

		FlattenedNode Node = BVHNodes[i];

		if (Node.TriangleCount > 0) {
			
			for (uint j = 0; j < Node.TriangleCount ; j++) {
				uint triangle = Node.StartIdx + j;
				vec3 Intersection = RayTriangle(RayOrigin, RayDirection, BVHTriangles[triangle].Position[0].xyz * s,  BVHTriangles[triangle].Position[1].xyz* s,  BVHTriangles[triangle].Position[2].xyz* s);

				if (Intersection.x > 0.0f && Intersection.x < TMax) {
					TMax = Intersection.x;
					IntersectionTUV = Intersection;
				}
			}
		}
	}

	return IntersectionTUV;
}

vec3 WorldPosFromDepth(float depth, vec2 txc)
{
    float z = depth * 2.0 - 1.0;
    vec4 ClipSpacePosition = vec4(txc * 2.0 - 1.0, z, 1.0);
    vec4 ViewSpacePosition = u_InverseProjection * ClipSpacePosition;
    ViewSpacePosition /= ViewSpacePosition.w;
    vec4 WorldPos = u_InverseView * ViewSpacePosition;
    return WorldPos.xyz;
}

vec3 GetRayDirectionAt(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}

void main() 
{	
	HASH2SEED = (v_TexCoords.x * v_TexCoords.y) * 64.0;

	vec3 rD = normalize(GetRayDirectionAt(v_TexCoords).xyz);
	vec3 rO = u_InverseView[3].xyz;

	float s = 1.0f;
	
	vec3 Intersection = RayTraceBVH(rO, rD);
	
	if (Intersection.x > 0.0f) {
		o_Color = vec3(Intersection.x / 23.0f);
	}
	
	else {
		o_Color = vec3(0.0f, 1.0f, 0.0f);
	}


	

	//FlattenedNode Node = BVHNodes[BVHNodes[u_x].SecondChildIndex];
	//FlattenedNode Node = BVHNodes[u_x];
	//
	//if (Node.TriangleCount > 0) {
	//	if (Node.SecondChildIndex > 0 || Node.TriangleCount < 1) {
	//		o_Color = vec3(0.,0.,1.); 
	//		return;
	//	}
	//
	//	vec3 I = RayTraceTrianglesLinear(rO, rD, Node.StartIdx, Node.TriangleCount);
	//
	//	if (I.x > 0.0f) {
	//		o_Color = vec3(1.,1.,0.);
	//	}
	//
	//	else {
	//		o_Color = vec3(0.,1.,0.);
	//	}	
	//
	//	return;
	//}
	//
	//else {
	//
	//	if (RayBounds(Node.Min.xyz, Node.Max.xyz, rO, 1./rD, 0.001f, 10000.0f) > 0.0f) {
	//		o_Color = vec3(1.,0.,0.);
	//	}
	//
	//	else {
	//		o_Color = vec3(0.,1.,0.);
	//	}
	//}
	
	

   //
	//vec3 Intersection = RayTraceTrianglesLinear(rO, rD, 0, 2188);
	//if (Intersection.x > 0.0f) {
	//	o_Color = vec3(Intersection.x / 25.0f);
	//}
	//
	//else {
	//	o_Color = vec3(0.0f, 1.0f, 0.0f);
	//}
   //


	//vec3 Intersection = DebugBVHTris(rO, rD, 4900);
	//if (Intersection.x > 0.0f) {
	//	o_Color = vec3(Intersection.x / 10.0f);
	//}
	//
	//else {
	//	o_Color = vec3(0.0f, 1.0f, 0.0f);
	//}
}