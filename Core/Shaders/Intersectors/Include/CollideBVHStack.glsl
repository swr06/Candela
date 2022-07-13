#define SSBO_BINDING_STARTINDEX 16

#extension GL_ARB_bindless_texture : require
#extension GL_ARB_bindless_texture : enable

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
    int PackedData[4]; // Contains packed data 
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
    int Data[14];
};

struct C_AABB {
    vec3 Min;
    vec3 Max;
};

// SSBOs
layout (std430, binding = (SSBO_BINDING_STARTINDEX + 0)) buffer SSBO_BVHVertices {
	Vertex BVHVertices[];
};

layout (std430, binding = (SSBO_BINDING_STARTINDEX + 1)) buffer SSBO_BVHTris {
	Triangle BVHTris[];
};

layout (std430, binding = (SSBO_BINDING_STARTINDEX + 2)) buffer SSBO_BVHNodes {
	Node BVHNodes[];
};

layout (std430, binding = (SSBO_BINDING_STARTINDEX + 3)) buffer SSBO_Entities {
	BVHEntity BVHEntities[];
};

float max3(vec3 val) 
{
    return max(max(val.x, val.y), val.z);
}

float min3(vec3 val)
{
    return min(val.x, min(val.y, val.z));
}

int GetStartIdx(in Bounds x) {
    return floatBitsToInt(x.Min.w);
}

bool IsLeaf(in Bounds x) {
    return floatBitsToInt(x.Min.w) != -1;
}

float DistanceSqr(vec3 x, vec3 y) {
    vec3 d = y - x;
    return dot(d, d);
}

bool AABBAABBOverlap(C_AABB a, C_AABB b) 
{
    return ((a.Min.x <= b.Max.x && a.Max.x >= b.Min.x) && (a.Min.y <= b.Max.y && a.Max.y >= b.Min.y) && 
           (a.Min.z <= b.Max.z && a.Max.z >= b.Min.z));
}

float AABBAABBOverlapF(C_AABB a, C_AABB b) 
{
    bool Intersected = ((a.Min.x <= b.Max.x && a.Max.x >= b.Min.x) && (a.Min.y <= b.Max.y && a.Max.y >= b.Min.y) && 
           (a.Min.z <= b.Max.z && a.Max.z >= b.Min.z));
    float Distance = DistanceSqr((a.Min.xyz + a.Max.xyz) / 2.0f, (b.Min.xyz + b.Max.xyz) / 2.0f);
    return Intersected ? Distance : -1.0f;
}

bool BoxTriangleOverlap(vec3 v0, vec3 v1, vec3 v2, C_AABB aabb) {
    vec3 c = (aabb.Min + aabb.Max) / 2.0f;
    vec3 e = aabb.Max - aabb.Min;

    v0 -= c;
    v1 -= c;
    v2 -= c;

    vec3 f0 = v1 - v0; // B - A
    vec3 f1 = v2 - v1; // C - B
    vec3 f2 = v0 - v2; // A - C

    vec3 u0 = vec3(1.0f, 0.0f, 0.0f);
    vec3 u1 = vec3(0.0f, 1.0f, 0.0f);
    vec3 u2 = vec3(0.0f, 0.0f, 1.0f);

    vec3 AxisUxFx[9];

    AxisUxFx[0] = cross(u0, f0);
    AxisUxFx[1] = cross(u0, f1);
    AxisUxFx[2] = cross(u0, f2);
    AxisUxFx[3] = cross(u1, f0);
    AxisUxFx[4] = cross(u1, f1);
    AxisUxFx[5] = cross(u2, f2);
    AxisUxFx[6] = cross(u2, f0);
    AxisUxFx[7] = cross(u2, f1);
    AxisUxFx[8] = cross(u2, f2);

    for (int i = 0; i < 9; i++) {

        vec3 axis = AxisUxFx[i];
        float p0 = dot(v0, axis);
        float p1 = dot(v1, axis);
        float p2 = dot(v2, axis);

        float r = e.x * abs(dot(u0, axis)) +
            e.y * abs(dot(u1, axis)) +
            e.z * abs(dot(u2, axis));

        if (max(-max(max(p0, p1), p2), min(min(p0, p1), p2)) > r) {
            return false;
        }
    }

    vec3 triangleNormal = cross(f0, f1);
    float plane_distance = dot(triangleNormal, v0);

    return true;
}

