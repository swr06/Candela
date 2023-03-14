float NDF(float cosLh, float roughness)
{
	float alpha   = roughness * roughness;
	float alphaSq = alpha * alpha;

	float denom = (cosLh * cosLh) * (alphaSq - 1.0) + 1.0;
	return alphaSq / (3.14159265359f * denom * denom);
}

float Schlick(float cosTheta, float k)
{
	return cosTheta / (cosTheta * (1.0 - k) + k);
}

float GGX(float cosLi, float cosLo, float roughness)
{
	float r = roughness + 1.0f;
	float k = (r * r) / 8.0f; 
	return Schlick(cosLi, k) * Schlick(cosLo, k);
}

vec3 FresnelSchlick(vec3 F0, float cosTheta)
{
	return F0 + (vec3(1.0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 FresnelSchlickRoughness(vec3 Eye, vec3 norm, vec3 F0, float roughness) 
{
	return F0 + (max(vec3(pow(1.0f - roughness, 3.0f)) - F0, vec3(0.0f))) * pow(max(1.0 - clamp(dot(Eye, norm), 0.0f, 1.0f), 0.0f), 5.0f);
}

vec3 FresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness)
{
    return F0 + (max(vec3(1.0-roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 CookTorranceBRDF(vec3 eye, vec3 world_pos, vec3 light_dir, vec3 radiance, vec3 albedo, vec3 N, vec2 rm, float shadow)
{
    const float Epsilon = 0.00001;

	// Material
	float roughness = rm.x;
	float metalness = rm.y;

    vec3 Lo = normalize(eye - world_pos);
	vec3 Li = -light_dir;
	vec3 Radiance = radiance;

	// Half vector 
	vec3 Lh = normalize(Li + Lo);

	// Compute cosines 
	float CosLo = max(0.0, dot(N, Lo));
	float CosLi = max(0.0, dot(N, Li));
	float CosLh = max(0.0, dot(N, Lh));

	// Fresnel 
	vec3 F0 = mix(vec3(0.04), albedo, metalness);
	vec3 F  = FresnelSchlick(F0, max(0.0, dot(Lh, Lo)));
	
	// Distribution 
	float D = NDF(CosLh, roughness);

	// Geometry 
	float G = GGX(CosLi, CosLo, roughness);

	// Direct diffuse 
	vec3 kd = mix(vec3(1.0) - F, vec3(0.0), metalness);
	vec3 DiffuseBRDF = kd * albedo;

	// Direct specular 
	vec3 SpecularBRDF = (F * D * G) / max(Epsilon, 4.0 * CosLi * CosLo);

	// Combine 
	vec3 Combined = (DiffuseBRDF + SpecularBRDF) * Radiance * CosLi;

	// Multiply by visibility and return
	return Combined * shadow;
}

//
float g_square(float x) {
	return x*x;
}	

float G_Smith_over_NdotV(float roughness, float NdotV, float NdotL)
{
    float alpha = g_square(roughness);
    float g1 = NdotV * sqrt(g_square(alpha) + (1.0 - g_square(alpha)) * g_square(NdotL));
    float g2 = NdotL * sqrt(g_square(alpha) + (1.0 - g_square(alpha)) * g_square(NdotV));
    return 2.0 *  NdotL / (g1 + g2);
}

float SpecularGGX(vec3 V, vec3 L, vec3 N, float roughness, float NoH_offset)
{
    vec3 H = normalize(L - V);
    float NoL = max(0, dot(N, L));
    float VoH = max(0, -dot(V, H));
    float NoV = max(0, -dot(N, V));
    float NoH = clamp(dot(N, H) + NoH_offset, 0, 1);

    if (NoL > 0)
    {
        float G = G_Smith_over_NdotV(roughness, NoV, NoL);
        float alpha = g_square(max(roughness, 0.02));
        float D = g_square(alpha) / (acos(-1.0f) * g_square(g_square(NoH) * g_square(alpha) + (1 - g_square(NoH))));
        return D * G / 4;
    }

    return 0;
}