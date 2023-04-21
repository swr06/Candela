#define saturate(x) (clamp(x, 0.0f, 1.0f))
#define Saturate(x) (clamp(x, 0.0f, 1.0f))
#define Lerp(x, y, m) (mix(x, y, m))
#define square(x) (x*x)
#define sqr(x) (x*x)
#define rcp(x) (1.0f/x)
#define clamp01(x) (saturate(x))

struct GBufferData {
   vec3 Position;
   vec3 Normal;
   vec3 Albedo;
   bool ValidMask;
   float SkyAmount;
   float Depth;
};

float max_of(vec2 v) { return max(v.x, v.y); }
float max_of(vec3 v) { return max(v.x, max(v.y, v.z)); }
float max_of(vec4 v) { return max(v.x, max(v.y, max(v.z, v.w))); }
float min_of(vec2 v) { return min(v.x, v.y); }
float min_of(vec3 v) { return min(v.x, min(v.y, v.z)); }
float min_of(vec4 v) { return min(v.x, min(v.y, min(v.z, v.w))); }

mat4 SaturationMatrix(float saturation)
{
  vec3 luminance = vec3(0.3086, 0.6094, 0.0820);
  float oneMinusSat = 1.0 - saturation;
  vec3 red = vec3(luminance.x * oneMinusSat);
  red += vec3(saturation, 0, 0);

  vec3 green = vec3(luminance.y * oneMinusSat);
  green += vec3(0, saturation, 0);

  vec3 blue = vec3(luminance.z * oneMinusSat);
  blue += vec3(0, 0, saturation);

  return mat4(red, 0,
    green, 0,
    blue, 0,
    0, 0, 0, 1);
}

bool IsSky(float D) {
    if (D > 0.99999999f || D == 1.0f) {
        return true;
    }

    return false;
}

bool InScreenspace(vec2 x) {
    const float bias = 0.0000000001f;
    if (x.x > bias && x.x < 1.0f-bias && x.y > bias && x.y < 1.0f-bias) {
        return true;
    }

    return false;
}   

bool IsInScreenspace(vec2 x) {
    const float bias = 0.0000000001f;
    if (x.x > bias && x.x < 1.0f-bias && x.y > bias && x.y < 1.0f-bias) {
        return true;
    }

    return false;
}   

bool IsInScreenspaceBiased(vec2 x) {
    const float bias = 0.005f;
    if (x.x > bias && x.x < 1.0f-bias && x.y > bias && x.y < 1.0f-bias) {
        return true;
    }

    return false;
}   

bool InScreenspace(vec3 x) {
    const float bias = 0.001f;
    if (x.x > bias && x.x < 1.0f-bias && x.y > bias && x.y < 1.0f-bias && x.z > 0.0f && x.z < 1.0f-bias) {
        return true;
    }

    return false;
}   

bool IsInScreenspace(vec3 x) {
    const float bias = 0.001f;
    if (x.x > bias && x.x < 1.0f-bias && x.y > bias && x.y < 1.0f-bias && x.z > 0.0f && x.z < 1.0f-bias) {
        return true;
    }

    return false;
}   

bool IsValid(in float x) {
	
	if (isnan(x) || isinf(x)) {
		return false;
	}

	return true;

}

bool IsValid(in vec2 x) {
	
	if (isnan(x.x) || isinf(x.x) || isnan(x.y) || isinf(x.y)) {
		return false;
	}

	return true;

}

bool IsValid(in vec3 x) {
	
	if (isnan(x.x) || isinf(x.x) || isnan(x.y) || isinf(x.y) || isnan(x.z) || isinf(x.z)) {
		return false;
	}

	return true;
}


bool IsValid(in vec4 x) {
	
	if (isnan(x.x) || isinf(x.x) || isnan(x.y) || isinf(x.y) || isnan(x.z) || isinf(x.z) || isnan(x.w) || isinf(x.w)) {
		return false;
	}

	return true;
}

float Luminance(vec3 rgb)
{
    const vec3 W = vec3(0.2125, 0.7154, 0.0721);
    return dot(rgb, W);
}

vec3 InverseReinhard(vec3 RGB)
{
    return (RGB / (vec3(1.0f) - Luminance(RGB)));
}

