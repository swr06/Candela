#include "Object.h"
#include <cstdlib>
#include <cstdio>

namespace Candela
{
	static uint32_t _CurrentObjectID = 1;

	Object::Object() : m_ObjectID(++_CurrentObjectID)
	{
	
	}

	Object::~Object()
	{

	}

	void Object::Buffer()
	{
		for (auto& e : m_Meshes)
		{
			e.Buffer();
		}
	}

	void Object::ClearCPUSideData()
	{
		for (auto& e : m_Meshes)
		{
			e.m_Indices.clear();
			e.m_Vertices.clear();
		}
	}

	Mesh& Object::GenerateMesh()
	{
		m_Meshes.emplace_back(m_Meshes.size());
		return m_Meshes.back();
	}
}