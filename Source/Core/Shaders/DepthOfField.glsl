#version 430 core 

#define PI 3.14159265359

//#define HQ 1

#include "Include/Utility.glsl"

layout (location = 0) out vec4 o_Color;

layout (std430, binding = 12) restrict buffer CommonUniformData 
{
	float u_Time;
	int u_Frame;
	int u_CurrentFrame;

	mat4 u_ViewProjection;
	mat4 u_Projection;
	mat4 u_View;
	mat4 u_InverseProjection;
	mat4 u_InverseView;
	mat4 u_PrevProjection;
	mat4 u_PrevView;
	mat4 u_PrevInverseProjection;
	mat4 u_PrevInverseView;
	mat4 u_InversePrevProjection;
	mat4 u_InversePrevView;

	vec3 u_ViewerPosition;
	vec3 u_Incident;
	vec3 u_SunDirection;
	vec3 u_LightDirection;

	float u_zNear;
	float u_zFar;
};

in vec2 v_TexCoords;
//in float v_FocusDepth;

uniform sampler2D u_Input;

uniform float u_FocusDepth;

uniform bool u_HQ;

uniform float u_BlurRadius;

uniform float u_DOFScale;
float DOFRadiusScale = u_HQ ? 0.5f : 2.2f;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

float GetBlurScale(float Depth, float FocusPoint, float FocusScale) {

	float CircleOfConfusion = abs(clamp((1.0 / FocusPoint - 1.0 / Depth) * FocusScale, -1.0, 1.0));
	return CircleOfConfusion * u_BlurRadius;
}

// Interleaved gradient noise, used for dithering
float GradientNoise(float Multiplier)
{
	vec2 coord = gl_FragCoord.xy + mod(6.0f * 100.493850275f * Multiplier, 500.0f);
	float noise = fract(52.9829189f * fract(0.06711056f * coord.x + 0.00583715f * coord.y));
	return noise;
}

void main() {
	
	// Based on Dennis Gustafsson's blog on DoF

	vec4 CenterSample = texture(u_Input, v_TexCoords);
	float LinearZ = LinearizeDepth(CenterSample.w);

	float CenterCircle = GetBlurScale(LinearZ, u_FocusDepth, u_DOFScale);

	vec2 TexelSize = 1.0f / textureSize(u_Input, 0).xy;

	float Radius = DOFRadiusScale;

	vec3 TotalColor = CenterSample.xyz;

	float TotalWeight = 1.0f;

	float Hash = GradientNoise(0.0f);
	float Theta = Hash * 2.0f * PI;
	float CosTheta = cos(Theta);
	float SinTheta = sin(Theta);
	mat2 RotationMatrix = mat2(vec2(CosTheta, -SinTheta), vec2(SinTheta, CosTheta));

	int SamplesTaken = 0;

	float MeanDepth = LinearizeDepth(CenterSample.w);
	float MinDepth = MeanDepth;
	float UseCircle = Radius;
	float DepthWeights = 1.0f;

	for (float Angle = 0.0f; Radius < u_BlurRadius ; Angle += 2.39996323f) {


		vec2 Rotation = vec2(cos(Angle), sin(Angle));
		vec2 SampleCoord = (v_TexCoords + RotationMatrix * Rotation * TexelSize * Radius);

		if (SampleCoord != clamp(SampleCoord, 0.0f, 1.0f)) {
			continue;
		}

		vec4 Sample = TexelFetchNormalized(u_Input, SampleCoord);

		float SampleDepth = LinearizeDepth(Sample.w);

		float SampleCircle = GetBlurScale(SampleDepth, u_FocusDepth, u_DOFScale);

		UseCircle = max(UseCircle, SampleCircle);

		if (SampleDepth > LinearZ) 
		{
			SampleCircle = clamp(SampleCircle, 0.0f, CenterCircle * 2.0f);
		}

		float MixFactor = smoothstep(Radius - 0.5f, Radius + 0.5f, SampleCircle);
		
		//MeanDepth += mix(MeanDepth / DepthWeights, SampleDepth, MixFactor);

		MinDepth = min(MinDepth, SampleDepth);


		MeanDepth += SampleDepth;
        DepthWeights += 1.0;

        TotalColor += mix(TotalColor / TotalWeight, Sample.xyz, MixFactor);
        TotalWeight += 1.0;

		SamplesTaken++;
        Radius += DOFRadiusScale / Radius;
	}

	MeanDepth /= DepthWeights;

	o_Color.xyz = TotalColor / TotalWeight;
	o_Color.w = clamp(UseCircle / clamp((u_BlurRadius - 5.0f), 0.0f, 128.0f), 0.0f, 4.0f); 

	///GetBlurScale(MinDepth, u_FocusDepth, 0.05f) / DOFBlurSize;
	//o_Color.w = GetBlurScale(MeanDepth, u_FocusDepth, 0.01f) / DOFBlurSize;
}