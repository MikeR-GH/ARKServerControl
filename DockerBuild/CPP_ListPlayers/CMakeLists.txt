cmake_minimum_required(VERSION 2.6)
project(cpp_listplayers)

add_executable(cpp_listplayers main.cpp)

install(TARGETS cpp_listplayers RUNTIME DESTINATION bin)
