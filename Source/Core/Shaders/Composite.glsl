#version 330 core

#include "Include/Utility.glsl"

in vec2 v_TexCoords;
layout(location = 0) out vec3 o_Color;

uniform sampler2D u_MainTexture;
uniform sampler2D u_DOF;

uniform sampler3D u_TonyMcMapFaceLUT;

uniform int u_SelectedTonemap;

uniform bool u_DOFEnabled;

uniform float u_zNear;
uniform float u_zFar;

uniform float u_DOFScale;

uniform float u_FocusDepth;

uniform bool u_PerformanceDOF;

uniform float u_GrainStrength;

uniform float u_Time;

uniform float u_Exposure;

uniform vec3 u_SunDirection;

uniform float u_PurkinjeStrength;

const float DOFBlurSize = 20.0f;
float DOFScale = u_DOFScale * 4.0f;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

// Tonemap 0 : Academy Tonemap (fitted curve)
// ACES Tonemap operator 
mat3 ACESInputMat = mat3(
    0.59719, 0.07600, 0.02840,
    0.35458, 0.90834, 0.13383,
    0.04823, 0.01566, 0.83777
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
mat3 ACESOutputMat = mat3(
    1.60475, -0.10208, -0.00327,
    -0.53108, 1.10813, -0.07276,
    -0.07367, -0.00605, 1.07602
);

vec3 RRTAndODTFit(vec3 v)
{
    vec3 a = v * (v + 0.0245786f) - 0.000090537f;
    vec3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

vec3 ACESFitted(vec3 Color)
{ 
    Color.rgb = ACESInputMat * Color.rgb;
    Color.rgb = RRTAndODTFit(Color.rgb);
    Color.rgb = ACESOutputMat * Color.rgb;

    return Color;
}

// Tonemap 1 : ACES Filmic/Cinematic
vec3 ACESFilmic(vec3 color)
{	
	mat3 m1 = mat3(
        0.59719, 0.07600, 0.02840,
        0.35458, 0.90834, 0.13383,
        0.04823, 0.01566, 0.83777
	);
	mat3 m2 = mat3(
        1.60475, -0.10208, -0.00327,
        -0.53108,  1.10813, -0.07276,
        -0.07367, -0.00605,  1.07602
	);
	vec3 v = m1 * color;    
	vec3 a = v * (v + 0.0245786) - 0.000090537;
	vec3 b = v * (0.983729 * v + 0.4329510) + 0.238081;
	return pow(clamp(m2 * (a / b), 0.0, 1.0), vec3(1.0 / 2.2));	
}



// Tonemap 2 : TonyMcMapface 
// By Tomasz Stachowiak 
vec3 TonemapTonyMcMapface(vec3 stimulus) {
    vec3 encoded = stimulus / (stimulus + 1.0);

    const float LUT_DIMS = 48.0;
    vec3 uv = encoded * ((LUT_DIMS - 1.0) / LUT_DIMS) + 0.5 / LUT_DIMS;
   // uv.y = 1.0f - uv.y;

    return texture(u_TonyMcMapFaceLUT, uv).xyz;
}

// Tonemap 3 : Lottes Fit 
float LottesTonemapF(float x) {
    const float a = 1.6;
    const float d = 0.977;
    const float hdrMax = 8.0;
    const float midIn = 0.18;
    const float midOut = 0.267;
    const float b = (-pow(midIn, a) + pow(hdrMax, a) * midOut) / ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
    const float c = (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) / ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
    return pow(x, a) / (pow(x, a * d) * b + c);
}

vec3 LottesTonemap(vec3 x) {
    return vec3(LottesTonemapF(x.x), LottesTonemapF(x.y), LottesTonemapF(x.z));
}

// Tonemap 4 : Burgess 
vec3 HejlBurgessTonemap(vec3 col)
{
    vec3 Maxima = max(vec3(0.0), col - 0.004);
    vec3 Compute = (Maxima * (6.2 * Maxima + 0.05)) / (Maxima * (6.2 * Maxima + 2.3) + 0.06);
    return Compute;
}

// Tonemap 5 : RomBinDaHouse 
vec3 RomBinDaHouseTonemap(vec3 color)
{
    color = exp( -1.0 / ( 2.72*color + 0.15 ) );
	return color;
}

// Tonemap 6 : Uncharted Tonemap 
vec3 Uncharted2ToneMapping(vec3 color)
{
	float A = 0.15;
	float B = 0.50;
	float C = 0.10;
	float D = 0.20;
	float E = 0.02;
	float F = 0.30;
	float W = 11.2;
	float exposure = 2.;
	color *= exposure;
	color = ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
	float white = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;
	color /= white;
	return color;
}

vec3 PurkinjeEffect(vec3 Color, float Intensity) 
{
	vec3 BaseColor = Color;
    vec3 RodResponse = vec3(7.15e-5f, 4.81e-1f, 3.28e-1f);
    vec3 XYZ = rgbToXYZ(Color);
    vec3 ScopticLuma = XYZ * (1.33f * (1.0f + (XYZ.y + XYZ.z) / XYZ.x) - 1.68f);
    float Purkinge = dot(RodResponse, xyzToRGB(ScopticLuma));
    Color = mix(Color, Purkinge * vec3(0.5f, 0.7f, 1.0f), exp2(-Purkinge * 2.0f));
    return mix(max(Color, 0.0), BaseColor, clamp(1.0f-Intensity,0.0f,1.0f));
}

// main 
void main()
{
    ivec2 Pixel = ivec2(gl_FragCoord.xy);

    vec3 Color = vec3(0.0f);

    vec4 RawSample = texelFetch(u_MainTexture, Pixel, 0);

    float LinearDepth = LinearizeDepth(RawSample.w);
    
    //vec4 DOFSample = texture(u_DOF, v_TexCoords).xyzw;

    Color = RawSample.xyz;

    if (u_DOFEnabled) {
       
        vec4 DOFSampleCubic = Bicubic(u_DOF, v_TexCoords).xyzw;
        float BlurScale = clamp(DOFSampleCubic.w, 0.0f, 1.0f);
        Color = mix(RawSample.xyz, DOFSampleCubic.xyz, BlurScale);

    }

    if (u_PurkinjeStrength > 0.0000001f) {
        Color = PurkinjeEffect(Color, clamp(sqrt(clamp(exp(u_SunDirection.y),0.0f, 1.0f))*u_PurkinjeStrength,0.,1.));
    }

    float EffectiveExposure = 0.825f * u_Exposure; 
    Color *= EffectiveExposure;

    switch (u_SelectedTonemap) {
        
        case 0 : {
            Color = ACESFitted(Color); // <3 
            break;
        }

        case 1 : {
            Color = TonemapTonyMcMapface(Color); // <3 
            break;
        }

        case 2 : {
            Color = ACESFilmic(Color); // :|
            break;
        }

        case 3 : {
            Color = LottesTonemap(Color); // :|
            break;
        }

        case 4 : {
            Color = HejlBurgessTonemap(Color); // :) 
            break;
        }

        case 5 : {
            Color = RomBinDaHouseTonemap(Color); // :)
            break;
        }

        case 6 : {
            Color = Uncharted2ToneMapping(Color); // -_-
            break;
        }

        default : 
            Color = Color; // >:(
            break;
    }

    o_Color = Color;
    o_Color = clamp(o_Color, 0.0f, 1.0f);
}
