set(V2LIN_TEST_COMMON_SOURCES
    test.c
    test_tasks.c
    test_semaphores.c
    test_msgq.c
    test_watchdog.c
    test_mutexes.c
)

add_executable(v2lin_test ${V2LIN_TEST_COMMON_SOURCES})
set_target_properties(v2lin_test PROPERTIES OUTPUT_NAME test)
add_executable(test_sem test_sem.c)
add_executable(test_time test_time.c)
add_executable(demo demo.c)

set(V2LIN_TEST_TARGETS v2lin_test test_sem test_time demo)

foreach(target IN LISTS V2LIN_TEST_TARGETS)
  target_include_directories(${target}
    PRIVATE
      ${PROJECT_SOURCE_DIR}/lib
      ${PROJECT_SOURCE_DIR}/tests
  )

  target_compile_definitions(${target}
    PRIVATE
      _GNU_SOURCE
      _USR_SYS_INIT_KILL
      DEBUG
  )

  target_compile_options(${target}
    PRIVATE
      ${V2LIN_COMMON_COMPILE_FLAGS}
      ${V2LIN_COMMON_WARNING_FLAGS}
  )

  target_link_libraries(${target}
    PRIVATE
      v2linmain
      v2lin
      ${V2LIN_PLATFORM_LIBS}
  )
endforeach()

set_target_properties(v2lin_test test_sem test_time demo
  PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/tests
)

if(BUILD_TESTING)
  add_test(NAME v2lin-test-time COMMAND $<TARGET_FILE:test_time>)
  add_test(NAME v2lin-test-sem COMMAND $<TARGET_FILE:test_sem>)
endif()
