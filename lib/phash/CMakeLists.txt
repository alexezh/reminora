cmake_minimum_required(VERSION 3.10)
project(PhashCrossCorrelation)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Enable optimization flags
set(CMAKE_CXX_FLAGS_RELEASE "-O3 -DNDEBUG")

# Check for x86_64 architecture and enable POPCNT if available
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
    include(CheckCXXCompilerFlag)
    check_cxx_compiler_flag("-mpopcnt" COMPILER_SUPPORTS_POPCNT)
    if(COMPILER_SUPPORTS_POPCNT)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mpopcnt")
        add_definitions(-D__POPCNT__)
    endif()
endif()

# Create static library
add_library(phash_cross_correlation STATIC
    CrossCorrelation.cpp
    CrossCorrelation.hpp
)

# Public headers
target_include_directories(phash_cross_correlation PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# Example usage (optional test executable)
add_executable(phash_test
    test_main.cpp
)

target_link_libraries(phash_test phash_cross_correlation)

# Installation
install(TARGETS phash_cross_correlation
    ARCHIVE DESTINATION lib
    LIBRARY DESTINATION lib
)

install(FILES CrossCorrelation.hpp
    DESTINATION include/shipwreck/phash
)