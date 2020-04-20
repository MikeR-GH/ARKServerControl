cmake_minimum_required(VERSION 2.6)
project(cpp_sendcommand)

add_executable(cpp_sendcommand main.cpp)

install(TARGETS cpp_sendcommand RUNTIME DESTINATION bin)
