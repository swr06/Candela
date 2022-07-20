// Samples sky visibility using hemispherical shadow maps 
// Used for testing out the hemispherical shadow mapping 

layout(bindless_sampler) uniform sampler2D SkyHemisphericalShadowmaps[32];
uniform mat4 u_SkyShadowMatrices[32]; // <- shadow matrices 

vec2 hash2();

float GetSkyShadowing(vec3 Position, vec3 Normal) {

	Position += Normal * 0.25f;

	float TotalShadowing = 0.0f;

	int Samples = 64;

	for (int i = 0 ; i < Samples ; i++) {
		
		int s = int(mix(0.,32.,hash2().x));

		vec4 ProjectionCoordinates = u_SkyShadowMatrices[s] * vec4(Position, 1.0f);

		if (abs(ProjectionCoordinates.x) < 1.0f && abs(ProjectionCoordinates.y) < 1.0f && ProjectionCoordinates.z < 1.0f 
		    && abs(ProjectionCoordinates.x) < 1.0f && abs(ProjectionCoordinates.y) < 1.0f)
		{
			ProjectionCoordinates.xyz = ProjectionCoordinates.xyz * 0.5f + 0.5f;
			TotalShadowing += 1.0 - float(ProjectionCoordinates.z - 0.00001f > TexelFetchNormalized(SkyHemisphericalShadowmaps[s], ProjectionCoordinates.xy + hash2() * 0.00825).x);
		}
	}
	
	return (TotalShadowing / float(Samples));
}

//o_Color = pow(GetSkyShadowing(WorldPosition, Normal).xxx, 1.0.xxx) * 20. * texture(u_Skymap, mix(vec3(0.0f,1.0f,0.0f),Normal,0.2f)).xyz * Albedo * clamp(dot(Normal, vec3(0.0f,1.0f,0.0)),0.5,1.);
