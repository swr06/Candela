project(crc CXX)
add_library(crc INTERFACE)
target_include_directories(crc INTERFACE .)
add_library(crc::crc ALIAS crc)