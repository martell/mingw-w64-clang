# Mingw-w64-Clang

__The llvm port of mingw-w64.__

Now self contained in a unified alpine Docker script :)

The stack is as follows.

*  [__Compiler__] : __llvm__ __clang__ __clang++__
*  [__Linker__] : __lld__
* [__C__ __Runtime__] : __compiler-rt__ __mingw-w64__
* [__C++__ __Runtime__] : __libc++__ __libc++abi__
* [__Exceptions__] : __libunwind__

Work has and will continue to be upstreamed where possible

### Todos

 - __libcxx__ - enable test suite testing on cross compile
 - __mingw-w64__ - add support for aarch64 when devices become available
 - __wine__ - update alpine wine to 3.0 on release so x64 can test properly


### Status

 - llvm - __works__
 - clang - __works__
 - clang++ - __works__
 - compiler-rt - __works__
 - mingw-w64 - __works__
 - libcxx - __builds__
 - libcxxabi - __works__
 - libunwind - __works__ (needs support for seh but dwarf works and sjlj for i686)
