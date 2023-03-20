cmake_minimum_required(VERSION 3.11)
project(Candela CXX)

find_package(OpenGL REQUIRED)
find_package(assimp REQUIRED)
find_package(glfw3 REQUIRED)

add_executable(candela
./main.cpp
./Core/ShaderManager.cpp
./Core/FpsCamera.cpp
./Core/ProbeMap.cpp
./Core/Pipeline.cpp
./Core/ModelFileLoader.cpp
./Core/MeshOptimizer.cpp
./Core/Player.cpp
./Core/TAAJitter.cpp
./Core/Object.cpp
./Core/PhysicsIntegrator.cpp
./Core/Physics.cpp
./Core/SkyShadowMap.cpp
./Core/ShadowMapHandler.cpp
./Core/MathsHelpers.cpp
./Core/ProbeGI.cpp
./Core/Shadowmap.cpp
./Core/BVH/Intersector.cpp
./Core/BVH/BVHConstructor.cpp
./Core/OrthographicCamera.cpp
./Core/Mesh.cpp
./Core/Entity.cpp
./Core/ModelRenderer.cpp
./Core/Frustum.cpp
./Core/GLClasses/IndexBuffer.cpp
./Core/GLClasses/Framebuffer.cpp
./Core/GLClasses/VertexBuffer.cpp
./Core/GLClasses/stb_image.cpp
./Core/GLClasses/DepthBuffer.cpp
./Core/GLClasses/Shader.cpp
./Core/GLClasses/ComputeShader.cpp
./Core/GLClasses/CubeTextureMap.cpp
./Core/GLClasses/stb_include.cpp
./Core/GLClasses/FramebufferRed.cpp
./Core/GLClasses/Texture.cpp
./Core/GLClasses/VertexArray.cpp
./Core/GLClasses/Fps.cpp
./Core/GLClasses/TextureArray.cpp
./Core/Application/Application.cpp
./Core/Application/Logger.cpp
./Core/BloomFBO.cpp
./Core/BloomRenderer.cpp
./Core/ShadowRenderer.cpp
./Core/Threadpool.cpp
)

add_subdirectory(Dependencies)

target_link_libraries(candela PRIVATE ${assimp_LIBRARIES} crc::crc glad::glad imgui::imgui imguizmo::imguizmo glfw assimp)
target_include_directories(candela PRIVATE Dependencies/glm)

target_compile_features(candela PRIVATE cxx_std_17)

file(COPY Models DESTINATION ${CMAKE_BINARY_DIR})
file(COPY Core/Shaders DESTINATION ${CMAKE_BINARY_DIR}/Core)
file(COPY Res DESTINATION ${CMAKE_BINARY_DIR})