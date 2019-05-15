cmake_minimum_required(VERSION 2.6)
project(cpp_stopserver)

add_executable(cpp_stopserver main.cpp)

install(TARGETS cpp_stopserver RUNTIME DESTINATION bin)
