#version 330 core
#define INF 100000.0f

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

layout(location = 0) out vec3 o_Color;

in vec2 v_TexCoords;

uniform sampler2D u_FramebufferTexture;
uniform sampler2D u_PositionTexture;
uniform sampler2D u_NormalTexture;
uniform sampler2D u_BlockIDTex;

uniform mat4 u_InverseView;
uniform mat4 u_InverseProjection;
uniform vec2 u_Dimensions;
uniform bool u_ExponentiallyMagnifyColorDifferences;


vec2 TexCoords;

bool CompareFloatNormal(float x, float y) {
    return abs(x - y) < 0.02f;
}

vec3 GetNormalFromID(float n) {
	const vec3 Normals[6] = vec3[]( vec3(0.0f, 0.0f, 1.0f), vec3(0.0f, 0.0f, -1.0f),
					vec3(0.0f, 1.0f, 0.0f), vec3(0.0f, -1.0f, 0.0f), 
					vec3(-1.0f, 0.0f, 0.0f), vec3(1.0f, 0.0f, 0.0f));
    int idx = int(round(n*10.0f));

    if (idx > 5) {
        return vec3(1.0f, 1.0f, 1.0f);
    }

    return Normals[idx];
}

vec3 SampleNormalFromTex(sampler2D samp, vec2 txc) { 
    return GetNormalFromID(texture(samp, txc).x);

}
vec3 GetRayDirectionAt(vec2 screenspace)
{
	vec4 clip = vec4(screenspace * 2.0f - 1.0f, -1.0, 1.0);
	vec4 eye = vec4(vec2(u_InverseProjection * clip), -1.0, 0.0);
	return vec3(u_InverseView * eye);
}

vec4 SamplePositionAt(vec2 txc)
{
	vec3 O = u_InverseView[3].xyz;
	float Dist = 1./texture(u_PositionTexture, txc).r;
	return vec4(O + normalize(GetRayDirectionAt(txc)) * Dist, Dist);
}

int GetBlockAt(vec2 txc)
{
	float id = texture(u_BlockIDTex, txc).r;
	return clamp(int(floor(id * 255.0f)), 0, 127);
}

float GetLuminance(vec3 color) 
{
	return dot(color, vec3(0.299, 0.587, 0.114));
}


vec3 Reinhard(vec3 RGB )
{
    return vec3(RGB) / (vec3(1.0f) + GetLuminance(RGB));
}

vec3 InverseReinhard(vec3 RGB)
{
    return RGB / (vec3(1.0f) - GetLuminance(RGB));
}

float GetLuminosityWeightFXAA(vec3 color, bool edge, bool skyedge, vec2 txc) 
{
	// Amplify subpixel differences ->
	bool ShouldAmplifyLess = true;

	if (skyedge && !u_ExponentiallyMagnifyColorDifferences) {
		ShouldAmplifyLess = true;
	}

	if (edge) 
	{
		if (ShouldAmplifyLess) {
			color = pow(exp(color * 1.0f), vec3(1.5f));
		}

		else {
			color = pow(exp(color * 2.4f), vec3(4.0f));
		}
	}

	float LuminanceRaw = dot(color, vec3(0.299, 0.587, 0.114));
	return LuminanceRaw;
}

float GetLuminosityWeightFXAANoBias(vec3 color, bool edge, vec2 txc) 
{
	float LuminanceRaw = dot(color, vec3(0.299, 0.587, 0.114));
	return LuminanceRaw;
}

float quality[12] = float[12] (1.0, 1.0, 1.0, 1.0, 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0, 8.0);


bool DetectEdge(out bool skysample, out float BaseDepth)
{
	BaseDepth = texture(u_PositionTexture, TexCoords).x;
	vec3 BaseNormal = SampleNormalFromTex(u_NormalTexture, TexCoords).xyz;
	vec3 BaseColor = texture(u_FramebufferTexture, TexCoords).xyz;
	vec2 TexelSize = 1.0f / textureSize(u_FramebufferTexture, 0);
	int BaseBlock = GetBlockAt(TexCoords);
	skysample = false;

	for (int x = -1 ; x <= 1 ; x++)
	{
		for (int y = -1 ; y <= 1 ; y++)
		{
			vec2 SampleCoord = TexCoords + vec2(x, y) * TexelSize;
			float SampleDepth = texture(u_PositionTexture, SampleCoord).x;
			vec3 SampleNormal = SampleNormalFromTex(u_NormalTexture, SampleCoord).xyz;
			float PositionError = abs(BaseDepth - SampleDepth);//distance(BasePosition, SamplePosition.xyz);
			int SampleBlock = GetBlockAt(SampleCoord);

			if (SampleDepth < 0.0f) {
				skysample = true;
			}

			if (BaseNormal != SampleNormal ||
				PositionError > 0.9f ||
				SampleBlock != BaseBlock) 
			{
				return true;
			}
		}
	}

	return false;
}



