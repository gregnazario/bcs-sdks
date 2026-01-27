cmake_minimum_required(VERSION 3.14)
project(bcs VERSION 0.1.0 LANGUAGES CXX)

# C++17 required
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Header-only library
add_library(bcs INTERFACE)
target_include_directories(bcs INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)

# Alias for FetchContent usage
add_library(bcs::bcs ALIAS bcs)

# Testing
option(BCS_BUILD_TESTS "Build BCS tests" ON)
if(BCS_BUILD_TESTS)
    enable_testing()
    
    # Test executable
    add_executable(test_bcs tests/test_bcs.cpp)
    target_link_libraries(test_bcs PRIVATE bcs)
    target_include_directories(test_bcs PRIVATE tests)
    
    # Register test
    add_test(NAME bcs_tests COMMAND test_bcs)
endif()

# Installation
include(GNUInstallDirs)
install(TARGETS bcs
    EXPORT bcsTargets
    INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(DIRECTORY include/bcs
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(EXPORT bcsTargets
    FILE bcsTargets.cmake
    NAMESPACE bcs::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bcs
)

# Package configuration
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/bcsConfigVersion.cmake"
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/bcsConfig.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/bcsConfig.cmake"
    INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bcs
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/bcsConfig.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/bcsConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bcs
)
