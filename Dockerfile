FROM alpine:3.7

WORKDIR /build

RUN apk --no-cache update && apk --no-cache upgrade && apk add --no-cache git

RUN git config --global user.name "Mingw" && \
    git config --global user.email root@localhost

RUN git clone -b release_60 https://github.com/llvm-mirror/llvm.git && \
    cd llvm/tools && \
    git clone -b release_60 https://github.com/llvm-mirror/clang.git && \
    git clone -b release_60 https://github.com/llvm-mirror/lld.git

RUN apk add --no-cache clang clang-dev linux-headers cmake \
    build-base ninja make python2 python2-dev tar

ENV TOOLCHAIN_PREFIX=/build/prefix
ENV CMAKE_BUILD_TYPE=MinSizeRel

COPY ./scripts/build-llvm.sh build-llvm.sh
RUN ./build-llvm.sh $TOOLCHAIN_PREFIX $CMAKE_BUILD_TYPE

ENV ORIG_PATH=$PATH
ENV PATH=$TOOLCHAIN_PREFIX/bin:$ORIG_PATH


RUN git clone git://git.code.sf.net/p/mingw-w64/mingw-w64
ENV TOOLCHAIN_ARCHS="i686 x86_64 armv7"

RUN cd mingw-w64/mingw-w64-headers && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && \
        ../configure --host=$arch-w64-mingw32 \
            --enable-secure-api --enable-idl --prefix= \
            --with-default-win32-winnt=0x600 && \
        DESTDIR=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 make install && cd .. || exit 1; \
    done

# Install the wrapper scripts
COPY wrappers/clang-target-wrapper /build/prefix/bin
RUN cd $TOOLCHAIN_PREFIX/bin && \
    for arch in $TOOLCHAIN_ARCHS; do \
        for exec in clang clang++; do \
            ln -s clang-target-wrapper $arch-w64-mingw32-$exec; \
        done; \
    done

# configure of the crt needs bash :/
RUN apk --no-cache update && apk --no-cache upgrade && apk add --no-cache bash

# Build Mingw-w64 with our freshly built Clang
RUN cd mingw-w64/mingw-w64-crt && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && \
        case $arch in \
        armv7) \
            FLAGS="--disable-lib32 --disable-lib64 --enable-libarm32" \
            ;; \
        i686) \
            FLAGS="--enable-lib32 --disable-lib64" \
            ;; \
        x86_64) \
            FLAGS="--disable-lib32 --enable-lib64" \
            ;; \
        esac && \
        CC=$arch-w64-mingw32-clang CXX=$arch-w64-mingw32-clang++ \
        AS=llvm-as AR=llvm-ar RANLIB=llvm-ranlib DLLTOOL=llvm-dlltool \
        ../configure --prefix= --host=$arch-w64-mingw32 $FLAGS && \
        make && DESTDIR=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 make install && \
        cd .. || exit 1; \
    done

RUN git clone -b release_60 https://github.com/llvm-mirror/compiler-rt.git

#TODO: Support i686 for mingw-w64
#      Martell is working on a patch to force i686 like android does
RUN cd $TOOLCHAIN_PREFIX && ln -s i686-w64-mingw32 i386-w64-mingw32

# Manually build compiler-rt as a standalone project
RUN cd compiler-rt && \
    for arch in $TOOLCHAIN_ARCHS; do \
        buildarchname=$arch && \
        libarchname=$arch && \
        case $arch in \
        armv7) \
            libarchname=arm \
            ;; \
        i686) \
            buildarchname=i386 \
            libarchname=i386 \
            ;; \
        esac && \
        mkdir build-$arch && cd build-$arch && cmake -G"Ninja" \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_AR=$TOOLCHAIN_PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
            -DCMAKE_C_COMPILER_WORKS=1 \
            -DCMAKE_C_COMPILER_TARGET=$buildarchname-windows-gnu \
            -DCOMPILER_RT_DEFAULT_TARGET_ONLY=TRUE \
            ../lib/builtins && \
        ninja && \
        mkdir -p $TOOLCHAIN_PREFIX/lib/clang/6.0.0/lib/windows && \
        cp lib/windows/libclang_rt.builtins-$buildarchname.a $TOOLCHAIN_PREFIX/lib/clang/6.0.0/lib/windows/libclang_rt.builtins-$libarchname.a && \
        cd .. && rm -rf build-$arch || exit 1; \
    done