vec3 Reinhard(vec3 RGB)
{
    return vec3(RGB) / (vec3(1.0f) + Luminance(RGB));
}

float Manhattan(in vec3 p1, in vec3 p2)
{
	return abs(p1.x - p2.x) + abs(p1.y - p2.y) + abs(p1.z - p2.z);
}

vec3 ClipToAABB(vec3 prevColor, vec3 minColor, vec3 maxColor)
{
    vec3 pClip = 0.5 * (maxColor + minColor); 
    vec3 eClip = 0.5 * (maxColor - minColor); 
    vec3 vClip = prevColor - pClip;
    vec3 vUnit = vClip / eClip;
    vec3 aUnit = abs(vUnit);
    float denom = max(aUnit.x, max(aUnit.y, aUnit.z));
    return denom > 1.0 ? pClip + vClip / denom : prevColor;
}

vec4 ClipToAABB(vec4 prevColor, vec4 minColor, vec4 maxColor)
{
    vec4 pClip = 0.5 * (maxColor + minColor); 
    vec4 eClip = 0.5 * (maxColor - minColor); 
    vec4 vClip = prevColor - pClip;
    vec4 vUnit = vClip / eClip;
    vec4 aUnit = abs(vUnit);
    float denom = max(aUnit.w, max(aUnit.x, max(aUnit.y, aUnit.z)));
    return denom > 1.0 ? pClip + vClip / denom : prevColor;
}

float ClipToAABB(float prevColor, float minColor, float maxColor)
{
    float pClip = 0.5 * (maxColor + minColor); 
    float eClip = 0.5 * (maxColor - minColor); 
    float vClip = prevColor - pClip;
    float vUnit = vClip / eClip;
    float aUnit = abs(vUnit);
    float denom = aUnit;
    return denom > 1.0 ? pClip + vClip / denom : prevColor;
}

vec3 RGB2YCoCg(in vec3 rgb)
{
    float co = rgb.r - rgb.b;
    float t = rgb.b + co / 2.0;
    float cg = rgb.g - t;
    float y = t + cg / 2.0;
    return vec3(y, co, cg);
}

vec3 YCoCg2RGB(in vec3 ycocg)
{
    float t = ycocg.r - ycocg.b / 2.0;
    float g = ycocg.b + t;
    float b = t - ycocg.g / 2.0;
    float r = ycocg.g + b;
    return vec3(r, g, b);
}

float Gaussian(float DistanceSqr)
{
    return exp(-2.29f * DistanceSqr);
}

vec4 CatmullRomConfidence(sampler2D sampler, vec2 coord, out float confidence) {
	vec2 res = textureSize(sampler, 0);
	vec2 view_pixel_size = 1.0 / res;
	vec2 sample_pos = coord * res;
	vec2 tex_pos_1 = floor(sample_pos - 0.5) + 0.5;
	vec2 f = sample_pos - tex_pos_1;
	vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
	vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
	vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
	vec2 w3 = f * f * (-0.5 + 0.5 * f);
	vec2 w12 = w1 + w2;
	vec2 offset12 = w2 / (w1 + w2);
	vec2 tex_pos_0 = tex_pos_1 - 1.0;
	vec2 tex_pos_3 = tex_pos_1 + 2.0;
	vec2 tex_pos_12 = tex_pos_1 + offset12;

	tex_pos_0 *= view_pixel_size;
	tex_pos_3 *= view_pixel_size;
	tex_pos_12 *= view_pixel_size;

	vec4 result = vec4(0.0);
	result += texture(sampler, vec2(tex_pos_0.x, tex_pos_0.y)) * w0.x * w0.y;
	result += texture(sampler, vec2(tex_pos_12.x, tex_pos_0.y)) * w12.x * w0.y;
	result += texture(sampler, vec2(tex_pos_3.x, tex_pos_0.y)) * w3.x * w0.y;

	result += texture(sampler, vec2(tex_pos_0.x, tex_pos_12.y)) * w0.x * w12.y;
	result += texture(sampler, vec2(tex_pos_12.x, tex_pos_12.y)) * w12.x * w12.y;
	result += texture(sampler, vec2(tex_pos_3.x, tex_pos_12.y)) * w3.x * w12.y;

	result += texture(sampler, vec2(tex_pos_0.x, tex_pos_3.y)) * w0.x * w3.y;
	result += texture(sampler, vec2(tex_pos_12.x, tex_pos_3.y)) * w12.x * w3.y;
	result += texture(sampler, vec2(tex_pos_3.x, tex_pos_3.y)) * w3.x * w3.y;

	// Calculate confidence-of-quality factor using UE method (maximum weight)
	confidence = max_of(vec4(w0.x, w1.x, w2.x, w3.x)) * max_of(vec4(w0.y, w1.y, w2.y, w3.y));

	return result;
}

