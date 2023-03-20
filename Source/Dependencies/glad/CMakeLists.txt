project(glad C)
add_library(glad src/glad.c)
target_include_directories(glad PUBLIC include)
add_library(glad::glad ALIAS glad)