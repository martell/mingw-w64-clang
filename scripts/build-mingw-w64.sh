#!/bin/sh
set -e
# arguments:defaults
# toolchain_prefix:mingw-w64-toolchain toolchain_archs:i686 x86_64 arm
DEFAULT_PREFIX="$(pwd)/mingw-w64-toolchain"

if [ "$1" != "" ]; then
    TOOLCHAIN_PREFIX="${1}"
else
    TOOLCHAIN_PREFIX="$(pwd)/mingw-w64-cross-toolchain"
fi

if [ "$2" != "" ]; then
    shift
    TOOLCHAIN_ARCHS="$@"
else
    TOOLCHAIN_ARCHS="i686 x86_64 armv7"
fi

cd mingw-w64/mingw-w64-headers
for arch in $TOOLCHAIN_ARCHS; do
    mkdir build-$arch && cd build-$arch
    ../configure --host=$arch-w64-mingw32 \
        --enable-secure-api \
        --enable-idl \
        --prefix= \
        --with-default-win32-winnt=0x600
    DESTDIR=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 make install
    cd .. && rm -rf build-$arch
done
cd ../..


# Build Mingw-w64 with our freshly built Clang
cd mingw-w64/mingw-w64-crt
for arch in $TOOLCHAIN_ARCHS; do
    mkdir build-$arch && cd build-$arch
    case $arch in
    armv7)
        FLAGS="--disable-lib32 --disable-lib64 --enable-libarm32"
        ;;
    i686)
        FLAGS="--enable-lib32 --disable-lib64"
        ;;
    x86_64)
        FLAGS="--disable-lib32 --enable-lib64"
        ;;
    esac
    CC=$arch-w64-mingw32-clang \
    CXX=$arch-w64-mingw32-clang++ \
    AS=llvm-as \
    AR=llvm-ar \
    RANLIB=llvm-ranlib \
    DLLTOOL=llvm-dlltool \
    ../configure \
    --prefix= \
    --host=$arch-w64-mingw32 \
    $FLAGS
    make
    DESTDIR=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 make install
    cd .. && rm -rf build-$arch
done