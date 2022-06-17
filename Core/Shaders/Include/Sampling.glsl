vec3 CosWeightedHemisphere(const vec3 n, vec2 r) 
{
	float PI2 = 2.0f * 3.14159265359;
	vec3  uu = normalize(cross(n, vec3(0.0,1.0,1.0)));
	vec3  vv = cross(uu, n);
	float ra = sqrt(r.y);
	float rx = ra * cos(PI2 * r.x); 
	float ry = ra * sin(PI2 * r.x);
	float rz = sqrt(1.0 - r.y);
	vec3  rr = vec3(rx * uu + ry * vv + rz * n );
    return normalize(rr);
}

vec3 SampleSphere(vec3 Hash)
{
    float phi = 2.0f * 3.14159265359 * Hash.x; // 0 -> 2 pi
    float cosTheta = 2.0f * Hash.y - 1.0f; // -1 -> 1
    float u = Hash.z;
    float theta = acos(cosTheta);
    float r = pow(u, 1.0 / 3.0); // -> bias 
    float x = r * sin(theta) * cos(phi);
    float y = r * sin(theta) * sin(phi);
    float z = r * cos(theta);
    return vec3(x, y, z);
}

vec2 SamplePointInDisk(in float radius, in float Xi1, in float Xi2) 
{
    float r = radius * sqrt(1.0 - Xi1);
    float theta = Xi2 * 2.0f * 3.14159265359;
	return vec2(r * cos(theta), r * sin(theta));
}

vec3 SampleCone(in vec3 d, in float phi, in float sina, in float cosa) 
{    
	vec3 w = normalize(d);
    vec3 u = normalize(cross(w.yzx, w));
    vec3 v = cross(w, u);
	return (u * cos(phi) + v * sin(phi)) * sina + w * cosa;
}

vec3 SampleCone(vec2 Xi, float CosThetaMax) 
{
    float CosTheta = (1.0f - Xi.x) + Xi.x * CosThetaMax;
    float SinTheta = sqrt(1.0f - CosTheta * CosTheta);
    float phi = Xi.y * 3.14159265359f * 2.0f;
    vec3 L;
    L.x = SinTheta * cos(phi);
    L.y = SinTheta * sin(phi);
    L.z = CosTheta;
    return L;
}

vec3 SampleCone(vec3 Direction, vec2 Xi, float CosTheta) {
	const vec3 Basis = vec3(0.0f, 1.0f, 1.0f);
	vec3 L = Direction;
	vec3 T = normalize(cross(L, Basis));
	vec3 B = cross(T, L);
	mat3 TBN = mat3(T, B, L);
	return TBN * SampleCone(Xi, CosTheta);
}

vec3 SampleGGXVNDF(vec3 N, float roughness, vec2 Xi)
{
    float alpha = roughness * roughness;
    float alpha2 = alpha * alpha;
	
    float phi = 2.0 * 3.14159265359 * Xi.x;
    float cosTheta = sqrt((1.0 - Xi.y) / (1.0 + (alpha2 - 1.0) * Xi.y));
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);
	
    vec3 H;
    H.x = cos(phi) * sinTheta;
    H.y = sin(phi) * sinTheta;
    H.z = cosTheta;
	
    vec3 up = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(up, N));
    vec3 bitangent = cross(N, tangent);
	
    vec3 sampleVec = tangent * H.x + bitangent * H.y + N * H.z;
    return normalize(sampleVec);
} 