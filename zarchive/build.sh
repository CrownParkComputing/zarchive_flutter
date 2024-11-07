#!/bin/bash

# Create build directory
mkdir -p build
cd build

# Configure with CMake
cmake ..

# Build
make

# Get the Flutter build mode (debug/release/profile)
BUILD_MODE="debug"
if [ -n "$1" ]; then
    BUILD_MODE="$1"
fi

# Copy library to platform-specific location
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Copy to Flutter's lib directory
    LIB_DIR="../../build/linux/x64/$BUILD_MODE/bundle/lib"
    mkdir -p "$LIB_DIR"
    cp libzarchive.so "$LIB_DIR/"
    
    # Also copy to intermediate build directory for development
    mkdir -p "../../build/linux/x64/$BUILD_MODE/lib/"
    cp libzarchive.so "../../build/linux/x64/$BUILD_MODE/lib/"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    LIB_DIR="../../build/macos/$BUILD_MODE/zarchive_flutter.app/Contents/Frameworks"
    mkdir -p "$LIB_DIR"
    cp libzarchive.dylib "$LIB_DIR/"
else
    LIB_DIR="../../build/windows/$BUILD_MODE"
    mkdir -p "$LIB_DIR"
    cp zarchive.dll "$LIB_DIR/"
fi

echo "Library copied to $LIB_DIR"
