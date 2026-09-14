set(V2LIN_SAMPLE_INCLUDE_DIRS
    ${PROJECT_SOURCE_DIR}/lib
)

add_executable(with_sysinit with_sysinit.c)
add_executable(with_main with_main/with_main.c)
add_library(sample_lib SHARED shared_library/sample_lib.c)
set_target_properties(sample_lib PROPERTIES OUTPUT_NAME sample_lib)

add_executable(sample_load shared_library/load.c)
set_target_properties(sample_load PROPERTIES OUTPUT_NAME load)

set(V2LIN_SAMPLE_TARGETS with_sysinit with_main sample_load)

foreach(target IN LISTS V2LIN_SAMPLE_TARGETS)
  target_include_directories(${target} PRIVATE ${V2LIN_SAMPLE_INCLUDE_DIRS})
  target_compile_definitions(${target} PRIVATE _GNU_SOURCE _USR_SYS_INIT_KILL DEBUG)
  target_compile_options(${target} PRIVATE ${V2LIN_COMMON_COMPILE_FLAGS} ${V2LIN_COMMON_WARNING_FLAGS})
endforeach()

target_include_directories(sample_lib PRIVATE ${PROJECT_SOURCE_DIR}/samples/shared_library)
target_compile_definitions(sample_lib PRIVATE _GNU_SOURCE _USR_SYS_INIT_KILL DEBUG)
target_compile_options(sample_lib PRIVATE ${V2LIN_COMMON_COMPILE_FLAGS} ${V2LIN_COMMON_WARNING_FLAGS})

target_link_libraries(with_sysinit PRIVATE v2linmain v2lin ${V2LIN_PLATFORM_LIBS})
target_link_libraries(with_main PRIVATE v2lin ${V2LIN_PLATFORM_LIBS})
target_link_libraries(sample_load PRIVATE v2lin sample_lib ${V2LIN_PLATFORM_LIBS})
target_link_libraries(sample_lib PRIVATE ${V2LIN_PLATFORM_LIBS})

set_target_properties(sample_load PROPERTIES BUILD_RPATH "$ORIGIN")

set_target_properties(with_sysinit with_main sample_load
  PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/samples
)

set_target_properties(sample_lib
  PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/samples
)
