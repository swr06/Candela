project(imgui)

add_library(imgui imgui.cpp imgui_draw.cpp imgui_impl_glfw.cpp imgui_impl_opengl3.cpp imgui_widgets.cpp)
target_include_directories(imgui PUBLIC .)
target_link_libraries(imgui PUBLIC glad::glad)
add_library(imgui::imgui ALIAS imgui)