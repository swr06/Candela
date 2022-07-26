#version 330 core

#include "Include/Utility.glsl"

in vec2 v_TexCoords;
layout(location = 0) out vec3 o_Color;

uniform sampler2D u_MainTexture;
uniform sampler2D u_DOF;

uniform bool u_DOFEnabled;

uniform float u_zNear;
uniform float u_zFar;

uniform float u_FocusDepth;

uniform bool u_PerformanceDOF;

uniform float u_GrainStrength;

uniform float u_Time;

const float DOFBlurSize = 20.0f;
const float DOFScale = 0.04f;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

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

vec4 ACESFitted(vec4 Color, float Exposure)
{
    Color.rgb *= Exposure;
    
    Color.rgb = ACESInputMat * Color.rgb;
    Color.rgb = RRTAndODTFit(Color.rgb);
    Color.rgb = ACESOutputMat * Color.rgb;

    return Color;
}

void main()
{
    ivec2 Pixel = ivec2(gl_FragCoord.xy);

    vec4 RawSample = texelFetch(u_MainTexture, Pixel, 0);

    float LinearDepth = LinearizeDepth(RawSample.w);
    
    //vec4 DOFSample = texture(u_DOF, v_TexCoords).xyzw;

    o_Color = RawSample.xyz;

    if (u_DOFEnabled) {
       
        vec4 DOFSampleCubic = Bicubic(u_DOF, v_TexCoords).xyzw;
        float BlurScale = clamp(DOFSampleCubic.w, 0.0f, 1.0f);
        o_Color = mix(RawSample.xyz, DOFSampleCubic.xyz, BlurScale);

    }

    o_Color.xyz = ACESFitted(vec4(o_Color.xyz, 1.0f), 0.8f).xyz;
    o_Color = clamp(o_Color, 0.0f, 1.0f);
}
