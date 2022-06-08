vec3 SpecularDominantDirection(vec3 V, vec3 N, float Roughness) {
	float f = (1.0f - Roughness) * (sqrt(1.0f - Roughness) + Roughness);
	vec3 R = reflect(-V, N);
	vec3 Direction = mix(N, R, f);
	return normalize(Direction);
}

