# cross_compile

## Learn how `v2lin_v02` cross compiles

This repository currently tracks the learning notes for understanding `v2lin_v02` cross-compilation.

Use this quick workflow in the `v2lin_v02` source tree:

1. Identify the build entrypoint (`Makefile`, `CMakeLists.txt`, or build script).
2. Build with verbose output so the real compiler is visible:
   - Make: `make V=1`
   - CMake: `cmake --build . --verbose`
3. Confirm the cross toolchain prefix from the compile command (for example `arm-linux-gnueabihf-gcc`).
4. Check the key cross-compilation variables:
   - `CC`, `CXX`, `LD`, `AR`, `SYSROOT`, `CFLAGS`, `LDFLAGS`
5. Verify the binary target architecture:
   - `file <output-binary>`
   - `readelf -h <output-binary>`

If step 2 prints host compilers like `gcc`/`clang` without a target prefix, the project is not cross-compiling yet and needs toolchain configuration.
