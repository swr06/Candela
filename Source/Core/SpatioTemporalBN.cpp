// WIP!!

// Based on the work by gao-duan (on github)
// And this paper https://www.arnoldrenderer.com/research/dither_abstract.pdf


// Idea : https://developer.nvidia.com/blog/rendering-in-real-time-with-spatiotemporal-blue-noise-textures-part-1/
//Quote : "Scalar spatiotemporal blue noise textures store a scalar value per pixel
//and are useful for rendering algorithms that want a random scalar value per pixel,
//such as stochastic transparency. You generate these textures by running the void and cluster algorithm in 3D but modify the energy function.
//When calculating the energy between two pixels, you only return the energy value 
//if the two pixels are from the same texture slice(have the same z value) or if 
//they are the same pixel at different points in time(have the same xy value); 
//otherwise, it returns zero.The result is N textures, which are perfectly 
//blue over space, but each pixel individually is also blue over the z axis(time).
//In these textures, the(x, y) planes are spatial dimensions that correspond to screen pixels, 
//and the z axis is the dimension of time.You advance one step down the z dimension each frame."

#include "SpatioTemporalBN.h"
namespace Candela {
	namespace STBN {

		typedef std::vector<std::vector<float>> NoiseData;

		int To1D(int x, int y, int z, int sx, int sy, int sz) {
			return (z * sz * sy) + (y * sx) + x;
		}

		float Minkowski(const std::vector<float>& p, const std::vector<float>& q)
		{
			int D = p.size();
			float Final = 0.0f;

			for (int i = 0; i < p.size(); ++i) {
				Final += glm::pow(glm::abs(p[i] - q[i]), (D / 2.0));
			}

			return Final;
		}


		float EnergyFunction(NoiseData& Data, int Kernel, int cx, int cy, int cz, int sx, int sy, int sz) {

			float SigmaI = 2.1f; 
			float SigmaS = 1.0f; // <- Find by trial and error only.

			for (int px = 0; px < sx; px++) {
				for (int py = 0; py < sy; py++) {
					for (int pz = 0; pz < sz; pz++) {

						int PIndex = To1D(px, py, pz, sx, sy, sz);
						std::vector<float> PthRow = Data[PIndex];

						for (int qx = 0; qx < sx; qx++) {
							for (int qy = 0; qy < sy; qy++) {
								for (int qz = 0; qz < sz; qz++) {

									// Ordered pairs 
									glm::ivec3 A = glm::ivec3(px, py, pz);
									glm::ivec3 B = glm::ivec3(qx, qy, qz);
									float Delta = glm::dot(glm::vec3(A) - glm::vec3(B), glm::vec3(A) - glm::vec3(B));

									int QIndex = To1D(qx, qy, qz, sx, sy, sz);

									if (PIndex == QIndex) {
										continue;
									}

									std::vector<float> QthRow = Data[QIndex];
								
								}
							}
						}

					}
				}
			}
		}

		float* Compute(int Kernel, int x, int y, int z)
		{
			Random Generator;

			float* WhiteNoise, *BlueNoise;

			WhiteNoise = new float[x * y * z];
			BlueNoise = new float[x * y * z];

			for (int i = 0; i < x * y * z; i++) 
			{
				float Noise = Generator.Float();
				int Index = i;
				WhiteNoise[Index] = Noise;
				BlueNoise[Index] = Noise;
			}
		}

	}
}