vec4 CatmullRom(sampler2D tex, in vec2 uv)
{
    vec2 texSize = textureSize(tex, 0).xy;
    vec2 samplePos = uv * texSize;
    vec2 texPos1 = floor(samplePos - 0.5f) + 0.5f;
    vec2 f = samplePos - texPos1;
    vec2 w0 = f * (-0.5f + f * (1.0f - 0.5f * f));
    vec2 w1 = 1.0f + f * f * (-2.5f + 1.5f * f);
    vec2 w2 = f * (0.5f + f * (2.0f - 1.5f * f));
    vec2 w3 = f * f * (-0.5f + 0.5f * f);
    
    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / (w1 + w2);

    vec2 texPos0 = texPos1 - 1;
    vec2 texPos3 = texPos1 + 2;
    vec2 texPos12 = texPos1 + offset12;

    texPos0 /= texSize;
    texPos3 /= texSize;
    texPos12 /= texSize;

    vec4 result = vec4(0.0f);

    result += texture(tex, vec2(texPos0.x, texPos0.y)) * w0.x * w0.y;
    result += texture(tex, vec2(texPos12.x, texPos0.y)) * w12.x * w0.y;
    result += texture(tex, vec2(texPos3.x, texPos0.y)) * w3.x * w0.y;
    result += texture(tex, vec2(texPos0.x, texPos12.y)) * w0.x * w12.y;
    result += texture(tex, vec2(texPos12.x, texPos12.y)) * w12.x * w12.y;
    result += texture(tex, vec2(texPos3.x, texPos12.y)) * w3.x * w12.y;
    result += texture(tex, vec2(texPos0.x, texPos3.y)) * w0.x * w3.y;
    result += texture(tex, vec2(texPos12.x, texPos3.y)) * w12.x * w3.y;
    result += texture(tex, vec2(texPos3.x, texPos3.y)) * w3.x * w3.y;

    return result;
}

vec4 CatmullRom(sampler2D tex, in vec2 uv, float LODBias)
{
    vec2 texSize = textureSize(tex, 0).xy;
    vec2 samplePos = uv * texSize;
    vec2 texPos1 = floor(samplePos - 0.5f) + 0.5f;
    vec2 f = samplePos - texPos1;
    vec2 w0 = f * (-0.5f + f * (1.0f - 0.5f * f));
    vec2 w1 = 1.0f + f * f * (-2.5f + 1.5f * f);
    vec2 w2 = f * (0.5f + f * (2.0f - 1.5f * f));
    vec2 w3 = f * f * (-0.5f + 0.5f * f);
    
    vec2 w12 = w1 + w2;
    vec2 offset12 = w2 / (w1 + w2);

    vec2 texPos0 = texPos1 - 1;
    vec2 texPos3 = texPos1 + 2;
    vec2 texPos12 = texPos1 + offset12;

    texPos0 /= texSize;
    texPos3 /= texSize;
    texPos12 /= texSize;

    vec4 result = vec4(0.0f);

    #ifdef COMPUTE 
        // Lod bias isnt supported on compute 
        result += texture(tex, vec2(texPos0.x, texPos0.y)) * w0.x * w0.y;
        result += texture(tex, vec2(texPos12.x, texPos0.y)) * w12.x * w0.y;
        result += texture(tex, vec2(texPos3.x, texPos0.y)) * w3.x * w0.y;
        result += texture(tex, vec2(texPos0.x, texPos12.y)) * w0.x * w12.y;
        result += texture(tex, vec2(texPos12.x, texPos12.y)) * w12.x * w12.y;
        result += texture(tex, vec2(texPos3.x, texPos12.y)) * w3.x * w12.y;
        result += texture(tex, vec2(texPos0.x, texPos3.y)) * w0.x * w3.y;
        result += texture(tex, vec2(texPos12.x, texPos3.y)) * w12.x * w3.y;
        result += texture(tex, vec2(texPos3.x, texPos3.y)) * w3.x * w3.y;
    #else 
        result += texture(tex, vec2(texPos0.x, texPos0.y), LODBias) * w0.x * w0.y;
        result += texture(tex, vec2(texPos12.x, texPos0.y), LODBias) * w12.x * w0.y;
        result += texture(tex, vec2(texPos3.x, texPos0.y), LODBias) * w3.x * w0.y;
        result += texture(tex, vec2(texPos0.x, texPos12.y), LODBias) * w0.x * w12.y;
        result += texture(tex, vec2(texPos12.x, texPos12.y), LODBias) * w12.x * w12.y;
        result += texture(tex, vec2(texPos3.x, texPos12.y), LODBias) * w3.x * w12.y;
        result += texture(tex, vec2(texPos0.x, texPos3.y), LODBias) * w0.x * w3.y;
        result += texture(tex, vec2(texPos12.x, texPos3.y), LODBias) * w12.x * w3.y;
        result += texture(tex, vec2(texPos3.x, texPos3.y), LODBias) * w3.x * w3.y;
    #endif

    return result;
}

