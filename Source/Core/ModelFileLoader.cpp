#include "ModelFileLoader.h"

#include <assimp/pbrmaterial.h>
#include <assimp/Importer.hpp>
#include <assimp/scene.h>
#include <assimp/postprocess.h>
#include <chrono>

#include "MeshOptimizer.h"
#include <string>
#include <vector>
#include <array>

#define PACK_U16(lsb, msb) ((uint16_t) ( ((uint16_t)(lsb) & 0xFF) | (((uint16_t)(msb) & 0xFF) << 8) ))

/* Model Loader
Uses the assimp model loading library to load the models. It uses a recursive model to process the meshes and materials
*/

namespace Candela
{
	namespace FileLoader
	{
		static int GlobalMeshCounter = 0;
		static bool is_gltf = false;

		static int IndexCounter = 0;
		static int VertexCounter = 0;

		std::vector<_MeshMaterialData> MeshTextureReferences;

		void LoadMaterialTextures(aiMesh* mesh, aiMaterial* mat, Mesh* _mesh, const std::string& path)
		{
			std::filesystem::path pth(path);

			std::string texture_path = pth.parent_path().string().c_str();
			aiString material_name;
			aiString diffuse_texture;
			aiString specular_texture;
			aiString normal_texture;
			aiString roughness_texture;
			aiString metallic_texture;
			aiString ao_texture;
			_mesh->m_IsGLTF = is_gltf;

			if (mat->GetTexture(AI_MATKEY_GLTF_PBRMETALLICROUGHNESS_BASE_COLOR_TEXTURE, &diffuse_texture) == aiReturn_SUCCESS)
			{
				std::string pth = texture_path + "/" + diffuse_texture.C_Str();
				_mesh->TexturePaths[0] = pth;
			}

			else if (mat->GetTexture(aiTextureType_DIFFUSE, 0, &diffuse_texture) == aiReturn_SUCCESS)
			{
				std::string pth = texture_path + "/" + diffuse_texture.C_Str();
				_mesh->TexturePaths[0] = pth;
			}

			if (mat->GetTexture(aiTextureType_NORMALS, 0, &normal_texture) == aiReturn_SUCCESS)
			{
				std::string pth = texture_path + "/" + normal_texture.C_Str();
				_mesh->TexturePaths[1] = pth;
			}


			if (mat->GetTexture(AI_MATKEY_GLTF_PBRMETALLICROUGHNESS_METALLICROUGHNESS_TEXTURE, &metallic_texture) == aiReturn_SUCCESS)
			{
				std::string pth = texture_path + "/" + metallic_texture.C_Str();
				_mesh->TexturePaths[5] = pth;
			}

			else {
				if (mat->GetTexture(aiTextureType_METALNESS, 0, &metallic_texture) == aiReturn_SUCCESS)
				{
					std::string pth = texture_path + "/" + metallic_texture.C_Str();
					_mesh->TexturePaths[3] = pth;
				}

				if (mat->GetTexture(aiTextureType_DIFFUSE_ROUGHNESS, 0, &roughness_texture) == aiReturn_SUCCESS)
				{
					std::string pth = texture_path + "/" + roughness_texture.C_Str();
					_mesh->TexturePaths[2] = pth;
				}
			}

			if (mat->GetTexture(aiTextureType_AMBIENT_OCCLUSION, 0, &ao_texture) == aiReturn_SUCCESS)
			{
				std::string pth = texture_path + "/" + ao_texture.C_Str();
				_mesh->TexturePaths[4] = pth;
			}

			aiColor4D diffuse_color;
			aiGetMaterialColor(mat, AI_MATKEY_COLOR_DIFFUSE, &diffuse_color);

			_MeshMaterialData meshmat;
			meshmat.Albedo = _mesh->TexturePaths[0];
			meshmat.Normal = _mesh->TexturePaths[1];
			meshmat.ModelColor = glm::vec3(diffuse_color[0], diffuse_color[1], diffuse_color[2]);
			MeshTextureReferences.push_back(meshmat);
		}

