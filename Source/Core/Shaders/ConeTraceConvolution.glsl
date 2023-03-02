#version 330 core

layout (location = 0) out vec3 o_Color;

uniform sampler2D u_Texture;
uniform bool u_Direction;
uniform float u_Mip;
uniform float u_MipSize;

in vec2 v_TexCoords;

bool InThresholdedScreenSpace(vec2 x)
{
	const float b = 0.001f;
    return x.x < 1.0f - b && x.x > b && x.y < 1.0f - b && x.y > b;
}

const float GaussianWeightsSmall[11] = float[] (0.000003, 0.000229, 0.005977, 0.060598, 0.24173, 0.382925,	0.24173, 0.060598, 0.005977, 0.000229, 0.000003);

void main()
{
	vec2 Dims = textureSize(u_Texture, int(u_MipSize)).xy;
    vec2 TexelSize = 1.0f / Dims;

    vec3 TotalColor = vec3(0.0f); 
    float TotalWeight = 0.0f;
    vec2 Direction = mix(vec2(0.0f, 1.0f), vec2(1.0f, 0.0f), float(u_Direction));
    
	for (int i = -5; i <= 5; i++)
	{
		vec2 S = v_TexCoords + vec2(i) * Direction * TexelSize;
		if (!InThresholdedScreenSpace(S)) { continue; }
		float CurrentWeight = GaussianWeightsSmall[i + 5];
		TotalColor += textureLod(u_Texture, S, u_Mip).rgb * CurrentWeight;
		TotalWeight += CurrentWeight;
	}
   

    TotalColor /= max(TotalWeight, 0.01f);
    o_Color = TotalColor;
}