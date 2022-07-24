#version 330 core 

layout (location = 0) out vec3 o_Color;

in vec2 v_TexCoords;
in float v_FocusDepth;

uniform sampler2D u_Input;

uniform float u_zNear;
uniform float u_zFar;

const float BlurSize = 20.0f;

float LinearizeDepth(float depth)
{
	return (2.0 * u_zNear) / (u_zFar + u_zNear - depth * (u_zFar - u_zNear));
}

float GetBlurScale(float Depth, float FocusPoint, float FocusScale) {

	float CircleOfConfusion = abs(clamp((1.0 / FocusPoint - 1.0 / Depth) * FocusScale, -1.0, 1.0));
	return CircleOfConfusion * BlurSize;
}

void main() {
	
	const float Scale = 5.0f;

	vec4 CenterSample = texture(u_Input, v_TexCoords);
	float LinearZ = LinearizeDepth(CenterSample.w);

	float CenterSize = GetBlurScale(LinearZ, v_FocusDepth, Scale);

	vec2 TexelSize = 1.0f / textureSize(u_Input, 0).xy;

	float Radius = 0.5f;

	vec3 TotalColor = CenterSample.xyz;

	float TotalWeight = 1.0f;

	for (float Angle = 0.0f; Radius < BlurSize ; Angle += 2.39996323f) {

		vec2 Rotation = vec2(cos(Angle), sin(Angle));
		vec2 SampleCoord = v_TexCoords + Rotation * TexelSize * Radius;

		vec4 Sample = texture(u_Input, SampleCoord);

		float SampleDepth = LinearizeDepth(Sample.w);

		float SampleSize = GetBlurScale(SampleDepth, v_FocusDepth, Scale);

		if (SampleDepth > LinearZ) {

			SampleSize = clamp(SampleSize, 0.0f, CenterSize * 2.0f);

		}

		float MixFactor = smoothstep(Radius - 0.5f, Radius + 0.5f, SampleSize);
        TotalColor += mix(TotalColor / TotalWeight, Sample.xyz, MixFactor);
        TotalWeight += 1.0;
        Radius += 0.5f / Radius;
	}

	o_Color = TotalColor / TotalWeight;
}