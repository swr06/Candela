#pragma once 

#include <iostream>

#include <glm/glm.hpp>

namespace Candela {

    namespace Maths {
        glm::vec3 GetForwardVector(const glm::mat4& Transform);
        glm::vec3 GetRightVector(const glm::mat4& Transform);
        glm::vec3 GetUpVector(const glm::mat4& Transform);
        glm::mat4 GetRotationMatrix(const glm::mat4& Transform);
        glm::vec3 GetPosition(const glm::mat4& Transform);
        void SetPosition(glm::mat4& oTransform, const glm::vec3& Position);
        glm::vec2 FibonacciLattice(int Iteration, int N);
        glm::vec3 SampleHemisphere(glm::vec3 N, glm::vec2 Hash);
        glm::vec3 CosineHemisphere(glm::vec3 N, glm::vec2 Hash);
    }
}