void FXAA311(inout vec3 color) 
{
	float edgeThresholdMin = 0.03125;
	float edgeThresholdMax = 0.125;
	bool skysample = false; 
	float bd = 0.0f;
	bool IsAtEdge = DetectEdge(skysample, bd);
	float subpixelQuality = IsAtEdge ? 0.55f : 0.1f; 
	bool skyedge = skysample;

	int iterations = 12;
	vec2 texCoord = TexCoords;

	//if (IsAtEdge) {
	//	color = vec3(1.0f, 0.0f, 0.0f);
	//	return;
	//}
	
	vec2 view = 1.0 / vec2(textureSize(u_FramebufferTexture, 0));
	
	float lumaCenter = GetLuminosityWeightFXAA(color, IsAtEdge, skyedge, texCoord);
	float lumaDown  = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, texCoord + vec2( 0.0, -1.0) * view, 0.0).rgb, IsAtEdge, skyedge, texCoord + vec2( 0.0, -1.0) * view);
	float lumaUp    = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, texCoord + vec2( 0.0,  1.0) * view, 0.0).rgb, IsAtEdge, skyedge, texCoord + vec2( 0.0,  1.0) * view);
	float lumaLeft  = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, texCoord + vec2(-1.0,  0.0) * view, 0.0).rgb, IsAtEdge, skyedge, texCoord + vec2(-1.0,  0.0) * view);
	float lumaRight = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, texCoord + vec2( 1.0,  0.0) * view, 0.0).rgb, IsAtEdge, skyedge, texCoord + vec2( 1.0,  0.0) * view);
	
	float lumaMin = min(lumaCenter, min(min(lumaDown, lumaUp), min(lumaLeft, lumaRight)));
	float lumaMax = max(lumaCenter, max(max(lumaDown, lumaUp), max(lumaLeft, lumaRight)));
	
	float lumaRange = lumaMax - lumaMin;
	
	if (lumaRange > max(edgeThresholdMin, lumaMax * edgeThresholdMax)) {
		float lumaDownLeft  = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, texCoord + vec2(-1.0, -1.0) * view, 0.0).rgb, IsAtEdge, skyedge, texCoord + vec2(-1.0, -1.0) * view);
		float lumaUpRight   = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, texCoord + vec2( 1.0,  1.0) * view, 0.0).rgb, IsAtEdge, skyedge, texCoord + vec2( 1.0,  1.0) * view);
		float lumaUpLeft    = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, texCoord + vec2(-1.0,  1.0) * view, 0.0).rgb, IsAtEdge, skyedge, texCoord + vec2(-1.0,  1.0) * view);
		float lumaDownRight = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, texCoord + vec2( 1.0, -1.0) * view, 0.0).rgb, IsAtEdge, skyedge, texCoord + vec2( 1.0, -1.0) * view);
		
		float lumaDownUp    = lumaDown + lumaUp;
		float lumaLeftRight = lumaLeft + lumaRight;
		
		float lumaLeftCorners  = lumaDownLeft  + lumaUpLeft;
		float lumaDownCorners  = lumaDownLeft  + lumaDownRight;
		float lumaRightCorners = lumaDownRight + lumaUpRight;
		float lumaUpCorners    = lumaUpRight   + lumaUpLeft;
		
		float edgeHorizontal = abs(-2.0 * lumaLeft   + lumaLeftCorners ) +
							   abs(-2.0 * lumaCenter + lumaDownUp      ) * 2.0 +
							   abs(-2.0 * lumaRight  + lumaRightCorners);
		float edgeVertical   = abs(-2.0 * lumaUp     + lumaUpCorners   ) +
							   abs(-2.0 * lumaCenter + lumaLeftRight   ) * 2.0 +
							   abs(-2.0 * lumaDown   + lumaDownCorners );
		
		bool isHorizontal = (edgeHorizontal >= edgeVertical);		
		
		float luma1 = isHorizontal ? lumaDown : lumaLeft;
		float luma2 = isHorizontal ? lumaUp : lumaRight;
		float gradient1 = luma1 - lumaCenter;
		float gradient2 = luma2 - lumaCenter;
		
		bool is1Steepest = abs(gradient1) >= abs(gradient2);
		float gradientScaled = 0.25 * max(abs(gradient1), abs(gradient2));
		
		float stepLength = isHorizontal ? view.y : view.x;

		float lumaLocalAverage = 0.0;

		if (is1Steepest) {
			stepLength = - stepLength;
			lumaLocalAverage = 0.5 * (luma1 + lumaCenter);
		} else {
			lumaLocalAverage = 0.5 * (luma2 + lumaCenter);
		}
		
		vec2 currentUv = texCoord;
		if (isHorizontal) {
			currentUv.y += stepLength * 0.5;
		} else {
			currentUv.x += stepLength * 0.5;
		}
		
		vec2 offset = isHorizontal ? vec2(view.x, 0.0) : vec2(0.0, view.y);
		
		vec2 uv1 = currentUv - offset;
		vec2 uv2 = currentUv + offset;

		float lumaEnd1 = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, uv1, 0.0).rgb, IsAtEdge, skyedge, uv1);
		float lumaEnd2 = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, uv2, 0.0).rgb, IsAtEdge, skyedge, uv2);
		lumaEnd1 -= lumaLocalAverage;
		lumaEnd2 -= lumaLocalAverage;
		
		bool reached1 = abs(lumaEnd1) >= gradientScaled;
		bool reached2 = abs(lumaEnd2) >= gradientScaled;
		bool reachedBoth = reached1 && reached2;
		
		if (!reached1) {
			uv1 -= offset;
		}
		if (!reached2) {
			uv2 += offset;
		}
		
		if (!reachedBoth) {
			for(int i = 2; i < iterations; i++) {
				if (!reached1) {
					lumaEnd1 = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, uv1, 0.0).rgb, IsAtEdge, skyedge, uv1);
					lumaEnd1 = lumaEnd1 - lumaLocalAverage;
				}
				if (!reached2) {
					lumaEnd2 = GetLuminosityWeightFXAA(textureLod(u_FramebufferTexture, uv2, 0.0).rgb, IsAtEdge, skyedge, uv2);
					lumaEnd2 = lumaEnd2 - lumaLocalAverage;
				}
				
				reached1 = abs(lumaEnd1) >= gradientScaled;
				reached2 = abs(lumaEnd2) >= gradientScaled;
				reachedBoth = reached1 && reached2;

				if (!reached1) {
					uv1 -= offset * quality[i];
				}
				if (!reached2) {
					uv2 += offset * quality[i];
				}
				
				if (reachedBoth) break;
			}
		}
		
		float distance1 = isHorizontal ? (texCoord.x - uv1.x) : (texCoord.y - uv1.y);
		float distance2 = isHorizontal ? (uv2.x - texCoord.x) : (uv2.y - texCoord.y);

		bool isDirection1 = distance1 < distance2;
		float distanceFinal = min(distance1, distance2);

		float edgeThickness = (distance1 + distance2);

		float pixelOffset = - distanceFinal / edgeThickness + 0.5f;
		
		bool isLumaCenterSmaller = lumaCenter < lumaLocalAverage;

		bool correctVariation = ((isDirection1 ? lumaEnd1 : lumaEnd2) < 0.0) != isLumaCenterSmaller;

		float finalOffset = correctVariation ? pixelOffset : 0.0;
		
		float lumaAverage = (1.0 / 12.0) * (2.0 * (lumaDownUp + lumaLeftRight) + lumaLeftCorners + lumaRightCorners);
		float subPixelOffset1 = clamp(abs(lumaAverage - lumaCenter) / lumaRange, 0.0, 1.0);
		float subPixelOffset2 = (-2.0 * subPixelOffset1 + 3.0) * subPixelOffset1 * subPixelOffset1;
		float subPixelOffsetFinal = subPixelOffset2 * subPixelOffset2 * subpixelQuality;

		finalOffset = max(finalOffset, subPixelOffsetFinal);
		
		
		// Compute the final UV coordinates.
		vec2 finalUv = texCoord;
		if (isHorizontal) {
			finalUv.y += finalOffset * stepLength;
		} else {
			finalUv.x += finalOffset * stepLength;
		}

		color = textureLod(u_FramebufferTexture, finalUv, 0.0).rgb;
	}
}



void main()
{
	TexCoords = v_TexCoords;


	vec3 BaseSample = texture(u_FramebufferTexture, TexCoords).rgb;
	vec3 ViewerPos = u_InverseView[3].xyz;
	vec3 BasePos = SamplePositionAt(TexCoords).xyz;
    vec3 Color = BaseSample;
	bool fxaa = false;
	FXAA311(Color);
	o_Color = Color;
}