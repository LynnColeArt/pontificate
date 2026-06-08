cmake_minimum_required(VERSION 3.20)

project(Pontificate VERSION 0.0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC OFF)

find_package(Qt5 5.15 REQUIRED COMPONENTS Core Gui Widgets)
find_program(ZIG_EXECUTABLE zig REQUIRED)

set(PONTIFICATE_ZIG_RUNTIME_LIBS "")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64|amd64)$")
    if(EXISTS "/lib/x86_64-linux-gnu/libquadmath.so.0")
        set(PONTIFICATE_QUADMATH_LIBRARY "/lib/x86_64-linux-gnu/libquadmath.so.0")
    else()
        file(GLOB PONTIFICATE_QUADMATH_CANDIDATES
            "/usr/lib/gcc/x86_64-linux-gnu/*/libquadmath.a"
        )
        list(SORT PONTIFICATE_QUADMATH_CANDIDATES COMPARE NATURAL ORDER DESCENDING)
        if(PONTIFICATE_QUADMATH_CANDIDATES)
            list(GET PONTIFICATE_QUADMATH_CANDIDATES 0 PONTIFICATE_QUADMATH_LIBRARY)
        endif()
    endif()
    if(NOT PONTIFICATE_QUADMATH_LIBRARY)
        message(FATAL_ERROR "Could not find libquadmath for Zig static library link")
    endif()
    file(GLOB PONTIFICATE_CLANG_BUILTINS_CANDIDATES
        "/usr/lib/llvm-*/lib/clang/*/lib/linux/libclang_rt.builtins-x86_64.a"
    )
    list(SORT PONTIFICATE_CLANG_BUILTINS_CANDIDATES COMPARE NATURAL ORDER DESCENDING)
    if(PONTIFICATE_CLANG_BUILTINS_CANDIDATES)
        list(GET PONTIFICATE_CLANG_BUILTINS_CANDIDATES 0 PONTIFICATE_CLANG_BUILTINS_LIBRARY)
    endif()
    if(NOT PONTIFICATE_CLANG_BUILTINS_LIBRARY)
        message(FATAL_ERROR "Could not find clang_rt.builtins-x86_64 for Zig static library link")
    endif()
    list(APPEND PONTIFICATE_ZIG_RUNTIME_LIBS
        "${PONTIFICATE_QUADMATH_LIBRARY}"
        "${PONTIFICATE_CLANG_BUILTINS_LIBRARY}"
    )
endif()

set(PONTIFICATE_ZIG_PREFIX "${CMAKE_BINARY_DIR}/zig")
set(PONTIFICATE_ZIG_LIB "${PONTIFICATE_ZIG_PREFIX}/lib/libpontificate_core.a")

add_custom_command(
    OUTPUT "${PONTIFICATE_ZIG_LIB}"
    COMMAND "${ZIG_EXECUTABLE}" build install --prefix "${PONTIFICATE_ZIG_PREFIX}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    DEPENDS
        "${CMAKE_SOURCE_DIR}/build.zig"
        "${CMAKE_SOURCE_DIR}/build.zig.zon"
        "${CMAKE_SOURCE_DIR}/core/include/pontificate_core.h"
        "${CMAKE_SOURCE_DIR}/core/src/main.zig"
        "${CMAKE_SOURCE_DIR}/core/src/media.zig"
        "${CMAKE_SOURCE_DIR}/core/src/pontificate.zig"
        "${CMAKE_SOURCE_DIR}/core/src/project.zig"
        "${CMAKE_SOURCE_DIR}/core/src/timeline.zig"
    VERBATIM
)

add_custom_target(pontificate_core_build DEPENDS "${PONTIFICATE_ZIG_LIB}")

add_library(pontificate_core STATIC IMPORTED GLOBAL)
set_target_properties(pontificate_core PROPERTIES
    IMPORTED_LOCATION "${PONTIFICATE_ZIG_LIB}"
    INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/core/include"
)
add_dependencies(pontificate_core pontificate_core_build)

add_executable(pontificate
    ui/src/main.cpp
)

target_link_libraries(pontificate PRIVATE
    Qt5::Core
    Qt5::Gui
    Qt5::Widgets
    pontificate_core
    ${PONTIFICATE_ZIG_RUNTIME_LIBS}
)

target_link_options(pontificate PRIVATE
    "$<$<PLATFORM_ID:Linux>:-Wl,-z,noexecstack>"
)

target_include_directories(pontificate PRIVATE
    "${CMAKE_SOURCE_DIR}/core/include"
)
