// Original shader by mrharicot

#version 330 core

#define SIGMA 10.0
#define MSIZE 15

layout (location = 0) out vec3 o_Color;

uniform sampler2D u_Texture;

uniform vec2 u_SketchSize;
uniform float u_BSIGMA = 0.9;

float normpdf(in float x, in float sigma)
{
	return 0.39894f * exp(-0.5f * x * x / (sigma * sigma)) / sigma;
}

float normpdf3(in vec3 v, in float sigma)
{
	return 0.39894f * exp(-0.5f * dot(v,v) / (sigma*sigma)) / sigma;
}

void main(void)
{
	vec3 c = texture2D(u_Texture, vec2(0.0, 0.0) + (gl_FragCoord.xy / u_SketchSize.xy)).rgb;
		
	//const int kSize = (MSIZE - 1) / 2;
	const int kSize = 4;
	vec3 final_colour = vec3(0.0);
	
	float Z = 0.0;

	// TODO : Precompute and store this
	/*
	float kernel[MSIZE];
	
	for (int j = 0; j <= kSize; ++j)
	{
		kernel[kSize + j] = kernel[kSize - j] = normpdf(float(j), SIGMA);
	}*/

	// Precalculated kernet of size 15
	const float kernel[MSIZE] = float[MSIZE]
	(
			0.031225216, 0.033322271, 0.035206333, 
			0.036826804, 0.038138565, 0.039104044,
			0.039695028, 0.039894000, 0.039695028,
			0.039104044, 0.038138565, 0.036826804, 
			0.035206333, 0.033322271, 0.031225216
	);
	
	vec3 cc;
	float factor;
	float bZ = 1.0 / normpdf(0.0, u_BSIGMA);

	//read out the texels
	for (int i = -kSize; i <= kSize; ++i)
	{
		for (int j = -kSize; j <= kSize; ++j)
		{
			cc = texture2D(u_Texture, vec2(0.0, 0.0) + ( gl_FragCoord.xy + vec2(float(i),float(j))) / u_SketchSize.xy).rgb;
			factor = normpdf3(cc - c, u_BSIGMA) * bZ * kernel[kSize + j] * kernel[kSize + i];
			Z += factor;
			final_colour += factor * cc;

		}
	}
	
	o_Color = vec3(final_colour / Z);
}