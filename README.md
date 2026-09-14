# cross_compile

This repository packages `v2lin_v02` and now provides a traditional CMake build
that covers all library, sample, and test binaries.

## Build everything (native Linux)

```bash
cmake -S /home/runner/work/cross_compile/cross_compile -B /home/runner/work/cross_compile/cross_compile/build
cmake --build /home/runner/work/cross_compile/cross_compile/build --parallel
```

## AArch64 cross build from AMD64 Linux

Only AArch64 Linux cross-compilation is supported.

```bash
cmake \
  -S /home/runner/work/cross_compile/cross_compile \
  -B /home/runner/work/cross_compile/cross_compile/build-aarch64 \
  -DCMAKE_TOOLCHAIN_FILE=/home/runner/work/cross_compile/cross_compile/cmake/toolchains/aarch64-linux-gnu.cmake
cmake --build /home/runner/work/cross_compile/cross_compile/build-aarch64 --parallel
```

## Produced targets

- Libraries: `v2lin`, `v2linmain`, `v2lin_static`, `v2linmain_static`
- Samples: `with_sysinit`, `with_main`, `sample_lib`, `load`
- Tests: `test`, `test_sem`, `test_time`, `demo`
