#!/bin/sh
set -e
# arguments:defaults
# toolchain_prefix:mingw-w64-toolchain cmake_build_type:release
DEFAULT_PREFIX="$(pwd)/mingw-w64-toolchain"

if [ "$1" != "" ]; then
    TOOLCHAIN_PREFIX="${1}"
else
    TOOLCHAIN_PREFIX="$(pwd)/mingw-w64-cross-toolchain"
fi

CMAKE_BUILD_TYPE="${2:Release}"

# TODO: check the clang version being used
if [ "$(which clang)" != "" ]; then
    CMAKE_COMPILER="-DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++"
fi

if [ "$(which ninja)" != "" ]; then
    CMAKE_GENERATOR="-G Ninja"
    NINJA=1
fi

# Build LLVM, Clang and LLD
cd llvm
mkdir -p build
cd build
cmake $CMAKE_GENERATOR \
    $CMAKE_COMPILER \
    -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN_PREFIX \
    -DCMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_TARGETS_TO_BUILD="ARM;X86" \
    -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
    -DCLANG_DEFAULT_LINKER=lld \
    -DCLANG_DEFAULT_RTLIB=compiler-rt \
    ../
ninja
ninja install
# clang-tblgen is not part of install so we manually install it.
cp bin/clang-tblgen $TOOLCHAIN_PREFIX/bin/clang-tblgen
# cleanup build folder
cd .. && rm -rf build