COPY tests/test.c tests/test-tors.c /build/test/

RUN cd test && \
    for arch in $TOOLCHAIN_ARCHS; do \
        $arch-w64-mingw32-clang test.c -o test-c-$arch.exe || exit 1; \
    done

RUN cd test && \
    for arch in $TOOLCHAIN_ARCHS; do \
        $arch-w64-mingw32-clang test-tors.c -o test-tors-$arch.exe || exit 1; \
    done

RUN git clone -b release_60 https://github.com/llvm-mirror/libcxx.git && \
    git clone -b release_60 https://github.com/llvm-mirror/libcxxabi.git && \
    git clone -b release_60 https://github.com/llvm-mirror/libunwind.git

RUN cd libunwind && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && cmake -G"Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DCMAKE_AR=$TOOLCHAIN_PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
            -DLLVM_NO_OLD_LIBSTDCXX=TRUE \
            -DCXX_SUPPORTS_CXX11=TRUE \
            -DLIBUNWIND_USE_COMPILER_RT=TRUE \
            -DLIBUNWIND_ENABLE_THREADS=TRUE \
            -DLIBUNWIND_ENABLE_SHARED=FALSE \
            -DLIBUNWIND_ENABLE_CROSS_UNWINDING=FALSE \
            -DCMAKE_CXX_FLAGS="-I/build/libcxx/include" \
            .. && \
        ninja && ninja install && \
        cd .. && rm -rf build-$arch || exit 1; \
    done

RUN cd libcxxabi && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && cmake -G"Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DCMAKE_AR=$TOOLCHAIN_PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
            -DLIBCXXABI_USE_COMPILER_RT=ON \
            -DLIBCXXABI_ENABLE_EXCEPTIONS=ON \
            -DLIBCXXABI_ENABLE_THREADS=ON \
            -DLIBCXXABI_INCLUDE_TESTS=OFF \
            -DLIBCXXABI_TARGET_TRIPLE=$arch-w64-mingw32 \
            -DLIBCXXABI_ENABLE_SHARED=OFF \
            -DLIBCXXABI_LIBCXX_INCLUDES=../../libcxx/include \
            -DLLVM_NO_OLD_LIBSTDCXX=TRUE \
            -DCXX_SUPPORTS_CXX11=TRUE \
            -DCMAKE_CXX_FLAGS="-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS" \
            .. && \
        ninja && \
        cd .. || exit 1; \
    done

COPY patches/libcxx/0001-libcxx-Move-Windows-threading-support-into-a-.cpp-fi.patch /build/
RUN cd libcxx && git am ../0001-libcxx-Move-Windows-threading-support-into-a-.cpp-fi.patch

RUN cd libcxx && \
    for arch in $TOOLCHAIN_ARCHS; do \
        mkdir build-$arch && cd build-$arch && cmake -G"Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=$TOOLCHAIN_PREFIX/$arch-w64-mingw32 \
            -DCMAKE_C_COMPILER=$arch-w64-mingw32-clang \
            -DCMAKE_CXX_COMPILER=$arch-w64-mingw32-clang++ \
            -DCMAKE_CROSSCOMPILING=TRUE \
            -DCMAKE_SYSTEM_NAME=Windows \
            -DCMAKE_C_COMPILER_WORKS=TRUE \
            -DCMAKE_CXX_COMPILER_WORKS=TRUE \
            -DCMAKE_AR=$TOOLCHAIN_PREFIX/bin/llvm-ar \
            -DCMAKE_RANLIB=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
            -DLIBCXX_USE_COMPILER_RT=ON \
            -DLIBCXX_INSTALL_HEADERS=ON \
            -DLIBCXX_ENABLE_EXCEPTIONS=ON \
            -DLIBCXX_ENABLE_THREADS=ON \
            -DLIBCXX_ENABLE_MONOTONIC_CLOCK=ON \
            -DLIBCXX_ENABLE_SHARED=OFF \
            -DLIBCXX_SUPPORTS_STD_EQ_CXX11_FLAG=TRUE \
            -DLIBCXX_HAVE_CXX_ATOMICS_WITHOUT_LIB=TRUE \
            -DLIBCXX_ENABLE_EXPERIMENTAL_LIBRARY=OFF \
            -DLIBCXX_ENABLE_FILESYSTEM=OFF \
            -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=TRUE \
            -DLIBCXX_CXX_ABI=libcxxabi \
            -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include \
            -DLIBCXX_CXX_ABI_LIBRARY_PATH=../../libcxxabi/build-$arch/lib \
            -DCMAKE_CXX_FLAGS="-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS" \
            .. && \
        ninja && ninja install && \
        ../utils/merge_archives.py \
            --ar llvm-ar \
            -o $TOOLCHAIN_PREFIX/$arch-w64-mingw32/lib/libc++.a \
            $TOOLCHAIN_PREFIX/$arch-w64-mingw32/lib/libc++.a \
            $TOOLCHAIN_PREFIX/$arch-w64-mingw32/lib/libunwind.a && \
        cd .. && rm -rf build-$arch || exit 1; \
    done

