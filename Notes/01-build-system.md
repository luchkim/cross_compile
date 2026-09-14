# 1. The build system

How the makefiles are organised, what each one is responsible for, and how to
change things without breaking the others.

---

## 1.1 Quick reference

Run from the top of the tree:

| Command | Effect |
|---|---|
| `make` | build `lib/`, `samples/` and `tests/` |
| `make lib` | build only `libv2lin.{so,a}` and `libv2linmain.{so,a}` |
| `make samples` | build the example programs |
| `make tests` | build the test programs |
| `make test` (or `make check`) | build everything, then run the suite |
| `make run` | run the sample programs |
| `make install` | install libraries + headers under `$(prefix)` |
| `make uninstall` | remove what `install` put there |
| `make clean` | remove objects, dependency files and build products |
| `make distclean` | `clean` + logs, `tags`, editor backups, core files |
| `make tags` | build a ctags index |
| `make help` | print all of the above |

Build knobs, appended to any command line:

| Knob | Default | Meaning |
|---|---|---|
| `V=1` | `0` | echo full compiler command lines instead of `  CC   foo.o` |
| `DEBUG=1` | `0` | compile in the `TRACEF()`/`TRACEV()` tracing (see note 2) |
| `TRACE_IN_OUT=1` | `0` | additionally trace entry/exit of every `CHK()`-wrapped call |
| `OPTIM=-O2` | `-O0` | optimisation level |
| `CC=<compiler>` | `gcc` | use a specific compiler |
| `CROSS_COMPILE=<prefix>` | empty | toolchain prefix, e.g. `arm-linux-gnueabihf-` (see [1.8](#18-cross-compiling)) |
| `V2LIN_RPATH=` | in-tree rpath | set empty to drop the baked-in rpath when building for a target device |
| `prefix=/usr` | `/usr/local` | install prefix |
| `DESTDIR=/tmp/stage` | empty | staged install root (for packaging) |

Examples:

```sh
make V=1                                  # see exactly what is executed
make DEBUG=1                              # trace-instrumented build of everything
make OPTIM=-O2 DEBUG=0                    # release-ish build
make CROSS_COMPILE=arm-linux-gnueabihf-   # cross-compile for 32-bit ARM
make install prefix=/usr DESTDIR=/tmp/pkg # staged install
```

`tests/` and `samples/` force `-DDEBUG` on regardless of the global `DEBUG`
setting, because everything they report goes through the tracing macros. See
[note 4](04-running-the-tests.md).

---

## 1.2 The three-file contract

Every directory that compiles something follows the same pattern:

```make
top := ..                 # 1. where the source root is, relative to here
include $(top)/defs.mk    # 2. shared configuration
include defs.mk           # 3. this directory's overrides (optional)

...declare what to build...

include $(top)/rules.mk   # 4. shared rules
```

| File | Owns |
|---|---|
| `defs.mk` (top level) | toolchain, flags, install paths, knobs, pretty-printing |
| `<dir>/defs.mk` | per-directory flag overrides only — never rules |
| `rules.mk` | the `%.o: %.c` rule, the link rules, `clean`, `distclean`, dependency inclusion |
| `<dir>/Makefile` | **what** to build, never **how** |

The split matters: if you find yourself writing a compile or link command in a
leaf `Makefile`, the rule belongs in `rules.mk` instead.

### Why `.DEFAULT_GOAL` is set explicitly

`rules.mk` is included *last*, so the `all:` rule it defines is not the first
rule make reads — a leaf `Makefile` that adds prerequisites (e.g.
`$(EXES): ../lib/libv2lin.so`) would otherwise silently become the default
goal and only one target would be built. `defs.mk` therefore pins
`.DEFAULT_GOAL := all`.

---

## 1.3 Declaring targets

A leaf `Makefile` declares targets through three list variables and a
`<target>_OBJS` variable per target:

```make
ARLIBS := libfoo.a          # static archives
SHLIBS := libfoo.so         # shared objects
EXES   := prog              # executables

libfoo.a_OBJS  := a.o b.o
libfoo.so_OBJS := a.o b.o
prog_OBJS      := main.o

prog_LDFLAGS   := -L.       # optional, applied to this target only
prog_LDLIBS    := -lfoo     # optional, applied to this target only

EXTRA_CLEAN    := prog.log  # optional, extra files for `make clean`
```

`rules.mk` turns each entry into a real rule via `$(eval)`, so every target
keeps its own object list and its own link flags. `TARGETS` is derived as
`$(ARLIBS) $(SHLIBS) $(EXES)` and `all:` depends on it.

### Adding a source file

Add the `.o` to the relevant `_OBJS` list. Nothing else. Header dependencies
are discovered automatically.

### Adding a new program

```make
EXES      += mytool
mytool_OBJS := mytool.o helper.o
```

### Adding a new directory

Copy any leaf `Makefile` as a template, set `top` to the right number of
`..`s, and add the directory to `SUBDIRS` in the parent (see
`samples/Makefile`).

---

## 1.4 Automatic header dependencies

Every compile runs with `-MMD -MP -MF $(@:.o=.d)`, producing a `.d` file
alongside each `.o`. `rules.mk` ends with `-include $(DEPS)`.

Consequence: **touching a header rebuilds exactly the objects that include
it** — no `make depend`, no stale-object debugging.

```sh
touch lib/vxw_hdrs.h && make     # rebuilds the 20 objects that include it
```

`make depend` still exists as a no-op so that old scripts do not break.

Objects borrowed from another directory (a prerequisite starting with `../`)
are deliberately excluded from both dependency tracking and `clean` — they
belong to the directory that builds them.

---

## 1.5 Linking and `LD_LIBRARY_PATH`

Every binary is linked with

```
-L../lib -Wl,-rpath,<absolute path of lib/>
```

so the samples and tests find `libv2lin.so` and `libv2linmain.so` on their own:

```sh
./tests/test          # just works
./samples/with_main/with_main
```

The original build required `export LD_LIBRARY_PATH=../lib` before every run.
That is no longer needed. `samples/shared_library/load` additionally gets
`-Wl,-rpath,<its own directory>` because it resolves `libsample_lib.so`
through `dlopen()` at run time, and `dlopen()` searches the RUNPATH of the
calling binary.

The rpath is absolute and points into the build tree, which is right for
development. For distribution, install the libraries properly
(`make install`) and link against `-lv2lin` from `$(libdir)` instead.

---

## 1.6 What gets built

| Artifact | Contents | Link it when |
|---|---|---|
| `lib/libv2lin.so` / `.a` | `ltaskLib`, `lsemLib`, `lmsgQLib`, `lwdLib`, `lkernelLib`, `v2ltime`, `v2ldebug` | always |
| `lib/libv2linmain.so` / `.a` | `main_impl.o` — the default `main()` | your app has `user_sysinit()`/`user_syskill()` instead of a `main()` |
| `samples/with_sysinit` | VxWorks-style entry point | — |
| `samples/with_main/with_main` | plain-Linux entry point | — |
| `samples/shared_library/{load,libsample_lib.so}` | `dlopen()` replacement for `loadModule()` | — |
| `tests/{test,test_sem,test_time,demo}` | see [note 4](04-running-the-tests.md) | — |

Both a shared object and a static archive are produced for each library so you
can choose at link time.

### Deliberately *not* built

| File | Why |
|---|---|
| `lib/loadLib.c`, `lib/taskVarLib.c` | empty stubs for the two VxWorks facilities with no direct POSIX equivalent. Use `dlopen()` and `pthread_key_create()` instead — see `samples/shared_library/` and the `README`. |
| `tests/tasks_sub.c` | a superseded copy of task bodies that now live in `test_msgq.c` / `test_mutexes.c` / `test_semaphores.c`; linking it in produces duplicate-symbol errors. |

---

## 1.7 Notable compiler flags and why they are there

Set in the top-level `defs.mk`:

| Flag | Reason |
|---|---|
| `-D_GNU_SOURCE` | needed for `gettid()`, `pthread_mutex_timedlock()`, `TIMEVAL_TO_TIMESPEC()` and `__BEGIN_DECLS` |
| `-D_USR_SYS_INIT_KILL` | selects the `user_sysinit()`/`user_syskill()` entry-point style over plain `main()` |
| `-fPIC` | the sources go into shared objects |
| `-pthread` | correct threading macros *and* the right link behaviour |
| `-fcommon` | the test programs share globals through tentative definitions in several translation units (`test_child_id`, `queue1_id`, …). That was the default until gcc 10 switched to `-fno-common`. |
| `-Wno-format`, `-Wno-unused-*` | the 2000-2006 sources predate several now-default warnings; they are demoted rather than the code being rewritten |
| `-O0` (default) | the suite is thread-timing sensitive and `-O0` keeps it reproducible and gdb-friendly |

`LDLIBS` is `-pthread -lrt -ldl` everywhere: `-lrt` for `clock_getres()`,
`-ldl` for the `dlopen()` sample.

---

## 1.8 Cross-compiling

Yes — and it works out of the box. Verified for 32-bit ARM (`armhf`) and
64-bit ARM (`aarch64`), both with **zero warnings**, and the cross-built
binaries were then run successfully under `qemu-user`.

```sh
make CROSS_COMPILE=arm-linux-gnueabihf-      # 32-bit ARM
make CROSS_COMPILE=aarch64-linux-gnu-        # 64-bit ARM
```

`CROSS_COMPILE` is the usual kernel-style prefix: it selects `$(CROSS_COMPILE)gcc`
and `$(CROSS_COMPILE)ar`. An explicit `CC=`/`AR=` on the command line still
wins, so the older form also works:

```sh
make CC=arm-linux-gnueabihf-gcc AR=arm-linux-gnueabihf-ar
```

### Building for a real target: drop the rpath

By default every binary carries an **absolute** rpath pointing at this build
tree's `lib/` (see 1.5). That is right for development and wrong for a device.
When the output is going somewhere else, build with:

```sh
make CROSS_COMPILE=aarch64-linux-gnu- V2LIN_RPATH=
make CROSS_COMPILE=aarch64-linux-gnu- V2LIN_RPATH= \
     install DESTDIR=/tmp/rootfs prefix=/usr
```

and rely on the target's normal loader search path (`/usr/lib`, `ld.so.conf`,
or `LD_LIBRARY_PATH`).

### Do not use `make test` on a cross build

`make test` runs the binaries on the build host. For a cross build use plain
`make`, then either copy to the target, or run under emulation:

```sh
qemu-arm -L /usr/arm-linux-gnueabihf -E LD_LIBRARY_PATH=$PWD/lib ./tests/test
```

### Cross-compiling inside Docker

Two approaches, both confirmed working.

**(a) Cross toolchain in an x86-64 container** — fast, no emulation during the
build:

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
        gcc-aarch64-linux-gnu  libc6-dev-arm64-cross \
        qemu-user file \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
```

```powershell
docker build -t v2lin-cross .
docker run --rm -v "${PWD}:/src" v2lin-cross make CROSS_COMPILE=arm-linux-gnueabihf-
```

`qemu-user` in the same image lets you smoke-test without hardware:

```sh
cd tests
qemu-arm -L /usr/arm-linux-gnueabihf -E LD_LIBRARY_PATH=/src/lib ./test_sem
qemu-arm -L /usr/arm-linux-gnueabihf -E LD_LIBRARY_PATH=/src/lib ./test 2> test.log
sh check-log.sh test.log known-failures.txt
```

**(b) A native ARM container via binfmt/QEMU** — no cross toolchain, but every
compiler invocation is emulated, so it is several times slower:

```powershell
docker run --privileged --rm tonistiigi/binfmt --install arm64   # once per boot
docker run --rm --platform linux/arm64 -v "${PWD}:/src" -w /src ubuntu:24.04 `
  bash -lc "apt-get update -qq && apt-get install -y -qq build-essential && make && make test"
```

Approach (b) has one advantage: `make test` actually works, because the
binaries are native to the emulated container.

### Portability notes for other targets

The sources are POSIX + a few Linux specifics, so any Linux target should
work. Things to check on an unusual one:

* `v2ltime.c` reads **`/proc/uptime`** — needs procfs mounted.
* `v2ldebug.c` needs **`SYS_gettid`**, which exists on every Linux port.
* `sysClkRateGet()` uses **`clock_getres()`**, hence `-lrt`.
* On 32-bit targets the `intptr_t` fixes (see
  [note 6](06-file-change-list.md)) are harmless no-ops; on 64-bit they are
  required for correctness.
* musl instead of glibc: the `__GLIBC__` guards around `gettid()` fall through
  to defining the wrapper, which is correct for musl < 1.2.2 and shadows the
  libc symbol harmlessly on newer ones.

---

## 1.9 Building on Windows

v2lin is Linux-only. On a Windows workstation the practical options are WSL2
or a Linux container. A container needs nothing installed in the checkout:

```powershell
# one-off image with a toolchain
docker run --rm -v "${PWD}:/src" -w /src ubuntu:24.04 `
  bash -lc "apt-get update -qq && apt-get install -y -qq build-essential && make && make test"
```

or, keeping a reusable image:

```powershell
docker build -t v2lin-build - <<'EOF'
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends build-essential gdb && rm -rf /var/lib/apt/lists/*
WORKDIR /src
EOF

docker run --rm -v "${PWD}:/src" v2lin-build make test
```

Real-time scheduling is restricted inside a default container, so the library
logs `errno=1 Operation not permitted` when it tries to install `SCHED_FIFO`
priorities. That is harmless for the test suite (see
[note 4](04-running-the-tests.md)); add `--cap-add=sys_nice --ulimit rtprio=99`
if you want the real scheduling behaviour.

MinGW/MSYS `gcc` will **not** work: there is no POSIX `SCHED_FIFO`,
no `/proc/uptime`, and `pthread_mutex_timedlock()` semantics differ.

---

## 1.10 Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `cannot open shared object file: libv2lin.so` | the tree was moved after being built (the rpath is absolute). Run `make clean && make`. |
| Only one target gets built in a directory | a rule was added *before* `include $(top)/defs.mk`, so `.DEFAULT_GOAL` was not yet set. Move the include to the top. |
| `multiple definition of 'x'` when linking a test | a new `.c` was added to `test_OBJS` that re-defines a symbol; check `tests/tasks_sub.c` is not in the list. |
| Edits to a header have no effect | the `.d` files were deleted without deleting the `.o`s. `make clean` fixes it. |
| `Operation not permitted` in a log | `SCHED_FIFO`/`SCHED_RR` needs privilege — see 1.9. |
