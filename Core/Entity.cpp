#include "Entity.h"

#include <unordered_map>

Candela::Entity::Entity(Object* object)
	: m_Object(object)
{
	m_Model = glm::mat4(1.0f);
	m_EmissiveAmount = 0.0f;
	m_IsPhysicsObject = false;
}

Candela::Entity::~Entity()
{

}