# TODO: actually install c++ headers into c++
RUN cd $TOOLCHAIN_PREFIX/include && ln -s ../$(echo $TOOLCHAIN_ARCHS | awk '{print $1}')-w64-mingw32/include/c++ .

COPY tests/test.cpp tests/test-exception.cpp /build/test/

RUN cd test && \
    for arch in $TOOLCHAIN_ARCHS; do \
        $arch-w64-mingw32-clang++ test.cpp -o test-cpp-$arch.exe -fno-exceptions -lpsapi || exit 1; \
    done

RUN cd test && \
    for arch in $TOOLCHAIN_ARCHS; do \
        $arch-w64-mingw32-clang++ test-exception.cpp -o test-exception-$arch.exe -lpsapi || exit 1; \
    done

ENV CROSS_TOOLCHAIN_PREFIX=/build/cross
# ENV PATH=$CROSS_TOOLCHAIN_PREFIX-$arch/bin:$ORIG_PATH
ENV AR=llvm-ar
ENV RANLIB=llvm-ranlib
ENV AS=llvm-as
ENV NM=llvm-nm

RUN apk --no-cache update && apk --no-cache upgrade && apk add --no-cache wine

COPY patches/llvm/0001-cmake-Don-t-build-Native-llvm-config-when-cross-comp.patch /build/
RUN cd llvm && git am ../0001-cmake-Don-t-build-Native-llvm-config-when-cross-comp.patch

#COPY patches/llvm/0001-fixup-tblgen.patch /build/
#RUN cd llvm && git am ../0001-fixup-tblgen.patch

COPY patches/llvm/0002-CMAKE-apply-O3-for-mingw-clang.patch /build/
RUN cd llvm && git am ../0002-CMAKE-apply-O3-for-mingw-clang.patch

COPY patches/llvm/0003-CMAKE-disable-mbig-obj-for-mingw-clang-asm.patch /build/
RUN cd llvm && git am ../0003-CMAKE-disable-mbig-obj-for-mingw-clang-asm.patch

#COPY patches/lld/0001-LLD-Protect-COFF.h-from-winnt-defines.patch /build/
#RUN cd llvm/tools/lld && git am ../../../0001-LLD-Protect-COFF.h-from-winnt-defines.patch

# Only cross building to x86_64 for now, change this to add i386/i686 if you wish.
ENV HOST_TOOLCHAIN_ARCHS="x86_64"

# Build LLVM, Clang and LLD for mingw-w64
RUN cd llvm && \
    for arch in $HOST_TOOLCHAIN_ARCHS; do \
        mkdir build-cross-$arch && cd build-cross-$arch && cmake -G"Ninja" \
        -DCMAKE_C_COMPILER=$TOOLCHAIN_PREFIX/bin/$arch-w64-mingw32-clang \
        -DCMAKE_CXX_COMPILER=$TOOLCHAIN_PREFIX/bin/$arch-w64-mingw32-clang++ \
        -DCMAKE_INSTALL_PREFIX=$CROSS_TOOLCHAIN_PREFIX-$arch \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CROSSCOMPILING=TRUE \
        -DCMAKE_SYSTEM_NAME=Windows \
        -DCMAKE_AR=$TOOLCHAIN_PREFIX/bin/llvm-ar \
        -DCMAKE_RANLIB=$TOOLCHAIN_PREFIX/bin/llvm-ranlib \
        -DLLVM_ENABLE_ASSERTIONS=ON \
        -DLLVM_TARGETS_TO_BUILD="ARM;X86" \
        -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
        -DCLANG_DEFAULT_LINKER=lld \
        -DCLANG_DEFAULT_RTLIB=compiler-rt \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_CXX_FLAGS="-D_GNU_SOURCE -Wl,-lpsapi" \
        -DLLVM_CONFIG_PATH=$TOOLCHAIN_PREFIX/bin/llvm-config \
        -DLLVM_TABLEGEN=$TOOLCHAIN_PREFIX/bin/llvm-tblgen \
        -DCLANG_TABLEGEN=$TOOLCHAIN_PREFIX/bin/clang-tblgen \
        -DCMAKE_SYSTEM_PROGRAM_PATH=$TOOLCHAIN_PREFIX/bin \
        -DCMAKE_FIND_ROOT_PATH=$TOOLCHAIN_PREFIX \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        ../ && ninja && ninja install && \
        cd .. && rm -rf build-cross-$arch || exit 1; \
    done