		void ProcessAssimpMesh(aiMesh* mesh, const aiScene* scene, Object* object, const std::string& pth, const glm::vec4& col, const glm::vec3& reflectivity)
		{
			Mesh& _mesh = object->GenerateMesh();
			_mesh.GlobalMeshNumber = GlobalMeshCounter;
			GlobalMeshCounter++;
			std::vector<Vertex>& vertices = _mesh.m_Vertices;
			std::vector<GLuint>& indices = _mesh.m_Indices;

			for (int i = 0; i < mesh->mNumVertices; i++)
			{
				VertexCounter++;

				Vertex vt;
				vt.position = glm::vec4(glm::vec3(
					mesh->mVertices[i].x,
					mesh->mVertices[i].y,
					mesh->mVertices[i].z
				), 1.);

				glm::vec3 vnormal = glm::vec3(0.0f), vtan = glm::vec3(0.0f);

				if (mesh->HasNormals())
				{
					vnormal = glm::vec3(
						mesh->mNormals[i].x,
						mesh->mNormals[i].y,
						mesh->mNormals[i].z
					);
				}

				if (mesh->mTextureCoords[0])
				{
					vt.texcoords = glm::packHalf2x16(glm::vec2(
						mesh->mTextureCoords[0][i].x,
						mesh->mTextureCoords[0][i].y
					));

					if (mesh->mTangents)
					{
						vtan.x = mesh->mTangents[i].x;
						vtan.y = mesh->mTangents[i].y;
						vtan.z = mesh->mTangents[i].z;
					}
				}

				else
				{
					vt.texcoords = glm::packHalf2x16(glm::vec2(0.0f, 0.0f));
				}

				glm::uvec3 data;
				data.x = glm::packHalf2x16(glm::vec2(vnormal.x, vnormal.y));
				data.y = glm::packHalf2x16(glm::vec2(vnormal.z, vtan.x));
				data.z = glm::packHalf2x16(glm::vec2(vtan.y, vtan.z));
				vt.normal_tangent_data = data;
				vertices.push_back(vt);
			}

			/* Push back the indices */
			for (int i = 0; i < mesh->mNumFaces; i++)
			{
				aiFace face = mesh->mFaces[i];

				for (unsigned int j = 0; j < face.mNumIndices; j++)
				{
					indices.push_back(face.mIndices[j]);
				}

				IndexCounter++;
			}

			/* Load material maps
			- Albedo map
			- Specular map
			- Normal map
			*/

			_mesh.m_Name = mesh->mName.C_Str();

			// process materials
			aiMaterial* material = scene->mMaterials[mesh->mMaterialIndex];
			_mesh.m_Color = col;

			LoadMaterialTextures(mesh, material, &object->m_Meshes.back(), pth);
		}

		uint32_t mesh_count = 0;

		void ProcessAssimpNode(aiNode* Node, const aiScene* Scene, Object* object, const std::string& pth)
		{
			// Process all the meshes in the node
			// Add the transparent meshes to the transparent mesh queue and add all the opaque ones

			for (int i = 0; i < Node->mNumMeshes; i++)
			{
				mesh_count++;
				aiMesh* mesh = Scene->mMeshes[Node->mMeshes[i]];
				aiMaterial* material = Scene->mMaterials[mesh->mMaterialIndex];
				aiColor4D diffuse_color;
				aiGetMaterialColor(material, AI_MATKEY_COLOR_DIFFUSE, &diffuse_color);

				float transparency = 0.0f;

				if (aiGetMaterialFloat(material, AI_MATKEY_OPACITY, &transparency) == AI_FAILURE)
				{
					transparency = 0.0f;
				}

				aiVector3D _reflectivity;

				if (material->Get(AI_MATKEY_COLOR_REFLECTIVE, _reflectivity) == AI_FAILURE)
				{
					_reflectivity = aiVector3D(0.0f);
				}

				glm::vec3 reflectivity = glm::vec3(_reflectivity.x, _reflectivity.y, _reflectivity.z);
				glm::vec4 final_color;
				final_color = glm::vec4(diffuse_color.r, diffuse_color.g, diffuse_color.b, diffuse_color.a);
				ProcessAssimpMesh(mesh, Scene, object, pth,
					final_color, reflectivity);
			}

			for (int i = 0; i < Node->mNumChildren; i++)
			{
				ProcessAssimpNode(Node->mChildren[i], Scene, object, pth);
			}
		}

