#version 330 core 

#define PI 3.14159265359

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;
//in float v_FocusDepth;

uniform sampler2D u_Input;

uniform float u_zNear;
uniform float u_zFar;
uniform float u_FocusDepth;

uniform float u_Time;

const float DOFBlurSize = 20.0f;
const float DOFScale = 0.02f;
const float DOFRadiusScale = 0.5f;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

float GetBlurScale(float Depth, float FocusPoint, float FocusScale) {

	float CircleOfConfusion = abs(clamp((1.0 / FocusPoint - 1.0 / Depth) * FocusScale, -1.0, 1.0));
	return CircleOfConfusion * DOFBlurSize;
}

// Interleaved gradient noise, used for dithering
float GradientNoise()
{
	vec2 coord = gl_FragCoord.xy + mod(6.0f * 100.493850275f * u_Time, 500.0f);
	float noise = fract(52.9829189f * fract(0.06711056f * coord.x + 0.00583715f * coord.y));
	return noise;
}

void main() {
	

	vec4 CenterSample = texture(u_Input, v_TexCoords);
	float LinearZ = LinearizeDepth(CenterSample.w);

	float CenterSize = GetBlurScale(LinearZ, u_FocusDepth, DOFScale);

	vec2 TexelSize = 1.0f / textureSize(u_Input, 0).xy;

	float Radius = DOFRadiusScale;

	vec3 TotalColor = CenterSample.xyz;

	float TotalWeight = 1.0f;

	float Hash = GradientNoise();
	float Theta = Hash * 2.0f * PI;
    float CosTheta = cos(Theta);
    float SinTheta = sin(Theta);
    mat2 RotationMatrix = mat2(vec2(CosTheta, -SinTheta), vec2(SinTheta, CosTheta));


	for (float Angle = 0.0f; Radius < DOFBlurSize ; Angle += 2.39996323f) {

		vec2 Rotation = vec2(cos(Angle), sin(Angle));
		vec2 SampleCoord = (v_TexCoords + RotationMatrix * Rotation * TexelSize * Radius);

		vec4 Sample = texture(u_Input, SampleCoord);

		float SampleDepth = LinearizeDepth(Sample.w);

		float SampleSize = GetBlurScale(SampleDepth, u_FocusDepth, DOFScale);

		if (SampleDepth > LinearZ) 
		{
			SampleSize = clamp(SampleSize, 0.0f, CenterSize * 1.0f);
		}

		float MixFactor = smoothstep(Radius - 0.5f, Radius + 0.5f, SampleSize);
        TotalColor += mix(TotalColor / TotalWeight, Sample.xyz, MixFactor);
        TotalWeight += 1.0;
        Radius += DOFRadiusScale / Radius;
	}

	o_Color = TotalColor / TotalWeight;
}