vec4 cubic(float x) {
  float x2 = x * x;
  float x3 = x2 * x;
  vec4 w;
  w.x =   -x3 + 3*x2 - 3*x + 1;
  w.y =  3*x3 - 6*x2       + 4;
  w.z = -3*x3 + 3*x2 + 3*x + 1;
  w.w =  x3;
  return w / 6.f;
}

vec4 Bicubic(sampler2D tex, vec2 coord, vec2 resolution) {
    coord *= resolution;

    float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec4 Bicubic(sampler2D tex, vec2 coord) {
    vec2 resolution = textureSize(tex, 0).xy;
    coord *= resolution;

    float fx = fract(coord.x);
    float fy = fract(coord.y);
    coord.x -= fx;
    coord.y -= fy;

    vec4 xcubic = cubic(fx);
    vec4 ycubic = cubic(fy);

    vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
    vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
    vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

    vec4 sample0 = texture(tex, vec2(offset.x, offset.z) / resolution);
    vec4 sample1 = texture(tex, vec2(offset.y, offset.z) / resolution);
    vec4 sample2 = texture(tex, vec2(offset.x, offset.w) / resolution);
    vec4 sample3 = texture(tex, vec2(offset.y, offset.w) / resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

// Super fast lanczos resampler 
vec4 LanczosResamplerFast(sampler2D tex, vec2 UV) 
{
     vec4 scale = vec4(
        1. / vec2(textureSize(tex, 0)),
        vec2(textureSize(tex, 0)) / textureSize(tex,0).xy
    );
    
    vec2 fragCoord = UV * textureSize(tex,0);
    vec2 src_pos = scale.zw * fragCoord;
    vec2 src_centre = floor(src_pos - .5) + .5;
    vec4 f; f.zw = 1. - (f.xy = src_pos - src_centre);
    vec4 l2_w0_o3 = ((1.5672 * f - 2.6445) * f + 0.0837) * f + 0.9976;
    vec4 l2_w1_o3 = ((-0.7389 * f + 1.3652) * f - 0.6295) * f - 0.0004;
    vec4 w1_2 = l2_w0_o3;
    vec2 w12 = w1_2.xy + w1_2.zw;
    vec4 wedge = l2_w1_o3.xyzw * w12.yxyx;
    vec2 tc12 = scale.xy * (src_centre + w1_2.zw / w12);
    vec2 tc0 = scale.xy * (src_centre - 1.);
    vec2 tc3 = scale.xy * (src_centre + 2.);
    float sum = wedge.x + wedge.y + wedge.z + wedge.w + w12.x * w12.y;    
    wedge /= sum;
    vec4 col = vec4(
        texture(tex, vec2(tc12.x, tc0.y)) * wedge.y +
        texture(tex, vec2(tc0.x, tc12.y)) * wedge.x +
        texture(tex, tc12.xy) * (w12.x * w12.y) +
        texture(tex, vec2(tc3.x, tc12.y)) * wedge.z +
        texture(tex, vec2(tc12.x, tc3.y)) * wedge.w
    );

    return col;
}

float RayleighPhase(float cosTheta) 
{
	float y = 0.035 / (2.0 - 0.035);
	float p1 = 3.0 / (4.0 * (1.0 + 2.0*y));
	float p2 = (1.0 + 3.0*y) + (1.0 - y) * square(cosTheta);
	float phase = p1 * p2;
	phase *= rcp(3.14159265359*4.0);
	return phase;
}

float CornetteShanksMiePhase(float cosTheta, float g) 
{
	float gg = g*g;
	float p1 = 3.0 * (1.0 - gg) * rcp((3.14159265359 * (2.0 + gg)));
	float p2 = (1.0 + square(cosTheta)) * rcp(pow((1.0 + gg - 2.0 * g * cosTheta), 3.0/2.0));
	float phase = p1 * p2;
	phase *= rcp(3.14159265359*4.0);
	return max(phase, 0.0);
}

vec4 TextureSmooth(sampler2D samp, vec2 uv) 
{
    vec2 textureResolution = textureSize(samp, 0).xy;
	uv = uv*textureResolution + 0.5f;
	vec2 iuv = floor(uv);
	vec2 fuv = fract(uv);
	uv = iuv + fuv*fuv*(3.0f-2.0f*fuv); 
	uv = (uv - 0.5f) / textureResolution;
	return texture(samp, uv).xyzw;
}

float Remap(float x, float a, float b, float c, float d)
{
    return (((x - a) / (b - a)) * (d - c)) + c;
}

float SRGBToLinear(float x){
    return x > 0.04045 ? pow(x * (1 / 1.055) + 0.0521327, 2.4) : x / 12.92;
}

vec3 SRGBToLinearVec3(vec3 x){
    return vec3(SRGBToLinear(x.x),
                SRGBToLinear(x.y),
                SRGBToLinear(x.z));
}

vec3 LinearToSRGB(vec3 linear) {
    vec3 SRGBLo = linear * 12.92;
    vec3 SRGBHi = (pow(abs(linear), vec3(1.0/2.4)) * 1.055) - 0.055;
    vec3 SRGB = mix(SRGBHi, SRGBLo, step(linear, vec3(0.0031308)));
    return SRGB;
}


vec3 TemperatureToRGB(float temperatureInKelvins)
{
	vec3 retColor;
	
    temperatureInKelvins = clamp(temperatureInKelvins, 1000, 50000) / 100;
    
    if (temperatureInKelvins <= 66){
        retColor.r = 1;
        retColor.g = clamp01(0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098);
    } else {
    	float t = temperatureInKelvins - 60;
        retColor.r = clamp01(1.29293618606274509804 * pow(t, -0.1332047592));
        retColor.g = clamp01(1.12989086089529411765 * pow(t, -0.0755148492));
    }
    
    if (temperatureInKelvins >= 66)
        retColor.b = 1;
    else if(temperatureInKelvins <= 19)
        retColor.b = 0;
    else
        retColor.b = clamp01(0.54320678911019607843 * log(temperatureInKelvins - 10) - 1.19625408914);

    return SRGBToLinearVec3(retColor);
}     

vec2 RSI(vec3 origin, vec3 dir, float radius)
{
	float B = dot(origin, dir);
	float C = dot(origin, origin) - radius * radius;
	float D = B * B - C;

	vec2 intersection;

	if (D < 0.0)
	{
		intersection = vec2(-1.0, -1.0);
	} 
	
	else
	{
		D = sqrt(D);
		intersection = -B + vec2(-D, D); 
	}

	return intersection;
}

#ifndef COMPUTE
vec4 SoftwareBilinear(sampler2D tex, vec2 uv)
{
    vec2 texSize = textureSize(tex, 0).xy;
	vec2 pos = uv * texSize - 0.5;
    vec2 f = fract(pos);
    vec2 pos_top_left = floor(pos);
    vec4 tl = texture(tex, (pos_top_left + vec2(0.5, 0.5)) / texSize, -100.0);
    vec4 tr = texture(tex, (pos_top_left + vec2(1.5, 0.5)) / texSize, -100.0);
    vec4 bl = texture(tex, (pos_top_left + vec2(0.5, 1.5)) / texSize, -100.0);
    vec4 br = texture(tex, (pos_top_left + vec2(1.5, 1.5)) / texSize, -100.0);
    vec4 ret = mix(mix(tl, tr, f.x), mix(bl, br, f.x), f.y);
    return ret;
}
#endif

float GetLuminance(in vec3 color) {
    return dot(color, vec3(0.2722287168, 0.6740817658, 0.0536895174));
}


float LuminanceAccurate(in vec3 color) {
    return dot(color, vec3(0.2722287168, 0.6740817658, 0.0536895174));
}

float bayer2(vec2 a){
    a = floor(a);
    return fract(dot(a, vec2(0.5, a.y * 0.75)));
}
#define bayer4(a)   (bayer2(  0.5 * (a)) * 0.25 + bayer2(a))
#define bayer8(a)   (bayer4(  0.5 * (a)) * 0.25 + bayer2(a))
#define bayer16(a)  (bayer8(  0.5 * (a)) * 0.25 + bayer2(a))
#define bayer32(a)  (bayer16( 0.5 * (a)) * 0.25 + bayer2(a))
#define bayer64(a)  (bayer32( 0.5 * (a)) * 0.25 + bayer2(a))
#define bayer128(a) (bayer64( 0.5 * (a)) * 0.25 + bayer2(a))
#define bayer256(a) (bayer128(0.5 * (a)) * 0.25 + bayer2(a))

vec4 Nearest(sampler2D tex, vec2 uv) {
    vec2 res = textureSize(tex,0).xy;
    uv *= res;
    uv = floor(uv)+0.5;
    uv /= res;
    return textureLod(tex, uv, 0.0);
}

vec4 TexelFetchNormalized(sampler2D tex, vec2 uv) {
    vec2 res = textureSize(tex,0).xy;
    return texelFetch(tex, ivec2(res*uv), 0);
}

float vmin(vec3 v) { return min(v.x, min(v.y, v.z)); }

float vmax(vec3 v) { return max(v.x, max(v.y, v.z)); }

float remap(float x, float a, float b, float c, float d)
{
    return (((x - a) / (b - a)) * (d - c)) + c;
}


//////////////////////////

vec4 mod289(vec4 x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float mod289(float x) {
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
	return mod289(((x*34.0)+1.0)*x);
}

float permute(float x) {
	return mod289(((x*34.0)+1.0)*x);
}

vec4 taylorInvSqrt(vec4 r) {
	return 1.79284291400159 - 0.85373472095314 * r;
}

float taylorInvSqrt(float r) {
	return 1.79284291400159 - 0.85373472095314 * r;
}

vec4 grad4(float j, vec4 ip) {
	const vec4 ones = vec4(1.0, 1.0, 1.0, -1.0);
	vec4 p,s;
	p.xyz = floor( fract (vec3(j) * ip.xyz) * 7.0) * ip.z - 1.0;
	p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
	s = vec4(lessThan(p, vec4(0.0)));
	p.xyz = p.xyz + (s.xyz*2.0 - 1.0) * s.www;
	return p;
}

// (sqrt(5) - 1)/4 = F4, used once below
#define F4 0.309016994374947451

float snoise(vec4 v) {
	const vec4 C = vec4(
		0.138196601125011, // (5 - sqrt(5))/20 G4
		0.276393202250021, // 2 * G4
		0.414589803375032, // 3 * G4
		-0.447213595499958); // -1 + 4 * G4

	// First corner
	vec4 i = floor(v + dot(v, vec4(F4)) );
	vec4 x0 = v - i + dot(i, C.xxxx);

	// Other corners
	// Rank sorting originally contributed by Bill Licea-Kane, AMD (formerly ATI)
	vec4 i0;
	vec3 isX = step( x0.yzw, x0.xxx );
	vec3 isYZ = step( x0.zww, x0.yyz );
	// i0.x = dot( isX, vec3( 1.0 ) );
	i0.x = isX.x + isX.y + isX.z;
	i0.yzw = 1.0 - isX;
	// i0.y += dot( isYZ.xy, vec2( 1.0 ) );
	i0.y += isYZ.x + isYZ.y;
	i0.zw += 1.0 - isYZ.xy;
	i0.z += isYZ.z;
	i0.w += 1.0 - isYZ.z;

	// i0 now contains the unique values 0,1,2,3 in each channel
	vec4 i3 = clamp( i0, 0.0, 1.0 );
	vec4 i2 = clamp( i0-1.0, 0.0, 1.0 );
	vec4 i1 = clamp( i0-2.0, 0.0, 1.0 );
	// x0 = x0 - 0.0 + 0.0 * C.xxxx
	// x1 = x0 - i1 + 1.0 * C.xxxx
	// x2 = x0 - i2 + 2.0 * C.xxxx
	// x3 = x0 - i3 + 3.0 * C.xxxx
	// x4 = x0 - 1.0 + 4.0 * C.xxxx
	vec4 x1 = x0 - i1 + C.xxxx;
	vec4 x2 = x0 - i2 + C.yyyy;
	vec4 x3 = x0 - i3 + C.zzzz;
	vec4 x4 = x0 + C.wwww;

	// Permutations
	i = mod289(i);
	float j0 = permute( permute( permute( permute(i.w) + i.z) + i.y) + i.x);
	vec4 j1 = permute( permute( permute( permute (
	i.w + vec4(i1.w, i2.w, i3.w, 1.0 ))
	+ i.z + vec4(i1.z, i2.z, i3.z, 1.0 ))
	+ i.y + vec4(i1.y, i2.y, i3.y, 1.0 ))
	+ i.x + vec4(i1.x, i2.x, i3.x, 1.0 ));

	// Gradients: 7x7x6 points over a cube, mapped onto a 4-cross polytope
	// 7*7*6 = 294, which is close to the ring size 17*17 = 289.
	vec4 ip = vec4(1.0/294.0, 1.0/49.0, 1.0/7.0, 0.0) ;
	vec4 p0 = grad4(j0, ip);
	vec4 p1 = grad4(j1.x, ip);
	vec4 p2 = grad4(j1.y, ip);
	vec4 p3 = grad4(j1.z, ip);
	vec4 p4 = grad4(j1.w, ip);

	// Normalise gradients
	vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;
	p4 *= taylorInvSqrt(dot(p4,p4));

	// Mix contributions from the five corners
	vec3 m0 = max(0.6 - vec3(dot(x0,x0), dot(x1,x1), dot(x2,x2)), 0.0);
	vec2 m1 = max(0.6 - vec2(dot(x3,x3), dot(x4,x4) ), 0.0);
	m0 = m0 * m0;
	m1 = m1 * m1;
	return 49.0 *
		( dot(m0*m0, vec3( dot( p0, x0 ), dot( p1, x1 ), dot( p2, x2 )))
		+ dot(m1*m1, vec2( dot( p3, x3 ), dot( p4, x4 ) ) ) ) ;
}





/////////////////////////


const mat3x3 xyzToRGBMatrix = mat3(
    3.1338561, -1.6168667, -0.4906146,
    -0.9787684,  1.9161415,  0.0334540,
    0.0719453, -0.2289914,  1.4052427
);

const mat3x3 rgbToXYZMatrix = mat3(
    vec3(0.5149, 0.3244, 0.1607),
    vec3(0.3654, 0.6704, 0.0642),
    vec3(0.0248, 0.1248, 0.8504)
);

vec3 xyzToRGB(in vec3 xyz) {
    float r = dot(xyz, xyzToRGBMatrix[0]);
    float g = dot(xyz, xyzToRGBMatrix[1]);
    float b = dot(xyz, xyzToRGBMatrix[2]);
    return vec3(r, g, b);
}

vec3 rgbToXYZ(in vec3 rgb) {
    float x = dot(rgb, rgbToXYZMatrix[0]);
    float y = dot(rgb, rgbToXYZMatrix[1]);
    float z = dot(rgb, rgbToXYZMatrix[2]);
    return vec3(x, y, z);
}