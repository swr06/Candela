#version 330 core

layout (location = 0) out vec3 o_Color;

uniform sampler2D u_Texture;
uniform bool u_Direction;
uniform bool u_Wide;
uniform float u_AspectRatioCorrect;
uniform vec2 u_Dimensions;

in vec2 v_TexCoords;

bool InThresholdedScreenSpace(vec2 x)
{
	const float b = 0.001f;
    return x.x < 1.0f - b && x.x > b && x.y < 1.0f - b && x.y > b;
}

// For kernel size : 8 (-8 -> +8)
const float GaussianWeightsWide[17] = float[] (0.000014, 0.000137, 0.000971, 0.005086, 0.019711, 0.056512, 0.119895, 0.188264, 0.218818, 0.188264, 0.119895, 0.056512, 0.019711, 0.005086, 0.000971, 0.000137, 0.000014);

// For kernel size : 5 (-5 -> +5)
const float GaussianWeightsSmall[11] = float[] (0.000003, 0.000229, 0.005977, 0.060598, 0.24173, 0.382925,	0.24173, 0.060598, 0.005977, 0.000229, 0.000003);

void main()
{
    vec2 TexelSize = 1.0f / u_Dimensions;

    vec3 TotalBloom = vec3(0.0f); 
    float TotalWeight = 0.0f;
    vec2 Direction = mix(vec2(0.0f, 1.0f), vec2(1.0f, 0.0f), float(u_Direction));
    
    if (!u_Wide) {

        for (int i = -5; i <= 5; i++)
        {
            vec2 S = v_TexCoords + vec2(i) * Direction * TexelSize * vec2(u_AspectRatioCorrect, 1.0f);
            if (!InThresholdedScreenSpace(S)) { continue; }
            float CurrentWeight = GaussianWeightsSmall[i + 5];
            TotalBloom += texture(u_Texture, S).rgb * CurrentWeight;
            TotalWeight += CurrentWeight;
        }
    }

    else {
        for (int i = -8; i <= 8; i++)
        {
            vec2 S = v_TexCoords + vec2(i) * Direction * TexelSize * vec2(u_AspectRatioCorrect, 1.0f);
            if (!InThresholdedScreenSpace(S)) { continue; }
            float CurrentWeight = GaussianWeightsWide[i + 8];
            TotalBloom += texture(u_Texture, S).rgb * CurrentWeight;
            TotalWeight += CurrentWeight;
        }
    }

    TotalBloom /= max(TotalWeight, 0.01f);
    o_Color = TotalBloom;

    o_Color.x = isnan(o_Color.x) || isinf(o_Color.x) ? 0.0f : o_Color.x;
    o_Color.y = isnan(o_Color.y) || isinf(o_Color.y) ? 0.0f : o_Color.y;
    o_Color.z = isnan(o_Color.z) || isinf(o_Color.z) ? 0.0f : o_Color.z;
}