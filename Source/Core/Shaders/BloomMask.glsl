#version 330 core

layout (location = 0) out vec3 o_Color; 

in vec2 v_TexCoords;

uniform sampler2D u_Texture;
uniform sampler2D u_EmissiveData;

float GetLuminance(vec3 color) 
{
    return dot(color, vec3(0.299, 0.587, 0.114));
}

bool FloatEqual(float x, float y) {
    return abs(x-y) < 0.05f;
}

void main()
{
    vec3 Fetch = texture(u_Texture, v_TexCoords).rgb;
    float E = texture(u_EmissiveData, v_TexCoords).w;
    //float L = GetLuminance(Fetch);
    //o_Color = L > 16.0f ? Fetch : vec3(0.);
    o_Color = E * 0.15f * Fetch;
    o_Color = max(o_Color, 0.0000000001f);
}