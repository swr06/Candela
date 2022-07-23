bool InsideVolume(vec3 p) { float e = 256.0f; return abs(p.x) < 256 && abs(p.y) < 128 && abs(p.z) < 256 ; } 

bool DDA(sampler3D samp, vec3 origin, vec3 direction, int dist, out vec4 data, out vec3 normal, out vec3 world_pos)
{
	const vec3 BLOCK_CALCULATED_NORMALS[6] = vec3[](vec3(1.0, 0.0, 0.0),vec3(-1.0, 0.0, 0.0),vec3(0.0, 1.0, 0.0),vec3(0.0, -1.0, 0.0),vec3(0.0, 0.0, 1.0),vec3(0.0, 0.0, -1.0));
	world_pos = origin;

	vec3 Temp;
	vec3 VoxelCoord; 
	vec3 FractPosition;

	Temp.x = direction.x > 0.0 ? 1.0 : 0.0;
	Temp.y = direction.y > 0.0 ? 1.0 : 0.0;
	Temp.z = direction.z > 0.0 ? 1.0 : 0.0;
	vec3 plane = floor(world_pos + Temp);

	for (int x = 0; x < dist; x++)
	{
		if (!InsideVolume(world_pos)) {
			break;
		}

		vec3 Next = (plane - world_pos) / direction;
		int side = 0;

		if (Next.x < min(Next.y, Next.z)) {
			world_pos += direction * Next.x;
			world_pos.x = plane.x;
			plane.x += sign(direction.x);
			side = 0;
		}

		else if (Next.y < Next.z) {
			world_pos += direction * Next.y;
			world_pos.y = plane.y;
			plane.y += sign(direction.y);
			side = 1;
		}

		else {
			world_pos += direction * Next.z;
			world_pos.z = plane.z;
			plane.z += sign(direction.z);
			side = 2;
		}

		VoxelCoord = (plane - Temp);
		int Side = ((side + 1) * 2) - 1;
		if (side == 0) {
			if (world_pos.x - VoxelCoord.x > 0.5){
				Side = 0;
			}
		}

		else if (side == 1){
			if (world_pos.y - VoxelCoord.y > 0.5){
				Side = 2;
			}
		}

		else {
			if (world_pos.z - VoxelCoord.z > 0.5){
				Side = 4;
			}
		}

		normal = BLOCK_CALCULATED_NORMALS[Side];
		data = texelFetch(samp, ivec3(VoxelCoord.xyz), 0).xyzw;

		if (data.w > 0.05f)
		{
			return true; 
		}
	}

	return false;
}
