struct AABB {
	vec4 Min;
	vec4 Max;
};

struct CollisionQuery {
	AABB Box;
};

struct CollisionResult {
	ivec4 Data;
};