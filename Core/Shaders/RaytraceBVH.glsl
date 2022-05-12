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

const float INFINITY = 1.0f / 0.0f;
const float INF = INFINITY;
const float EPS = 0.001f;


vec3 DEBUG_COLOR = vec3(0.,1.,0.);

struct Node
{
    vec3 aabb_left_min_or_v0;
    uint addr_left;
    vec3 aabb_left_max_or_v1;
    uint mesh_id;
    vec3 aabb_right_min_or_v2;
    uint addr_right;
    vec3 aabb_right_max;
    uint prim_id;
};

struct Vertex
{
	vec4 position; // 16 bytes
	uvec4 normal_tangent_texcoords_data; // 16 bytes
};

layout (std430, binding = 1) buffer SSBO_BVHVertices {
	Vertex Vertices[];
};

layout (std430, binding = 2) buffer SSBO_BVHNodes {
	Node BVHNodes[];
};

float max3(vec3 val) 
{
    return max(max(val.x, val.y), val.z);
}

float min3(float a, float b, float c)
{
    return min(c, min(a, b));
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


vec2 fast_intersect_aabb(
    vec3 pmin, vec3 pmax,
    vec3 invdir, vec3 oxinvdir,
    float t_max)
{
    vec3 f = fma(pmax, invdir, oxinvdir);
    vec3 n = fma(pmin, invdir, oxinvdir);
    vec3 tmax = max(f, n);
    vec3 tmin = min(f, n);
    float t1 = min(min3(tmax.x, tmax.y, tmax.z), t_max);
    float t0 = max(min3(tmin.x, tmin.y, tmin.z), 0.0);
    return vec2(t0, t1);
}


bool IsInternalNode(in Node node) {
    return node.addr_left != InvalidIdx;
}

bool IsLeaf(in Node node) {
    return !IsInternalNode(node);
}

vec3 IntersectBVH(vec3 RayOrigin, vec3 RayDirection) {

    vec3 InverseDirection = 1.0f / RayDirection;
    vec3 RayOriginD = -RayOrigin * InverseDirection;

    uint Stack[64];
    uint CurrentNodePointer = 0;
    int StackPointer = 0;

    vec3 IntersectionUVW = vec3(-1.0f);
    float TMax = 100000.0f;
    float TMin = 10000.0f;

    int Iterations = 0;

    while (Iterations < 128 && CurrentNodePointer != InvalidIdx) {
        
        Iterations++;

        Node CurrentNode = BVHNodes[CurrentNodePointer];

        if (IsLeaf(CurrentNode)) {

             vec2 s0 = fast_intersect_aabb(
                CurrentNode.aabb_left_min_or_v0,
                CurrentNode.aabb_left_max_or_v1,
                InverseDirection, RayOriginD, TMin);
            
            vec2 s1 = fast_intersect_aabb(
                CurrentNode.aabb_right_min_or_v2,
                CurrentNode.aabb_right_max,
                InverseDirection, RayOriginD, TMin);

            bool traverse_c0 = (s0.x <= s0.y);
            bool traverse_c1 = (s1.x <= s1.y);
            bool c1first = traverse_c1 && (s0.x > s1.x);

            if (traverse_c0 || traverse_c1)
            {
                uint deferred = InvalidIdx;

                if (c1first || !traverse_c0)
                {
                    CurrentNodePointer = CurrentNode.addr_right;
                    deferred = CurrentNode.addr_left;
                }
                else
                {
                    CurrentNodePointer = CurrentNode.addr_left;
                    deferred = CurrentNode.addr_right;
                }

                if (traverse_c0 && traverse_c1)
                {
                    Stack[StackPointer++] = deferred;
                }

                continue;

            }
        }

        else {
            
            vec3 v1 = Vertices[node.i0].xyz;
            vec3 v2 = Vertices[node.i1].xyz;
            vec3 v3 = Vertices[node.i2].xyz;
            float const f = fast_intersect_triangle(r, v1, v2, v3, t_max);
            // If hit update closest hit distance and index
            if (f < t_max)
            {
                t_max = f;
                isect_idx = addr;
            }

        }
    }

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
	
	//RayTraceBVH(rO, rD);
	
	vec3 o_Color = vec3(1.,0.,0.);
	imageStore(o_OutputData, Pixel, vec4(o_Color, 1.0f));
}