cmake_minimum_required(VERSION 3.10)
project(zarchive)

# Set C++ standard to C++17
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find zstd library
find_package(PkgConfig REQUIRED)
pkg_check_modules(ZSTD REQUIRED libzstd)

# Create shared library
add_library(zarchive SHARED
    zarchivewriter.cc
    zarchivereader.cc
    zarchive_ffi.cc
    sha_256.cc
)

# Include directories
target_include_directories(zarchive PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${ZSTD_INCLUDE_DIRS}
)

# Link libraries
target_link_libraries(zarchive PRIVATE
    ${ZSTD_LIBRARIES}
)

# Set output name
set_target_properties(zarchive PROPERTIES
    OUTPUT_NAME "zarchive"
    PREFIX "lib"
)

# Install rules
install(TARGETS zarchive
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
