
float SphereSDF(vec3 p, float r){
    return (length(p) - r);
}

void Repeat(inout vec3 p, vec3 dim)
{
    vec3 cellid;
    cellid = floor((p) / (dim));
    p = mod(p, dim) - dim * 0.5;
}

float Target(vec3 p){
    return SphereSDF(p, 1.0);
}

float MapSDF(vec3 p)
{
    vec3 GridSpace = u_ProbeGridResolution / u_ProbeBoxSize;
    Repeat(p, vec3(GridSpace));
    return SphereSDF(p, 0.15f);
}

// C - P / |C - P|
vec3 Normal(vec3 p)
{
    float c = MapSDF(p);
    const float e = 0.001f;
    return normalize(vec3(c - MapSDF(p - vec3(e, 0.0f, 0.0f)), c-MapSDF(p - vec3(0.0f, e, 0.0f)), c - MapSDF(p-vec3(0.0f, 0.0f, e))));
}

vec4 IntersectProbeGrid(vec3 Origin, vec3 Direction)
{

    float Distance = 0.0;
    const int Steps = 128;

    bool FoundIntersection = false;

    for(int i = 0; i < Steps; i++)
    {
        if (!IsInProbeGrid(Origin + Direction * Distance) ) {
            FoundIntersection = false;
            break;
        }

        float t = MapSDF(Origin + Direction * Distance) ;
        Distance += t;

        if(t < 0.001)
        {
            FoundIntersection = true;
        	break;
        }
        
    }
    
    return FoundIntersection ? vec4(Normal(Origin+Direction*Distance),min(Distance, 64.0)) : vec4(-1.0f);
}

void DrawProbeSphereGrid(vec3 Origin, vec3 Direction, float SurfaceDistance, inout vec3 oColor) {
	
	vec4 Intersection = IntersectProbeGrid(Origin, Direction);

	if (Intersection.w < SurfaceDistance && Intersection.w > 0.0f) {
		const bool OutputRaw = false; 

		if (OutputRaw) {
			vec3 Probe = ((Origin + Direction * Intersection.w) - u_ProbeBoxOrigin) / u_ProbeBoxSize; 
			Probe = Probe * 0.5 + 0.5;  
			ivec3 ProbeTexel = ivec3(Probe * u_ProbeGridResolution);
			SH sh = GetSH(ProbeTexel);
			oColor = SampleSH(sh, Intersection.xyz); 
		}

		else {
			oColor = SampleProbes((Origin + Direction * Intersection.w), Intersection.xyz, false);
		}
	}
}