set(V2LIN_SOURCES
    lkernelLib.c
    ltaskLib.c
    lmsgQLib.c
    lsemLib.c
    lwdLib.c
    v2ldebug.c
    v2ltime.c
)

set(V2LIN_MAIN_SOURCE main_impl.c)

add_library(v2lin SHARED ${V2LIN_SOURCES})
add_library(v2lin_static STATIC ${V2LIN_SOURCES})
set_target_properties(v2lin_static PROPERTIES OUTPUT_NAME v2lin)

add_library(v2linmain SHARED ${V2LIN_MAIN_SOURCE})
add_library(v2linmain_static STATIC ${V2LIN_MAIN_SOURCE})
set_target_properties(v2linmain_static PROPERTIES OUTPUT_NAME v2linmain)

set(V2LIN_ALL_LIB_TARGETS
    v2lin
    v2lin_static
    v2linmain
    v2linmain_static
)

foreach(target IN LISTS V2LIN_ALL_LIB_TARGETS)
  target_include_directories(${target}
    PUBLIC
      ${PROJECT_SOURCE_DIR}/lib
  )

  target_compile_definitions(${target}
    PRIVATE
      _GNU_SOURCE
      _USR_SYS_INIT_KILL
  )

  target_compile_options(${target}
    PRIVATE
      ${V2LIN_COMMON_COMPILE_FLAGS}
      ${V2LIN_COMMON_WARNING_FLAGS}
  )
endforeach()

target_link_libraries(v2lin PUBLIC ${V2LIN_PLATFORM_LIBS})
target_link_libraries(v2linmain PRIVATE v2lin ${V2LIN_PLATFORM_LIBS})

set_target_properties(v2lin v2linmain
  PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib
)

set_target_properties(v2lin_static v2linmain_static
  PROPERTIES
    ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib
)

install(TARGETS v2lin v2linmain v2lin_static v2linmain_static
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
