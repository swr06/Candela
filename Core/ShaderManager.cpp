#include "ShaderManager.h"
#include <sstream>

static std::unordered_map<std::string, GLClasses::Shader> ShaderManager_ShaderMap;
static std::unordered_map<std::string, GLClasses::ComputeShader> ShaderManager_ShaderMapC;

void Lumen::ShaderManager::CreateShaders()
{
	AddShader("GBUFFER", "Core/Shaders/GeometryVert.glsl", "Core/Shaders/GeometryFrag.glsl");
	AddShader("LIGHTING_PASS", "Core/Shaders/FBOVert.glsl", "Core/Shaders/ColorPass.glsl");
	AddShader("FINAL", "Core/Shaders/FBOVert.glsl", "Core/Shaders/FBOFrag.glsl");
	AddShader("DEPTH", "Core/Shaders/DepthVert.glsl", "Core/Shaders/DepthFrag.glsl");
	AddShader("PROBE_FORWARD", "Core/Shaders/ProbeForwardVert.glsl", "Core/Shaders/ProbeForwardFrag.glsl");
	AddComputeShader("DIFFUSE_TRACE", "Core/Shaders/DiffuseTrace.glsl");
	AddShader("CHECKER_UPSCALE", "Core/Shaders/FBOVert.glsl", "Core/Shaders/CheckerboardReconstruct.glsl");
	AddShader("TEMPORAL", "Core/Shaders/FBOVert.glsl", "Core/Shaders/Temporal.glsl");
	
	AddComputeShader("DDGI_RAYGEN", "Core/Shaders/DDGI/DDGIGenerateRays.glsl");
	AddComputeShader("DDGI_RT", "Core/Shaders/DDGI/DDGIRaytrace.glsl");
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
	for (auto& e : ShaderManager_ShaderMap)
	{
		e.second.Recompile();
	}

	for (auto& e : ShaderManager_ShaderMapC)
	{
		e.second.Recompile();
	}
}
