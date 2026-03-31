# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# TODO: Move the rest of this into files in ephemeral. See
# https://github.com/flutter/flutter/issues/57146.
set(WRAPPER_ROOT "${EPHEMERAL_DIR}/cpp_client_wrapper")

# Set fallback configurations for older versions of the flutter tool.
if (NOT DEFINED FLUTTER_TARGET_PLATFORM)
  set(FLUTTER_TARGET_PLATFORM "windows-x64")
endif()

# === Flutter Library ===
# System-level dependencies.
find_package(OpenGL REQUIRED)

add_library(flutter INTERFACE)
target_include_directories(flutter INTERFACE
  "${EPHEMERAL_DIR}/"
)
target_link_libraries(flutter INTERFACE "${EPHEMERAL_DIR}/flutter_windows.dll.lib")
target_link_libraries(flutter INTERFACE OpenGL::GL)

# === Dart Build Outputs ===
add_custom_target(flutter_assemble DEPENDS
  "${EPHEMERAL_DIR}/flutter_windows.dll"
)

# === Flutter Wrapper ===
list(APPEND CPP_WRAPPER_SOURCES_CORE
  "core_implementations.cc"
  "flutter_view_controller.cc"
)
foreach(source IN LISTS CPP_WRAPPER_SOURCES_CORE)
  list(APPEND CPP_WRAPPER_SOURCES_FULL
    "${WRAPPER_ROOT}/library_implementations/${source}")
endforeach()

list(APPEND CPP_WRAPPER_SOURCES_AND_PLUGIN
  "engine_method_result.cc"
  "plugin_handler.cc"
)
foreach(source IN LISTS CPP_WRAPPER_SOURCES_AND_PLUGIN)
  list(APPEND CPP_WRAPPER_SOURCES_FULL
    "${WRAPPER_ROOT}/library_implementations/${source}")
endforeach()

# Mark wrapper sources as GENERATED so CMake does not check for their
# existence at configure time; they are created by flutter assemble.
set_source_files_properties(${CPP_WRAPPER_SOURCES_FULL}
  PROPERTIES GENERATED TRUE)

add_library(flutter_wrapper_app STATIC
  ${CPP_WRAPPER_SOURCES_FULL}
)
apply_standard_settings(flutter_wrapper_app)
set_target_properties(flutter_wrapper_app PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
set_target_properties(flutter_wrapper_app PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_link_libraries(flutter_wrapper_app PUBLIC flutter)
target_include_directories(flutter_wrapper_app PUBLIC
  "${WRAPPER_ROOT}/include"
)
add_dependencies(flutter_wrapper_app flutter_assemble)

add_library(flutter_wrapper_plugin STATIC
  ${CPP_WRAPPER_SOURCES_FULL}
)
apply_standard_settings(flutter_wrapper_plugin)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  POSITION_INDEPENDENT_CODE ON)
set_target_properties(flutter_wrapper_plugin PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_link_libraries(flutter_wrapper_plugin PUBLIC flutter)
target_include_directories(flutter_wrapper_plugin PUBLIC
  "${WRAPPER_ROOT}/include"
)
add_dependencies(flutter_wrapper_plugin flutter_assemble)