bool CollideBVH(vec3 CMin, vec3 CMax, in const int NodeStartIndex, in const int NodeCount, in const mat4 InverseMatrix, out int Mesh, out int TriangleIndex) {

    CMin = vec3(InverseMatrix * vec4(CMin.xyz, 1.0f));
    CMax = vec3(InverseMatrix * vec4(CMax.xyz, 1.0f));
    
    C_AABB aabb = C_AABB(CMin, CMax);

    // Work stack 
	int Stack[64];
	int StackPointer = 0;

    // Intersections 
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
        LeftTraversal = LeftLeaf ? -1.0f :  AABBAABBOverlapF(C_AABB(CurrentNode.LeftChildData.Min.xyz, CurrentNode.LeftChildData.Max.xyz), aabb);
        RightTraversal = RightLeaf ? -1.0f : AABBAABBOverlapF(C_AABB(CurrentNode.RightChildData.Min.xyz, CurrentNode.RightChildData.Max.xyz), aabb);

        // Intersect triangles if leaf node
        
        // Left child 
        if (LeftLeaf) {

            int Packed = GetStartIdx(CurrentNode.LeftChildData);
            int StartIdx = Packed >> 4;
                    
            int Length = Packed & 0xF;
                    
            for (int Idx = 0; Idx < Length ; Idx++) {
                Triangle triangle = BVHTris[Idx + StartIdx];
                
                const int Offset = 0;
                        
                vec3 VertexA = BVHVertices[triangle.PackedData[0] + Offset].Position.xyz;
                vec3 VertexB = BVHVertices[triangle.PackedData[1] + Offset].Position.xyz;
                vec3 VertexC = BVHVertices[triangle.PackedData[2] + Offset].Position.xyz;
                
                if (BoxTriangleOverlap(VertexA, VertexB, VertexC, aabb))
                {
                    Mesh = triangle.PackedData[3];
                    TriangleIndex = Idx;
                    return true;
                }
            }

        }

        // Right 
        if (RightLeaf) {
            
            int Packed = GetStartIdx(CurrentNode.RightChildData);
            int StartIdx = Packed >> 4;
                    
            int Length = Packed & 0xF;
                    
            for (int Idx = 0; Idx < Length ; Idx++) {
                Triangle triangle = BVHTris[Idx + StartIdx];
                
                const int Offset = 0;
                        
                vec3 VertexA = BVHVertices[triangle.PackedData[0] + Offset].Position.xyz;
                vec3 VertexB = BVHVertices[triangle.PackedData[1] + Offset].Position.xyz;
                vec3 VertexC = BVHVertices[triangle.PackedData[2] + Offset].Position.xyz;
                
                if (BoxTriangleOverlap(VertexA, VertexB, VertexC, aabb))
                {
                    Mesh = triangle.PackedData[3];
                    TriangleIndex = Idx;
                    return true;
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

    Mesh = IntersectMesh;
    TriangleIndex = IntersectTriangleIdx;

    return false;
}

bool CollideScene(in const vec3 Min, in const vec3 Max, out int Mesh, out int TriangleIdx, out int Entity_) {

    C_AABB aabb = C_AABB(Min, Max);

    int Mesh_ = -1;
    int Tri_ = -1;
    Entity_ = -1;

    for (int i = 0 ; i < u_EntityCount ; i++)
    {
        bool Collided = CollideBVH(aabb.Min, aabb.Max, BVHEntities[i].NodeOffset, BVHEntities[i].NodeCount, BVHEntities[i].InverseMatrix, Mesh_, Tri_);

        if (Collided) {
            Mesh = Mesh_;
            TriangleIdx = Tri_;
            Entity_ = i;
            return true;
        }

    }

    return false;
}



