// 1st order spherical harmonic

const float Y00 = 0.28209479177387814347; 
const float Y11 = -0.48860251190291992159; 
const float Y10 = 0.48860251190291992159;
const float Y1_1 = -0.48860251190291992159;

//const float Y00 = 0.28209479177387814347; 
//const float Y11 = 0.48860251190291992159; 
//const float Y10 = 0.48860251190291992159;
//const float Y1_1 = 0.48860251190291992159;

struct SH {
	vec3 L00;
    vec3 L11;
    vec3 L10;
    vec3 L1_1;
};

SH GenerateEmptySH() {
    return SH(vec3(0.0f), vec3(0.0f), vec3(0.0f), vec3(0.0f));
}

void ScaleSH(inout SH sh, vec3 x) {
    sh.L00 *= x;
    sh.L11 *= x;
    sh.L10 *= x;
    sh.L1_1 *= x;
}

vec3 SampleSH(SH sh, vec3 direction) {

    vec3 result = vec3(0.0);
    result += sh.L00 * Y00;
    result += sh.L1_1 * Y1_1 * direction.y;
    result += sh.L10 * Y10 * direction.z;
    result += sh.L11 * Y11 * direction.x;
    return result;
}

SH EncodeSH(vec3 radiance, vec3 direction) {

    SH result = GenerateEmptySH();
    result.L00 += Y00 * radiance;
    result.L1_1 += Y1_1 * direction.y * radiance;
    result.L10 += Y10 * direction.z * radiance;
    result.L11 += Y11 * direction.x * radiance;
    return result;
}

SH AddSH(SH x, SH y) 
{
    SH result;
    result.L00 = x.L00 + y.L00;
    result.L1_1 = x.L1_1 + y.L1_1;
    result.L10 = x.L10 + y.L10;
    result.L11 = x.L11 + y.L11;
    return result;
}

float Max3shc(in vec3 x) {
    x = abs(x);
    return max(max(x.x, x.y), x.z);
}

void PackSH(SH sh, out uvec4 A, out uvec4 B) {
    
    // Find max value 
    float MaxSH = -1000.0f;

    MaxSH = max(MaxSH, Max3shc(sh.L00));
    MaxSH = max(MaxSH, Max3shc(sh.L11));
    MaxSH = max(MaxSH, Max3shc(sh.L10));
    MaxSH = max(MaxSH, Max3shc(sh.L1_1));

    sh.L00 /= MaxSH;
    sh.L11 /= MaxSH;
    sh.L10 /= MaxSH;
    sh.L1_1 /= MaxSH;

    uint Packed[8];
    Packed[0] = packSnorm2x16(vec2(sh.L00.x, sh.L00.y));
    Packed[1] = packSnorm2x16(vec2(sh.L00.z, sh.L11.x));
    Packed[2] = packSnorm2x16(vec2(sh.L11.y, sh.L11.z));
    Packed[3] = packSnorm2x16(vec2(sh.L10.x, sh.L10.y));
    Packed[4] = packSnorm2x16(vec2(sh.L10.z, sh.L1_1.x));
    Packed[5] = packSnorm2x16(vec2(sh.L1_1.y, sh.L1_1.z));
    Packed[6] = floatBitsToUint(MaxSH);
    Packed[7] = 0;

    A = uvec4(Packed[0], Packed[1], Packed[2], Packed[3]);
    B = uvec4(Packed[4], Packed[5], Packed[6], Packed[7]);
}

SH UnpackSH(uvec4 A, uvec4 B) {
    
    SH sh;

    float Multiplier = uintBitsToFloat(B.z);

    vec2 Unpacked[6];

    Unpacked[0] = unpackSnorm2x16(A.x) * Multiplier;
    Unpacked[1] = unpackSnorm2x16(A.y) * Multiplier;
    Unpacked[2] = unpackSnorm2x16(A.z) * Multiplier;
    Unpacked[3] = unpackSnorm2x16(A.w) * Multiplier;
    Unpacked[4] = unpackSnorm2x16(B.x) * Multiplier;
    Unpacked[5] = unpackSnorm2x16(B.y) * Multiplier;

    sh.L00 = vec3(Unpacked[0].x, Unpacked[0].y, Unpacked[1].x);
    sh.L11 = vec3(Unpacked[1].y, Unpacked[2].x, Unpacked[2].y);
    sh.L10 = vec3(Unpacked[3].x, Unpacked[3].y, Unpacked[4].x);
    sh.L1_1 = vec3(Unpacked[4].y, Unpacked[5].x, Unpacked[5].y);

    return sh;
}