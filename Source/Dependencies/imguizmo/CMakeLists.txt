project(imguizmo)

add_library(imguizmo ImGuizmo.cpp)
target_link_libraries(imguizmo PUBLIC imgui::imgui)
target_include_directories(imguizmo PRIVATE .)
add_library(imguizmo::imguizmo ALIAS imguizmo)
