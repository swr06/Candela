float signNotZero(float f) { return(f >= 0.0) ? 1.0 : -1.0; }
vec2  signNotZero(vec2  v) { return vec2(signNotZero(v.x), signNotZero(v.y)); }

/** Assumes that v is a unit vector. The result is an octahedral vector on the [-1, +1] square. */
vec2 OctahedralEncode(in vec3 v) {
    float l1norm = abs(v.x) + abs(v.y) + abs(v.z);
    vec2 result = v.xy * (1.0 / l1norm);
    if (v.z < 0.0) {
        result = (1.0 - abs(result.yx)) * signNotZero(result.xy);
    }
    return result;
}


/** Returns a unit vector. Argument o is an octahedral vector packed via octEncode,
    on the [-1, +1] square*/
vec3 OctahedralDecode(vec2 o) {
    vec3 v = vec3(o.x, o.y, 1.0 - abs(o.x) - abs(o.y));
    if (v.z < 0.0) {
        v.xy = (1.0 - abs(v.yx)) * signNotZero(v.xy);
    }
    return normalize(v);
}
