#include "MathsHelpers.h"

#include <glm/gtc/matrix_access.hpp>

namespace Candela {

    namespace Maths {

        const float PHI = 0.5f * (sqrt(5.0f) + 1.0f);
        const float PI = 3.141592653f;


        glm::mat4 GetRotationMatrix(const glm::mat4& Transform)
        {
            glm::vec3 scale = glm::vec3(
                glm::length(glm::vec3(glm::column(Transform, 0))),
                glm::length(glm::vec3(glm::column(Transform, 1))),
                glm::length(glm::vec3(glm::column(Transform, 2))));

            glm::mat4 result = glm::mat4();

            result[0][0] = Transform[0][0] / scale.x;
            result[0][1] = Transform[0][1] / scale.x;
            result[0][2] = Transform[0][2] / scale.x;

            result[1][0] = Transform[1][0] / scale.y;
            result[1][1] = Transform[1][1] / scale.y;
            result[1][2] = Transform[1][2] / scale.y;

            result[2][0] = Transform[2][0] / scale.z;
            result[2][1] = Transform[2][1] / scale.z;
            result[2][2] = Transform[2][2] / scale.z;

            result[3][3] = Transform[3][3];

            return result;

        }

        glm::vec3 GetForwardVector(const glm::mat4& Transform)
        {
            return glm::vec4(0.0f, 0.0f, -1.0f, 1.0f) * glm::inverse(GetRotationMatrix(Transform));
        }

        glm::vec3 GetRightVector(const glm::mat4& Transform)
        {
            return glm::vec4(1.0f, 0.0f, 0.0f, 1.0f) * glm::inverse(GetRotationMatrix(Transform));

        }

        glm::vec3 GetUpVector(const glm::mat4& Transform)
        {
            return glm::vec4(0.0f, 1.0f, 0.0f, 1.0f) * glm::inverse(GetRotationMatrix(Transform));
        }


        glm::vec3 GetPosition(const glm::mat4& Transform)
        {
            return Transform[3] * Transform[3][3];
        }

        void SetPosition(glm::mat4& Transform, const glm::vec3& Position)
        {
            Transform[3][0] = Position.x / Transform[3][3];
            Transform[3][1] = Position.y / Transform[3][3];
            Transform[3][2] = Position.z / Transform[3][3];
        }

        glm::vec2 FibonacciLattice(int Iteration, int N)
        {
            float i = (float)Iteration;
            return glm::vec2((float(i) + 0.5f) / float(N), glm::mod(float(i) / PHI, 1.0f));
        }

        glm::vec3 SampleHemisphere(glm::vec3 N, glm::vec2 Hash) 
        {
            glm::vec2 u = Hash;

            // Angles
            float r = sqrt(1.0 - u.x * u.x);
            float phi = 2.0 * PI * u.y;

            // Basis 
            glm::vec3 B = glm::normalize(glm::cross(N, glm::vec3(0.0, 1.0, 1.0)));
            glm::vec3 T = cross(B, N);

            return normalize(r * std::sin(phi) * B + u.x * N + r * std::cos(phi) * T);
        }


        glm::vec3 CosineHemisphere(glm::vec3 N, glm::vec2 Hash)
        {
            glm::vec2 u = Hash;
            float r = sqrt(u.x);
            float theta = 2.0 * PI * u.y;

            glm::vec3 B = glm::normalize(glm::cross(N, glm::vec3(0.0, 1.0, 1.0)));
            glm::vec3 T = glm::cross(B, N);

            return glm::normalize(r * glm::sin(theta) * B + (float)glm::sqrt(1.0 - u.x) * N + r * glm::cos(theta) * T);
        }


    }

}
