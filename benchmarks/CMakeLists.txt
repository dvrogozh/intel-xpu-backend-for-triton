cmake_minimum_required(VERSION 3.18 FATAL_ERROR)
#XeTLA need 20
set(CMAKE_CXX_STANDARD 20)

project(TritonBenchmark)

if(NOT WIN32)
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
endif()

find_package(Python3 COMPONENTS Interpreter)
find_package(Torch REQUIRED)
find_library(TORCH_PYTHON_LIBRARY torch_python PATH "${TORCH_INSTALL_PREFIX}/lib")
find_package(IPEX REQUIRED)


# add the XeTLA kernel.
add_subdirectory(xetla_kernel)
