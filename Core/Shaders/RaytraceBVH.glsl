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

// 32 bytes 
struct Vertex
{
	vec4 Position;
	uvec4 PackedData;
};

// 16 bytes 
struct Triangle {
    int Packed[4];
};

// 32 bytes 
// W Component has packed data 
struct Node {
    vec4 Min; // W component contains packed links
    vec4 Max; // W component contains packed leaf data 
};

// SSBOs
layout (std430, binding = 0) buffer SSBO_BVHVertices {
	Vertex Vertices[];
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
    return int(node.Min.w);
}

vec3 IntersectBVH(vec3 RayOrigin, vec3 RayDirection) {

    vec3 InverseDirection = 1.0f / RayDirection;

    int Iterations = 0;

    int Pointer = 0;

    float TMax = 100000.0f;

    while (Pointer >= 0 && Iterations < 64) {

        Iterations++;

        Node CurrentNode = BVHNodes[Pointer];

        float BoxTraversal = RayBounds(CurrentNode.Min.xyz, CurrentNode.Max.xyz, RayOrigin, InverseDirection, 0.001f, TMax);

        if (BoxTraversal > 0.0f) {

           // TMax = BoxTraversal;
            
            if (IsLeafNode(CurrentNode)) {
                return vec3(1.,0.,0.);
            }

            else {

                Pointer++;
            }

        }

        else {

            Pointer = int(CurrentNode.Max.w);
            
        }
    }

    return vec3(0., 1., 0.);

}


void main() {

	ivec2 Pixel = ivec2(gl_GlobalInvocationID.xy);
	vec2 TexCoords = vec2(Pixel) / u_Dims;

	vec3 rD = normalize(GetRayDirectionAt(TexCoords).xyz);
	vec3 rO = u_InverseView[3].xyz;

	float s = 1.0f;
	
	//RayTraceBVH(rO, rD);
	

	//vec3 o_Color = vec3(1.,0.,0.);
    vec3 o_Color =  IntersectBVH(rO, rD);

	imageStore(o_OutputData, Pixel, vec4(o_Color, 1.0f));
}