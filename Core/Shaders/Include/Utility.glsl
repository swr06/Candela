#define saturate(x) (clamp(x, 0.0f, 1.0f))
#define Saturate(x) (clamp(x, 0.0f, 1.0f))
#define Lerp(x, y, m) (mix(x, y, m))
#define square(x) (x*x)
#define sqr(x) (x*x)
#define rcp(x) (1.0f/x)
#define clamp01(x) (saturate(x))

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

    result += texture(tex, vec2(texPos0.x, texPos0.y), 0.0f) * w0.x * w0.y;
    result += texture(tex, vec2(texPos12.x, texPos0.y), 0.0f) * w12.x * w0.y;
    result += texture(tex, vec2(texPos3.x, texPos0.y), 0.0f) * w3.x * w0.y;
    result += texture(tex, vec2(texPos0.x, texPos12.y), 0.0f) * w0.x * w12.y;
    result += texture(tex, vec2(texPos12.x, texPos12.y), 0.0f) * w12.x * w12.y;
    result += texture(tex, vec2(texPos3.x, texPos12.y), 0.0f) * w3.x * w12.y;
    result += texture(tex, vec2(texPos0.x, texPos3.y), 0.0f) * w0.x * w3.y;
    result += texture(tex, vec2(texPos12.x, texPos3.y), 0.0f) * w12.x * w3.y;
    result += texture(tex, vec2(texPos3.x, texPos3.y), 0.0f) * w3.x * w3.y;

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

  vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
  vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
  vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
  vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

  float sx = s.x / (s.x + s.y);
  float sy = s.z / (s.z + s.w);

  return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
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


