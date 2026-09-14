cmake_minimum_required(VERSION 3.16)

project(v2lin_v02 LANGUAGES C)

include(GNUInstallDirs)
include(CTest)

if(CMAKE_CROSSCOMPILING AND NOT CMAKE_SYSTEM_PROCESSOR MATCHES "^(aarch64|arm64)$")
  message(FATAL_ERROR "Only aarch64 Linux cross-compilation is supported.")
endif()

set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(V2LIN_COMMON_WARNING_FLAGS
    -Wall
    -Wno-format
    -Wno-unused-label
    -Wno-unused-variable
    -Wno-unused-but-set-variable
    -Wno-unused-function
    -Wno-unused-value
)

set(V2LIN_COMMON_COMPILE_FLAGS
    -fmessage-length=0
    -fcommon
)

if(CMAKE_BUILD_TYPE STREQUAL "")
  set(CMAKE_BUILD_TYPE Debug CACHE STRING "Build type" FORCE)
endif()

find_package(Threads REQUIRED)

set(V2LIN_PLATFORM_LIBS Threads::Threads ${CMAKE_DL_LIBS})
if(UNIX AND NOT APPLE)
  list(APPEND V2LIN_PLATFORM_LIBS rt)
endif()

add_subdirectory(lib)
add_subdirectory(samples)
add_subdirectory(tests)

install(
  FILES
    ${PROJECT_SOURCE_DIR}/lib/vxw_hdrs.h
    ${PROJECT_SOURCE_DIR}/lib/vxw_defs.h
    ${PROJECT_SOURCE_DIR}/lib/v2lpthread.h
    ${PROJECT_SOURCE_DIR}/lib/v2ldebug.h
    ${PROJECT_SOURCE_DIR}/lib/internal.h
    ${PROJECT_SOURCE_DIR}/lib/sysLib.h
    ${PROJECT_SOURCE_DIR}/lib/tickLib.h
    ${PROJECT_SOURCE_DIR}/lib/taskVarLib.h
    ${PROJECT_SOURCE_DIR}/lib/loadLib.h
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/v2lin
)
