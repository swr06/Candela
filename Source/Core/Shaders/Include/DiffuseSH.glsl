vec3 SHToIrridiance(vec4 shY, vec2 CoCg, vec3 v)
{
    float x = dot(shY.xyz, v);
    float Y = 2.0 * (1.023326f * x + 0.886226f * shY.w);
    Y = max(Y, 0.0);
	CoCg *= Y * 0.282095f / (shY.w + 1e-6);
    float T = Y - CoCg.y * 0.5f;
    float G = CoCg.y + T;
    float B = T - CoCg.x * 0.5f;
    float R = B + CoCg.x;
    return max(vec3(R, G, B), vec3(0.0f));
}

vec3 SHToIrridiance(vec4 shY, vec2 CoCg)
{
    float Y = max(0, 3.544905f * shY.w);
    Y = max(Y, 0.0);
	CoCg *= Y * 0.282095f / (shY.w + 1e-6);
    float T = Y - CoCg.y * 0.5f;
    float G = CoCg.y + T;
    float B = T - CoCg.x * 0.5f;
    float R = B + CoCg.x;
    return max(vec3(R, G, B), vec3(0.0f));
}

float[6] IrridianceToSH(vec3 Radiance, vec3 Direction) {
	
	float Co = Radiance.x - Radiance.z; 
	float T = Radiance.z + Co * 0.5f; 
	float Cg = Radiance.y - T;
	float Y  = max(T + Cg * 0.5f, 0.0);
	float L00  = 0.282095f;
    float L1_1 = 0.488603f * Direction.y;
    float L10  = 0.488603f * Direction.z;
    float L11  = 0.488603f * Direction.x;
	float ReturnValue[6];
	ReturnValue[0] = max(L11 * Y, -100.0f);
	ReturnValue[1] = max(L1_1 * Y, -100.0f);
	ReturnValue[2] = max(L10 * Y, -100.0f);
	ReturnValue[3] = max(L00 * Y, -100.0f);
	ReturnValue[4] = Co;
	ReturnValue[5] = Cg;
	return ReturnValue;
}