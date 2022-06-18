// https://www.shadertoy.com/view/fdd3zf

vec2 Karis(float NdotV, float roughness)
{
	vec4 c0 = vec4(-1., -0.0275, -0.572, 0.022);
	vec4 c1 = vec4(1., 0.0425, 1.040, -0.040);
	vec4 r = roughness * c0 + c1;
	float a004 = min(r.x * r.x, exp2(-9.28 * NdotV)) * r.x + r.y;
	return vec2(-1.04, 1.04) * a004 + r.zw;
}