# Transfer mingw-w64-headers
RUN cd mingw-w64/mingw-w64-headers && \
    for host in $HOST_TOOLCHAIN_ARCHS; do \
        for arch in $TOOLCHAIN_ARCHS; do \
            cd build-$arch && \
            DESTDIR=$CROSS_TOOLCHAIN_PREFIX-$host/$arch-w64-mingw32 \
            make install && cd .. || exit 1; \
        done; \
    done

# Install the $TUPLE-clang binaries
COPY wrappers/clang-target-wrapper $CROSS_TOOLCHAIN_PREFIX-i686/bin
RUN for host in $HOST_TOOLCHAIN_ARCHS; do \
        cd $CROSS_TOOLCHAIN_PREFIX-$host/bin && \
        for arch in $TOOLCHAIN_ARCHS; do \
            for exec in clang clang++; do \
                ln -s clang-target-wrapper $arch-w64-mingw32-$exec; \
            done; \
        done; \
    done

# Transfer mingw-w64-crt, libcxx and libcxxabi
RUN cd mingw-w64/mingw-w64-crt && \
    for host in $HOST_TOOLCHAIN_ARCHS; do \
        for arch in $TOOLCHAIN_ARCHS; do \
            cd build-$arch && \
            DESTDIR=$CROSS_TOOLCHAIN_PREFIX-$host/$arch-w64-mingw32 \
            make install && cd .. || exit 1; \
        done; \
    done

# Transfer compiler-rt
RUN cd compiler-rt && \
    for host in $HOST_TOOLCHAIN_ARCHS; do \
        for arch in $TOOLCHAIN_ARCHS; do \
            buildarchname=$arch && \
            libarchname=$arch && \
            case $arch in \
            armv7) \
                libarchname=arm \
                ;; \
            i686) \
                buildarchname=i386 \
                libarchname=i386 \
                ;; \
            esac && \
            mkdir -p $CROSS_TOOLCHAIN_PREFIX-$host/lib/clang/6.0.0/lib/windows && \
            cp $TOOLCHAIN_PREFIX/lib/clang/6.0.0/lib/windows/libclang_rt.builtins-$libarchname.a $CROSS_TOOLCHAIN_PREFIX-$host/lib/clang/6.0.0/lib/windows/libclang_rt.builtins-$libarchname.a && \
            cd .. && rm -rf build-$arch || exit 1; \
        done; \
    done

RUN apk add --no-cache wine freetype
RUN WINEARCH=win64 winecfg

COPY tests/test.c tests/test-tors.c /build/test/

# wine currently fails when calling clang
# https://bugs.winehq.org/show_bug.cgi?id=44061
# fixme:crypt:CRYPT_LoadProvider Failed to load dll L"C:\\windows\\system32\\rsaenh.dll"
# LLVM ERROR: Could not acquire a cryptographic context: Unknown error (0x8009001D)

RUN cd test && \
    for arch in $TOOLCHAIN_ARCHS; do \
        wine64 $CROSS_TOOLCHAIN_PREFIX-x86_64/bin/clang -target x86_64-windows-gnu test.c -o test-c-$arch.exe || exit 1; \
    done

RUN cd test && \
    for arch in $TOOLCHAIN_ARCHS; do \
        wine64 $CROSS_TOOLCHAIN_PREFIX-x86_64/bin/clang -target x86_64-windows-gnu test-tors.c -o test-tors-$arch.exe || exit 1; \
    done