		void LoadModelFile(Object* object, const std::string& filepath)
		{
			IndexCounter = 0;
			VertexCounter = 0;

			object->Path = filepath;

			if (filepath.find("glb") != std::string::npos || filepath.find("gltf") != std::string::npos)
			{
				is_gltf = true;
			}

			Assimp::Importer importer;

			const aiScene* Scene = importer.ReadFile
			(
				filepath,
				aiProcess_JoinIdenticalVertices |
				aiProcess_Triangulate |
				aiProcess_CalcTangentSpace |
				aiProcess_GenUVCoords |
				aiProcess_FlipUVs |
				aiProcess_GenNormals
			);

			if (!Scene || Scene->mFlags & AI_SCENE_FLAGS_INCOMPLETE || !Scene->mRootNode)
			{
				std::stringstream str;
				str << "ERROR LOADING ASSIMP MODEL (" << filepath << ") ||  ASSIMP ERROR : " << importer.GetErrorString();
				throw "ERROR LOADING ASSIMP MODEL";
				std::cout << "\n\n" << str.str() << "\n\n";
				Logger::Log(str.str());
				return;
			}

			ProcessAssimpNode(Scene->mRootNode, Scene, object, filepath);

			bool optimize = false;

			if (optimize) {
				PartialOptimize(*object);
			}

			else {
				for (auto& e : object->m_Meshes)
				{
					e.m_AlbedoMap.CreateTexture(e.TexturePaths[0], true, true);
					e.m_NormalMap.CreateTexture(e.TexturePaths[1], false, true);
					e.m_RoughnessMap.CreateTexture(e.TexturePaths[2], false, true);
					e.m_MetalnessMap.CreateTexture(e.TexturePaths[3], false, true);
					e.m_AmbientOcclusionMap.CreateTexture(e.TexturePaths[4], false, true);
					e.m_MetalnessRoughnessMap.CreateTexture(e.TexturePaths[5], false, true);
				}
			}

			for (auto& mesh : object->m_Meshes) {

				glm::vec3 AABBMin = glm::vec3(100000.0f);
				glm::vec3 AABBMax = glm::vec3(-100000.0f);

				for (int i = 0; i < mesh.m_Indices.size(); i+=3) {
					
					for (int t = 0; t < 3; t++) {

						AABBMin = glm::min(AABBMin, glm::vec3(mesh.m_Vertices[mesh.m_Indices[i + t]].position));
						AABBMax = glm::max(AABBMax, glm::vec3(mesh.m_Vertices[mesh.m_Indices[i + t]].position));
					}

				}

				FrustumBox b;
				b.CreateBoxMinMax(AABBMin, AABBMax);
				mesh.Box = b;
				mesh.Min = AABBMin;
				mesh.Max = AABBMax;
			}

			object->Min = glm::vec3(100000.0f);
			object->Max = glm::vec3(-100000.0f);

			for (auto& mesh : object->m_Meshes) {
				object->Min = glm::min(object->Min, mesh.Min);
				object->Max = glm::max(object->Max, mesh.Max);
			}

			std::string filename = object->Path;
			size_t Idx = filename.find_last_of("\\/");
			if (std::string::npos != Idx)
			{
				filename.erase(0, Idx + 1);
			}

			std::cout << "\n\nMODEL LOADER : Loaded Model For Object : " << object->m_ObjectID << "    Model filename : " << filename;
			std::cout << "\nMeshes : " << mesh_count << "\nIndices : " << IndexCounter << "\nVertices : " << VertexCounter << "\nTriangles : " << IndexCounter / 3 << "\n";


			object->Buffer();

			mesh_count = 0;
			is_gltf = false;

			
			return;

		}


		std::vector<_MeshMaterialData> GetMeshTexturePaths()
		{
			return MeshTextureReferences;
		}
	}
}
