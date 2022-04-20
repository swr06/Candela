#pragma once

#include "Object.h"

#include <iostream>

namespace Lumen
{

	class Entity
	{
	public : 
		Entity(Object* object) : m_Object(object)
		{
			m_Model = glm::mat4(1.0f);
			m_EmissiveAmount = 0.0f;
		}

		Object* const m_Object;
		glm::mat4 m_Model;

		float m_EmissiveAmount = 0.0f;
		float m_EntityRoughness = 0.75f;
		float m_EntityMetalness = 0.0f;
	};
}