#version 430 core

#define InvalidIdx 0xffffffffu

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

uniform int u_Counter;

uniform int u_NodeCount;

const float INFINITY = 1.0f / 0.0f;
const float INF = INFINITY;
const float EPS = 0.001f;

vec3 DEBUG_COLOR = vec3(0.,1.,0.);

// 32 bytes 
struct Vertex
{
	vec4 Position;
	uvec4 PackedData;
};

// 16 bytes 
struct Triangle {
    ivec4 Packed;
};

// 32 bytes 
// W Component has packed data 
struct Node {
    vec4 Min; // W component contains packed links
    vec4 Max; // W component contains packed leaf data 
};

// SSBOs
layout (std430, binding = 0) buffer SSBO_BVHVertices {
	Vertex BVHVertices[];
};

layout (std430, binding = 1) buffer SSBO_BVHTris {
	Triangle BVHTris[];
};

layout (std430, binding = 2) buffer SSBO_BVHNodes {
	Node BVHNodes[];
};

float max3(vec3 val) 
{
    return max(max(val.x, val.y), val.z);
}

float min3(vec3 val)
{
    return min(val.x, min(val.y, val.z));
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

// Returns transversals 
float RayBounds(vec3 min_, vec3 max_, vec3 ray_origin, vec3 ray_inv_dir, float t_min, float t_max)
{
    vec3 aabb_min = min_;
    vec3 aabb_max = max_;
    vec3 t0 = (aabb_min - ray_origin) * ray_inv_dir;
    vec3 t1 = (aabb_max - ray_origin) * ray_inv_dir;
    float tmin = max(max3(min(t0, t1)), t_min);
    float tmax = min(min3(max(t0, t1)), t_max);
    return (tmax >= tmin) ? tmin : -1.;
}


// Gets ray direction from screenspace UV
vec3 GetRayDirectionAt(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}

bool IsLeafNode(in Node node) {
    return node.Min.w != -1.0f;
}

int GetStartIdx(in Node node) {
    return int(node.Min.w) >> 4;
}

bool IntersectTriangleP(vec3 r0, vec3 rD, in vec3 v1, in vec3 v2, in vec3 v3, float TMax)
{
    const vec3 e1 = v2 - v1;
    const vec3 e2 = v3 - v1;
    const vec3 s1 = cross(rD.xyz, e2);
    const float  invd = 1.0f/(dot(s1, e1));
    const vec3 d = r0.xyz - v1;
    const float  b1 = dot(d, s1) * invd;
    const vec3 s2 = cross(d, e1);
    const float  b2 = dot(rD.xyz, s2) * invd;
    const float temp = dot(e2, s2) * invd;

    if (b1 < 0.f || b1 > 1.f || b2 < 0.f || b1 + b2 > 1.f || temp < 0.f || temp > TMax)
    {
        return false;
    }

    else
    {
        return true;
    }
}

vec3 IntersectBVH(vec3 RayOrigin, vec3 RayDirection) {

    vec3 InverseDirection = 1.0f / RayDirection;

    int Iterations = 0;

    int Pointer = 0;

    float TMax = 100000.0f;

    vec3 ClosestIntersect = vec3(-1.0f);

    while (Pointer >= 0 && Iterations < 512 && Pointer < u_NodeCount) {

        Iterations++;

        Node CurrentNode = BVHNodes[Pointer];

        float BoxTraversal = RayBounds(CurrentNode.Min.xyz, CurrentNode.Max.xyz, RayOrigin, InverseDirection, 0.001f, TMax);

        if (BoxTraversal > 0.0f && BoxTraversal < TMax) {

            if (IsLeafNode(CurrentNode)) {

                //if (BoxTraversal > 0.0f && BoxTraversal < TMax)
                //{
                //    TMax = BoxTraversal;
                //    ClosestIntersect = vec3(BoxTraversal);
                //}
                
                int Packed = int(CurrentNode.Min.w);
                
                int Idx = Packed;
                
                //int Size = Packed & 0xF;
                
                for (int Reference = Idx ; Reference < Idx + 1 ; Reference++) 
                {
                    Triangle triangle = BVHTris[Reference];
                
                    vec3 VertexA = BVHVertices[triangle.Packed[0]].Position.xyz;
                    vec3 VertexB = BVHVertices[triangle.Packed[1]].Position.xyz;
                    vec3 VertexC = BVHVertices[triangle.Packed[2]].Position.xyz;
                    vec3 Intersect = RayTriangle(RayOrigin, RayDirection, VertexA, VertexB, VertexC);
                
                    if (Intersect.x > 0.0f && Intersect.x < TMax)
                    {
                        TMax = Intersect.x;
                        ClosestIntersect = Intersect;
                    }
                
                }

                Pointer = int(CurrentNode.Max.w);
                continue;
            }

            else {

                Pointer++;
                continue;
            }

        }

        else {

             Pointer = int(CurrentNode.Max.w);
             continue;
        }

        if (Pointer < 0) {
            break;
        }
    }

    return vec3(Iterations / 1000.0f);

    if (ClosestIntersect.x > 0.0f) {
        return vec3(ClosestIntersect.x) / 8.0f;
    }

    return vec3(1.0f, 0.0f, 0.0f);
}

vec3 BruteForceTris(vec3 rO, vec3 rD) {
    
    float TMax = 100000.0f;

    vec3 FIntersect = vec3(-1.);

    for (int x = 0 ; x < 2188; x++) {
        Triangle triangle = BVHTris[x];
        vec3 VertexA = BVHVertices[triangle.Packed[0]].Position.xyz;
        vec3 VertexB = BVHVertices[triangle.Packed[1]].Position.xyz;
        vec3 VertexC = BVHVertices[triangle.Packed[2]].Position.xyz;
        vec3 Intersect = RayTriangle(rO, rD, VertexA, VertexB, VertexC);
        
        if (Intersect.x > 0. && Intersect.x < TMax) {
            TMax = Intersect.x;
            FIntersect = Intersect;
        }
    }

    if (FIntersect.x > 0.0f) {
        return vec3(FIntersect.x) / 8.0f;
    }

    return vec3(1.0f, 0.0f, 0.0f);
}

void main() {

	ivec2 Pixel = ivec2(gl_GlobalInvocationID.xy);
	vec2 TexCoords = vec2(Pixel) / u_Dims;

	vec3 rD = normalize(GetRayDirectionAt(TexCoords).xyz);
	vec3 rO = u_InverseView[3].xyz;

	float s = 1.0f;
	
	vec3 o_Color = IntersectBVH(rO, rD);
	//vec3 o_Color = BruteForceTris(rO, rD);

	//vec3 o_Color = vec3(0.,0.,1.);
    //
    //if (true) {
	//
    //    Node CurrentNode = BVHNodes[u_Counter];
    //    float BoxTraversal = RayBounds(CurrentNode.Min.xyz, CurrentNode.Max.xyz, rO, 1./rD, 0.001f, 10000.0f);
    //
    //
    //    if (BoxTraversal > 0.) {
    //
    //        if (IsLeafNode(CurrentNode)) {
    //            
    //             int Reference = GetStartIdx(CurrentNode);
    //
    //            Triangle triangle = BVHTris[Reference];
    //
    //            vec3 VertexA = BVHVertices[triangle.Packed[0]].Position.xyz;
    //            vec3 VertexB = BVHVertices[triangle.Packed[1]].Position.xyz;
    //            vec3 VertexC = BVHVertices[triangle.Packed[2]].Position.xyz;
    //            vec3 Intersect = RayTriangle(rO, rD, VertexA, VertexB, VertexC);
    //           
    //            if (Intersect.x > 0.0f)
    //            {
    //                o_Color = vec3(1.,0.,0.);
    //            }
    //
    //            else {
    //
    //                o_Color = vec3(0.,1.,0.);
    //            }
    //
    //        }
    //
    //        else {
    //
    //            o_Color = vec3(1.,1.,1.);
    //        }
    //    }
    //} else {
    //
    //    Triangle triangle = BVHTris[u_Counter];
    //    vec3 VertexA = BVHVertices[triangle.Packed[0]].Position.xyz;
    //    vec3 VertexB = BVHVertices[triangle.Packed[1]].Position.xyz;
    //    vec3 VertexC = BVHVertices[triangle.Packed[2]].Position.xyz;
    //    vec3 Intersect = RayTriangle(rO, rD, VertexA, VertexB, VertexC);
    //    
    //    if (Intersect.x > 0.) {
    //        o_Color = vec3(1.,0.,0.);
    //    }
    //}

	imageStore(o_OutputData, Pixel, vec4(o_Color, 1.0f));
}