include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(MyDataStructure_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(MyDataStructure_setup_options)
  option(MyDataStructure_ENABLE_HARDENING "Enable hardening" ON)
  option(MyDataStructure_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    MyDataStructure_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    MyDataStructure_ENABLE_HARDENING
    OFF)

  MyDataStructure_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR MyDataStructure_PACKAGING_MAINTAINER_MODE)
    option(MyDataStructure_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(MyDataStructure_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(MyDataStructure_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(MyDataStructure_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(MyDataStructure_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(MyDataStructure_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(MyDataStructure_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(MyDataStructure_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(MyDataStructure_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(MyDataStructure_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(MyDataStructure_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(MyDataStructure_ENABLE_PCH "Enable precompiled headers" OFF)
    option(MyDataStructure_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(MyDataStructure_ENABLE_IPO "Enable IPO/LTO" ON)
    option(MyDataStructure_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(MyDataStructure_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(MyDataStructure_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(MyDataStructure_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(MyDataStructure_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(MyDataStructure_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(MyDataStructure_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(MyDataStructure_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(MyDataStructure_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(MyDataStructure_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(MyDataStructure_ENABLE_PCH "Enable precompiled headers" OFF)
    option(MyDataStructure_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      MyDataStructure_ENABLE_IPO
      MyDataStructure_WARNINGS_AS_ERRORS
      MyDataStructure_ENABLE_USER_LINKER
      MyDataStructure_ENABLE_SANITIZER_ADDRESS
      MyDataStructure_ENABLE_SANITIZER_LEAK
      MyDataStructure_ENABLE_SANITIZER_UNDEFINED
      MyDataStructure_ENABLE_SANITIZER_THREAD
      MyDataStructure_ENABLE_SANITIZER_MEMORY
      MyDataStructure_ENABLE_UNITY_BUILD
      MyDataStructure_ENABLE_CLANG_TIDY
      MyDataStructure_ENABLE_CPPCHECK
      MyDataStructure_ENABLE_COVERAGE
      MyDataStructure_ENABLE_PCH
      MyDataStructure_ENABLE_CACHE)
  endif()

  MyDataStructure_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (MyDataStructure_ENABLE_SANITIZER_ADDRESS OR MyDataStructure_ENABLE_SANITIZER_THREAD OR MyDataStructure_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(MyDataStructure_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(MyDataStructure_global_options)
  if(MyDataStructure_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    MyDataStructure_enable_ipo()
  endif()

  MyDataStructure_supports_sanitizers()

  if(MyDataStructure_ENABLE_HARDENING AND MyDataStructure_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR MyDataStructure_ENABLE_SANITIZER_UNDEFINED
       OR MyDataStructure_ENABLE_SANITIZER_ADDRESS
       OR MyDataStructure_ENABLE_SANITIZER_THREAD
       OR MyDataStructure_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${MyDataStructure_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${MyDataStructure_ENABLE_SANITIZER_UNDEFINED}")
    MyDataStructure_enable_hardening(MyDataStructure_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(MyDataStructure_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(MyDataStructure_warnings INTERFACE)
  add_library(MyDataStructure_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  MyDataStructure_set_project_warnings(
    MyDataStructure_warnings
    ${MyDataStructure_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(MyDataStructure_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(MyDataStructure_options)
  endif()

  include(cmake/Sanitizers.cmake)
  MyDataStructure_enable_sanitizers(
    MyDataStructure_options
    ${MyDataStructure_ENABLE_SANITIZER_ADDRESS}
    ${MyDataStructure_ENABLE_SANITIZER_LEAK}
    ${MyDataStructure_ENABLE_SANITIZER_UNDEFINED}
    ${MyDataStructure_ENABLE_SANITIZER_THREAD}
    ${MyDataStructure_ENABLE_SANITIZER_MEMORY})

  set_target_properties(MyDataStructure_options PROPERTIES UNITY_BUILD ${MyDataStructure_ENABLE_UNITY_BUILD})

  if(MyDataStructure_ENABLE_PCH)
    target_precompile_headers(
      MyDataStructure_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(MyDataStructure_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    MyDataStructure_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(MyDataStructure_ENABLE_CLANG_TIDY)
    MyDataStructure_enable_clang_tidy(MyDataStructure_options ${MyDataStructure_WARNINGS_AS_ERRORS})
  endif()

  if(MyDataStructure_ENABLE_CPPCHECK)
    MyDataStructure_enable_cppcheck(${MyDataStructure_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(MyDataStructure_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    MyDataStructure_enable_coverage(MyDataStructure_options)
  endif()

  if(MyDataStructure_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(MyDataStructure_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(MyDataStructure_ENABLE_HARDENING AND NOT MyDataStructure_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR MyDataStructure_ENABLE_SANITIZER_UNDEFINED
       OR MyDataStructure_ENABLE_SANITIZER_ADDRESS
       OR MyDataStructure_ENABLE_SANITIZER_THREAD
       OR MyDataStructure_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    MyDataStructure_enable_hardening(MyDataStructure_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
