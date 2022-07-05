#include "ShaderManager.h"
#include <sstream>

static std::unordered_map<std::string, GLClasses::Shader> ShaderManager_ShaderMap;
static std::unordered_map<std::string, GLClasses::ComputeShader> ShaderManager_ShaderMapC;

void Lumen::ShaderManager::CreateShaders()
{
	AddShader("GBUFFER", "Core/Shaders/GeometryVert.glsl", "Core/Shaders/GeometryFrag.glsl");
	AddShader("LIGHTING_PASS", "Core/Shaders/FBOVert.glsl", "Core/Shaders/ColorPass.glsl");
	AddShader("COMPOSITE", "Core/Shaders/FBOVert.glsl", "Core/Shaders/Composite.glsl");
	AddShader("CAS", "Core/Shaders/FBOVert.glsl", "Core/Shaders/CAS.glsl");
	AddShader("DEPTH", "Core/Shaders/DepthVert.glsl", "Core/Shaders/DepthFrag.glsl");
	AddShader("PROBE_FORWARD", "Core/Shaders/ProbeForwardVert.glsl", "Core/Shaders/ProbeForwardFrag.glsl");
	AddComputeShader("DIFFUSE_TRACE", "Core/Shaders/DiffuseTrace.glsl");
	AddComputeShader("SPECULAR_TRACE", "Core/Shaders/SpecularTrace.glsl");
	AddShader("CHECKER_UPSCALE", "Core/Shaders/FBOVert.glsl", "Core/Shaders/CheckerboardReconstruct.glsl");
	AddShader("TEMPORAL", "Core/Shaders/FBOVert.glsl", "Core/Shaders/Temporal.glsl");
	AddShader("MOTION_VECTORS", "Core/Shaders/FBOVert.glsl", "Core/Shaders/MotionVectors.glsl");
	AddShader("SVGF_VARIANCE", "Core/Shaders/FBOVert.glsl", "Core/Shaders/SpatialVariance.glsl");
	AddShader("SPATIAL_FILTER", "Core/Shaders/FBOVert.glsl", "Core/Shaders/SpatialFilter.glsl");
	AddShader("TAA", "Core/Shaders/FBOVert.glsl", "Core/Shaders/TAA.glsl");
	AddShader("VOLUMETRICS", "Core/Shaders/FBOVert.glsl", "Core/Shaders/Volumetrics.glsl");
	AddShader("SPATIAL_UPSCALE", "Core/Shaders/FBOVert.glsl", "Core/Shaders/SpatialUpscale.glsl");
	AddShader("BLOOM_MASK", "Core/Shaders/FBOVert.glsl", "Core/Shaders/BloomMask.glsl");
	AddShader("BLOOM_BLUR", "Core/Shaders/FBOVert.glsl", "Core/Shaders/BloomBlurTwoPass.glsl");
	AddComputeShader("PROBE_UPDATE", "Core/Shaders/UpdateRadianceProbes.glsl");
	AddComputeShader("COPY_VOLUME", "Core/Shaders/CopyVolume.glsl");
	AddComputeShader("COLLISIONS", "Core/Shaders/Collide.comp");
}

void Lumen::ShaderManager::AddShader(const std::string& name, const std::string& vert, const std::string& frag, const std::string& geo)
{
	auto exists = ShaderManager_ShaderMap.find(name);

	if (exists == ShaderManager_ShaderMap.end())
	{
		ShaderManager_ShaderMap.emplace(name, GLClasses::Shader());
		ShaderManager_ShaderMap.at(name).CreateShaderProgramFromFile(vert, frag);
		ShaderManager_ShaderMap.at(name).CompileShaders();
	}

	else
	{
		std::string err = "A shader with the name : " + name + "  already exists!";
		throw err;
	}
}

void Lumen::ShaderManager::AddComputeShader(const std::string& name, const std::string& comp)
{
	auto exists = ShaderManager_ShaderMapC.find(name);

	if (exists == ShaderManager_ShaderMapC.end())
	{
		ShaderManager_ShaderMapC.emplace(name, GLClasses::ComputeShader());
		ShaderManager_ShaderMapC.at(name).CreateComputeShader(comp);
		ShaderManager_ShaderMapC.at(name).Compile();
	}

	else
	{
		std::string err = "A shader with the name : " + name + "  already exists!";
		throw err;
	}
}

GLClasses::Shader& Lumen::ShaderManager::GetShader(const std::string& name)
{
	auto exists = ShaderManager_ShaderMap.find(name);

	if (exists != ShaderManager_ShaderMap.end())
	{
		return ShaderManager_ShaderMap.at(name);
	}

	else
	{
		throw "Shader that doesn't exist trying to be accessed!";
	}
}

GLClasses::ComputeShader& Lumen::ShaderManager::GetComputeShader(const std::string& name)
{
	auto exists = ShaderManager_ShaderMapC.find(name);

	if (exists != ShaderManager_ShaderMapC.end())
	{
		return ShaderManager_ShaderMapC.at(name);
	}

	else
	{
		throw "Shader that doesn't exist trying to be accessed!";
	}
}

GLuint Lumen::ShaderManager::GetShaderID(const std::string& name)
{
	auto exists = ShaderManager_ShaderMap.find(name);

	if (exists != ShaderManager_ShaderMap.end())
	{
		return ShaderManager_ShaderMap.at(name).GetProgramID();
	}

	else
	{
		throw "Shader that doesn't exist trying to be accessed!";
	}
}

void Lumen::ShaderManager::RecompileShaders()
{
	int ShadersRecompiled = 0;
	int ComputeShadersRecompiled = 0;

	for (auto& e : ShaderManager_ShaderMap)
	{
		ShadersRecompiled += (int)e.second.Recompile();
	}

	for (auto& e : ShaderManager_ShaderMapC)
	{
		ComputeShadersRecompiled += (int)e.second.Recompile();
	}
	
	std::cout << "\nShaders Recompiled : " << ShadersRecompiled << "   |   Compute Shaders Recompiled : " << ComputeShadersRecompiled;
}

void Lumen::ShaderManager::ForceRecompileShaders()
{
	for (auto& e : ShaderManager_ShaderMap)
	{
		e.second.ForceRecompile();
	}

	for (auto& e : ShaderManager_ShaderMapC)
	{
		e.second.ForceRecompile();
	}

	std::cout << "\nShaders Recompiled : " << ShaderManager_ShaderMap.size() << "   |   Compute Shaders Recompiled : " << ShaderManager_ShaderMapC.size();
}
