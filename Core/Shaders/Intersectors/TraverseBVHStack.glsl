#version 450 core

#extension GL_ARB_bindless_texture : require


#extension GL_ARB_bindless_texture : enable



layout(local_size_x = 16, local_size_y = 16) in;

layout(rgba16f, binding = 0) uniform image2D o_OutputData;

layout(bindless_sampler) uniform sampler2D Textures[32];

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform mat4 u_Projection;
uniform mat4 u_View;

uniform vec2 u_Dims;

uniform int u_EntityCount; 

uniform int u_TotalNodes;

const float INFINITY = 1.0f / 0.0f;
const float INF = INFINITY;
const float EPS = 0.001f;

// 32 bytes 
struct Vertex {
	vec4 Position;
	uvec4 PackedData; // Packed normal, tangent and texcoords
};

// 16 bytes 
struct Triangle {
    int Packed[4]; // Contains packed data 
};

// W Component contains packed data
struct Bounds
{
    vec4 Min;
    vec4 Max;
};

struct Node
{
    Bounds LeftChildData;
    Bounds RightChildData;
};

struct BVHEntity {
	mat4 ModelMatrix; // 64
	mat4 InverseMatrix; // 64
	int NodeOffset;
	int NodeCount;
    int Padding[14];
};

struct TextureReferences {
	vec4 ModelColor;
	int Albedo;
	int Normal;
	int Pad[2];
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

layout (std430, binding = 3) buffer SSBO_Entities {
	BVHEntity BVHEntities[];
};

layout (std430, binding = 4) buffer SSBO_TextureReferences {
    TextureReferences BVHTextureReferences[];
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

float RayBounds(vec3 ro, in vec3 invdir, in Bounds box, in float maxt)
{
    const vec3 f = (box.Max.xyz - ro.xyz) * invdir;
    const vec3 n = (box.Min.xyz - ro.xyz) * invdir;
    const vec3 tmax = max(f, n);
    const vec3 tmin = min(f, n);
    const float t1 = min(min(tmax.x, min(tmax.y, tmax.z)), maxt);
    const float t0 = max(max(tmin.x, max(tmin.y, tmin.z)), 0.f);
    return (t1 >= t0) ? (t0 > 0.f ? t0 : t1) : -1.f;
}


// Gets ray direction from screenspace UV
vec3 GetRayDirectionAt(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
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


int GetStartIdx(in Bounds x) {
    return floatBitsToInt(x.Min.w);
}

bool IsLeaf(in Bounds x) {
    return floatBitsToInt(x.Min.w) != -1;
}

vec3 ComputeBarycentrics(vec3 p, vec3 a, vec3 b, vec3 c)
{
    float u, v, w;

	vec3 v0 = b - a, v1 = c - a, v2 = p - a;
	float d00 = dot(v0, v0);
	float d01 = dot(v0, v1);
	float d11 = dot(v1, v1);
	float d20 = dot(v2, v0);
	float d21 = dot(v2, v1);
	float denom = d00 * d11 - d01 * d01;
	v = (d11 * d20 - d01 * d21) / denom;
	w = (d00 * d21 - d01 * d20) / denom;
	u = 1.0f - v - w;

    return vec3(u,v,w);
}

vec4 IntersectBVHStack(vec3 RayOrigin, vec3 RayDirection, in const int NodeStartIndex, in const int NodeCount, in const mat4 InverseMatrix, float TMax, out int oMesh, out int oTriangleIndex) {

    const bool IntersectTriangles = true;

    RayOrigin = vec3(InverseMatrix * vec4(RayOrigin.xyz, 1.0f));
    RayDirection = vec3(InverseMatrix * vec4(RayDirection.xyz, 0.0f));
    
    float InverseLength = 1.0f / length(RayDirection);

    RayDirection *= InverseLength;

    // Work stack 
	int Stack[64];
	int StackPointer = 0;

    // Intersections 
    float ClosestTraversal = -1.0f;
    int IntersectMesh = -1;
    int IntersectTriangleIdx = -1;

    // Misc 
	int Iterations = 0;

    int CurrentNodeIndex = NodeStartIndex;

    bool LeftLeaf = false;
    bool RightLeaf = false;
    float LeftTraversal = 0.f;
    float RightTraversal = 0.f;

    int Postponed = 0;

	while (Iterations < 1024) {
            
        if (StackPointer >= 64 || StackPointer < 0 || CurrentNodeIndex < NodeStartIndex 
         || CurrentNodeIndex > NodeStartIndex+NodeCount || CurrentNodeIndex < 0 || CurrentNodeIndex > u_TotalNodes)
        {
            break;
        }

        Iterations++;

        const Node CurrentNode = BVHNodes[CurrentNodeIndex];

        bool LeftLeaf = IsLeaf(CurrentNode.LeftChildData);
        bool RightLeaf = IsLeaf(CurrentNode.RightChildData);

        // Avoid intersecting if leaf nodes (we'd need to traverse the pushed nodes anyway)
        LeftTraversal = LeftLeaf ? -1.0f : RayBounds(RayOrigin, InverseDirection, CurrentNode.LeftChildData, TMax);
        RightTraversal = RightLeaf ? -1.0f : RayBounds(RayOrigin, InverseDirection, CurrentNode.RightChildData, TMax);

        // Intersect triangles if leaf node
        
        // Left child 
        if (LeftLeaf && IntersectTriangles) {

            int Packed = GetStartIdx(CurrentNode.LeftChildData);
            int StartIdx = Packed >> 4;
                    
            int Length = Packed & 0xF;
                    
            for (int Idx = 0; Idx < Length ; Idx++) {
                Triangle triangle = BVHTris[Idx + StartIdx];
                
                const int Offset = 0;
                        
                vec3 VertexA = BVHVertices[triangle.Packed[0] + Offset].Position.xyz;
                vec3 VertexB = BVHVertices[triangle.Packed[1] + Offset].Position.xyz;
                vec3 VertexC = BVHVertices[triangle.Packed[2] + Offset].Position.xyz;
                
                vec3 Intersect = RayTriangle(RayOrigin, RayDirection, VertexA, VertexB, VertexC);
                        
                if (Intersect.x > 0.0f && Intersect.x < TMax)
                {
                    TMax = Intersect.x;
                    ClosestTraversal = Intersect.x;
                    IntersectMesh = triangle.Packed[3];
                    IntersectTriangleIdx = Idx + StartIdx;
                }
            }

        }

        // Right 
        if (RightLeaf && IntersectTriangles) {
             
            int Packed = GetStartIdx(CurrentNode.RightChildData);
            int StartIdx = Packed >> 4;
                    
            int Length = Packed & 0xF;
                    
            for (int Idx = 0; Idx < Length ; Idx++) {
                Triangle triangle = BVHTris[Idx + StartIdx];
                
                const int Offset = 0;
                        
                vec3 VertexA = BVHVertices[triangle.Packed[0] + Offset].Position.xyz;
                vec3 VertexB = BVHVertices[triangle.Packed[1] + Offset].Position.xyz;
                vec3 VertexC = BVHVertices[triangle.Packed[2] + Offset].Position.xyz;
                
                vec3 Intersect = RayTriangle(RayOrigin, RayDirection, VertexA, VertexB, VertexC);
                        
                if (Intersect.x > 0.0f && Intersect.x < TMax)
                {
                    TMax = Intersect.x;
                    ClosestTraversal = Intersect.x;
                    IntersectMesh = triangle.Packed[3];
                    IntersectTriangleIdx = Idx + StartIdx;
                }
            }
        }

        // If we intersected both nodes we traverse the closer one first
        if (LeftTraversal > 0.0f && RightTraversal > 0.0f) {

            CurrentNodeIndex = floatBitsToInt(CurrentNode.LeftChildData.Max.w) + NodeStartIndex;
            Postponed = floatBitsToInt(CurrentNode.RightChildData.Max.w) + NodeStartIndex;

            // Was the right node closer? if so then swap.
            if (RightTraversal < LeftTraversal)
            {
                int Temp = CurrentNodeIndex;
                CurrentNodeIndex = Postponed;
                Postponed = Temp;
            }

            if (StackPointer >= 63) {
                break;
            }

            Stack[StackPointer++] = Postponed;
            continue;
        }

        else if (LeftTraversal > 0.0f) {
            CurrentNodeIndex = floatBitsToInt(CurrentNode.LeftChildData.Max.w) + NodeStartIndex;
            continue;
        }

         else if (RightTraversal > 0.0f) {
            CurrentNodeIndex = floatBitsToInt(CurrentNode.RightChildData.Max.w) + NodeStartIndex;
            continue;
        }

        // Explore pushed nodes 
        if (StackPointer <= 0) {
            break;
        }

        CurrentNodeIndex = Stack[--StackPointer];
	}

    oMesh = IntersectMesh;
    oTriangleIndex = IntersectTriangleIdx;

    if (ClosestTraversal > 0.0f && IntersectTriangleIdx > 0) {

         Triangle triangle = BVHTris[IntersectTriangleIdx];
         
         const vec3 VertexA = BVHVertices[triangle.Packed[0]].Position.xyz;
         const vec3 VertexB = BVHVertices[triangle.Packed[1]].Position.xyz;
         const vec3 VertexC = BVHVertices[triangle.Packed[2]].Position.xyz;

         return vec4(ClosestTraversal * InverseLength, ComputeBarycentrics(RayOrigin + RayDirection * ClosestTraversal, VertexA, VertexB, VertexC));
    }

    return vec4(vec3(-1.), -1.);
}

vec4 IntersectScene(vec3 RayOrigin, vec3 RayDirection, out int Mesh, out int TriangleIdx) {

    vec4 FinalIntersect = vec4(vec3(-1.0f), intBitsToFloat(-1));

    float TMax = 1000000.0f;

    int Mesh_ = -1;
    int Tri_ = -1;

    for (int i = 0 ; i < u_EntityCount ; i++)
    {
        vec4 Intersect = IntersectBVHStack(RayOrigin, RayDirection, BVHEntities[i].NodeOffset, BVHEntities[i].NodeCount, BVHEntities[i].InverseMatrix, TMax, Mesh_, Tri_);

        if (Intersect.x > 0.0f && Intersect.x < TMax) {
            TMax = Intersect.x;
            FinalIntersect = Intersect;
            Mesh = Mesh_;
            TriangleIdx = Tri_;
        }

    }

    return FinalIntersect;
}

vec3 UnpackNormal(in const uvec2 Packed) {
    
    return vec3(unpackHalf2x16(Packed.x).xy, unpackHalf2x16(Packed.y).x);
}

vec3 GetAlbedo(in const vec4 TUVW, in const int Mesh, in const int TriangleIndex) {

    Triangle triangle = BVHTris[TriangleIndex];

    Vertex A = BVHVertices[triangle.Packed[0]];
    Vertex B = BVHVertices[triangle.Packed[1]];
    Vertex C = BVHVertices[triangle.Packed[2]];

    vec2 UV = (unpackHalf2x16(A.PackedData.w) * TUVW.y) + (unpackHalf2x16(B.PackedData.w) * TUVW.z) + (unpackHalf2x16(C.PackedData.w) * TUVW.w);
    vec3 MeshNormal = normalize((UnpackNormal(A.PackedData.xy) * TUVW.y) + (UnpackNormal(B.PackedData.xy) * TUVW.z) + (UnpackNormal(C.PackedData.xy) * TUVW.w));

    int Ref = BVHTextureReferences[Mesh].Albedo;

    if (Ref > -1 && Mesh > -1 && TUVW.x > 0.) {
        return texture(Textures[Ref], UV.xy).xyz; 
    }

    return vec3(0.0f);
}

void main() {

	ivec2 Pixel = ivec2(gl_GlobalInvocationID.xy);
	vec2 TexCoords = vec2(Pixel) / u_Dims;

	vec3 rD = normalize(GetRayDirectionAt(TexCoords).xyz);
	vec3 rO = u_InverseView[3].xyz;

	float s = 1.0f;

    int IntersectedMesh = -1;
    int TriIdx = -1;
	
	vec4 TUVW = IntersectScene(rO, rD, IntersectedMesh, TriIdx);
    
    vec3 o_Color = GetAlbedo(TUVW, IntersectedMesh, TriIdx);

	imageStore(o_OutputData, Pixel, vec4(o_Color, 1.0f));
}