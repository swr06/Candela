const vec3 GridSpace = vec3(10.f);

float SphereSDF(vec3 p, float r){
    return length(p) - r;
}

void Repeat(inout vec3 p, vec3 dim)
{
    vec3 cellid;
    cellid = floor((p) / (dim));
    p = mod(p, dim) - dim * 0.5f;
}

float Target(vec3 p){
    return SphereSDF(p, 1.0);
}

float MapSDF(vec3 p)
{
    Repeat(p, vec3(GridSpace));
    return SphereSDF(p, 0.5f);
}

// C - P / |C - P|
vec3 Normal(vec3 p)
{
    float c = MapSDF(p);
    const float e = 0.001f;
    return normalize(vec3(c - MapSDF(p - vec3(e, 0.0f, 0.0f)), c-MapSDF(p - vec3(0.0f, e, 0.0f)), c - MapSDF(p-vec3(0.0f, 0.0f, e))));
}

float IntersectSphereGrid(vec3 Origin, vec3 Direction)
{
    float Distance = 0.0;
    const int Steps = 192;

    bool FoundIntersection = false;

    for(int i = 0; i < Steps; i++)
    {
        float t = MapSDF(Origin + Direction * Distance);
        Distance += t;

        if(t < 0.0001)
        {
            FoundIntersection = true;
        	break;
        }

       
    }
    
    return FoundIntersection ? min(Distance, 64.0) : -1.0f;
}