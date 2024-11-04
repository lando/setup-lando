cmake_minimum_required(VERSION 3.10)
project(setup-lando CXX)

# Determine architecture
if(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
    set(ARCH "arm64")
else()
    set(ARCH "x64")
endif()

message(STATUS "Building for architecture: ${ARCH}")
message(STATUS "Generator platform: ${CMAKE_GENERATOR_PLATFORM}")

# Configure script path and ensure it exists
set(SCRIPT_PATH "${CMAKE_SOURCE_DIR}/../../setup-lando.ps1")
if(NOT EXISTS "${SCRIPT_PATH}")
    message(FATAL_ERROR "setup-lando.ps1 not found at ${SCRIPT_PATH}")
endif()

configure_file(
    "${SCRIPT_PATH}"
    "${CMAKE_BINARY_DIR}/setup-lando.ps1"
    COPYONLY
)

# Ensure the script is in the same directory as the RC file
configure_file(
    "${SCRIPT_PATH}"
    "${CMAKE_CURRENT_SOURCE_DIR}/setup-lando.ps1"
    COPYONLY
)

# Verify script files exist
if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/setup-lando.ps1")
    message(FATAL_ERROR "setup-lando.ps1 not found in source directory after copy")
endif()

if(NOT EXISTS "${CMAKE_BINARY_DIR}/setup-lando.ps1")
    message(FATAL_ERROR "setup-lando.ps1 not found in build directory after copy")
endif()

add_executable(setup-lando WIN32
    setup-lando.cpp
    setup-lando.rc
    setup-lando.manifest
)

# Add Windows SDK include paths
if(MSVC)
    # Get Windows SDK paths from environment or registry
    if(DEFINED ENV{WindowsSdkDir} AND DEFINED ENV{WindowsSDKVersion})
        target_include_directories(setup-lando PRIVATE
            "$ENV{WindowsSdkDir}Include\\$ENV{WindowsSDKVersion}um"
            "$ENV{WindowsSdkDir}Include\\$ENV{WindowsSDKVersion}shared"
            "$ENV{WindowsSdkDir}Include\\$ENV{WindowsSDKVersion}ucrt"
        )
    else()
        message(STATUS "Windows SDK environment variables not found. Using default paths.")
        target_include_directories(setup-lando PRIVATE
            "C:/Program Files (x86)/Windows Kits/10/Include/10.0.22000.0/um"
            "C:/Program Files (x86)/Windows Kits/10/Include/10.0.22000.0/shared"
            "C:/Program Files (x86)/Windows Kits/10/Include/10.0.22000.0/ucrt"
        )
    endif()
endif()

# Add manifest to the executable
if(MSVC)
    set_target_properties(setup-lando PROPERTIES
        LINK_FLAGS "/MANIFEST:NO"
        MANIFEST_FILE "${CMAKE_CURRENT_SOURCE_DIR}/setup-lando.manifest"
    )
endif()

# Create dist directory if it doesn't exist
file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/../../dist")

# Set output path and name
set_target_properties(setup-lando PROPERTIES
    WIN32_EXECUTABLE TRUE
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/../../dist"
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_SOURCE_DIR}/../../dist"
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_SOURCE_DIR}/../../dist"
    OUTPUT_NAME "setup-lando-win-${ARCH}"
)

# Add post-build command to verify the file was created
add_custom_command(TARGET setup-lando POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "Built file: $<TARGET_FILE:setup-lando>"
)
