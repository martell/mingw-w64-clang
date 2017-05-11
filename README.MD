# Mingw-w64-Clang

__The llvm port of mingw-w64.__


The stack is as follows.

*  [__Compiler__] : __llvm__ __clang__ __clang++__
*  [__Linker__] : __lld__
* [__C__ __Runtime__] : __compiler-rt__ __mingw-w64__
* [__C++__ __Runtime__] : __libc++__ __libc++abi__
* [__Exceptions__] : __libunwind__

Work has and will continue to be upstreamed where possible

### Todos

 - __compiler-rt__ - partial arm divide functions for arm
 - __libcxx__ - get test suite running and make mingw-w64 pass
 - __llvm clang__ - rebuilds with self already :) need to fix libcxx and test properly
 - __mingw-w64__ - missing some arm headers and defs support still


### Status

 - llvm - __works__
 - clang - __works__
 - clang++ - __works__
 - compiler-rt - __partially working__ - (missing __armv7__ divide patches)
 - mingw-w64 - __works__
 - libcxx - __builds__
 - libcxxabi - __works__
 - libunwind - __not working__