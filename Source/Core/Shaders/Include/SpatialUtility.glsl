vec3 SpecularDominantDirection(vec3 V, vec3 N, float Roughness) {
	float f = (1.0f - Roughness) * (sqrt(1.0f - Roughness) + Roughness);
	vec3 R = reflect(-V, N);
	vec3 Direction = mix(N, R, f);
	return normalize(Direction);
}

float Variance(float x, float x2) {
	return abs(x2 - x * x);
}

float TransformReflectionTransversal(float x) {
	return x / 48.0f;
}	

float UntransformReflectionTransversal(float x) {
	return x * 48.0f;
}	

const float DEPTH_EXPONENT = 384.0f;
const float NORMAL_EXPONENT = 24.0f;