# 1. The build system

How the makefiles are organised, what each one is responsible for, and how to
change things without breaking the others.

---

## 1.1 Quick reference

Run from the top of the tree:

| Command                       | Effect                                              |
| ----------------------------- | --------------------------------------------------- |
| `make`                        | build `lib/`, `samples/`, `tests/` and `cpp_tests/` |
| `make lib`                    | build only `libv2lin.a` and `libv2linmain.a`        |
| `make samples`                | build the example programs                          |
| `make tests`                  | build the test programs                             |
| `make cpp_tests`              | build the C++ static-library smoke test             |
| `make test` (or `make check`) | build everything, then run the suite                |
| `make run`                    | run the sample programs                             |
| `make install`                | install libraries + headers under `$(prefix)`       |
| `make uninstall`              | remove what `install` put there                     |
| `make clean`                  | remove objects, dependency files and build products |
| `make distclean`              | `clean` + logs, `tags`, editor backups, core files  |
| `make tags`                   | build a ctags index                                 |
| `make help`                   | print all of the above                              |

Build knobs, appended to any command line:

| Knob                 | Default                 | Meaning                                                                       |
| -------------------- | ----------------------- | ----------------------------------------------------------------------------- |
| `DEBUG=1`            | `0`                     | compile in the `TRACEF()`/`TRACEV()` tracing (see note 2)                     |
| `TRACE_IN_OUT=1`     | `0`                     | additionally trace entry/exit of every `CHK()`-wrapped call                   |
| `OPTIM=-O2`          | `-O0`                   | optimisation level                                                            |
| `CC=<compiler>`      | `aarch64-linux-gnu-gcc` | use a specific C compiler                                                     |
| `CXX=<compiler>`     | `aarch64-linux-gnu-g++` | use a specific C++ compiler                                                   |
| `STATIC=0`           | `1`                     | permit dynamic system libraries when the target sysroot lacks static archives |
| `prefix=/usr`        | `/usr/local`            | install prefix                                                                |
| `DESTDIR=/tmp/stage` | empty                   | staged install root (for packaging)                                           |

Examples:

```sh
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

| File                  | Owns                                                                            |
| --------------------- | ------------------------------------------------------------------------------- |
| `defs.mk` (top level) | toolchain, flags, install paths, knobs, pretty-printing                         |
| `<dir>/defs.mk`       | per-directory flag overrides only — never rules                                 |
| `rules.mk`            | the `%.o: %.c` rule, the link rules, `clean`, `distclean`, dependency inclusion |
| `<dir>/Makefile`      | **what** to build, never **how**                                                |

The split matters: if you find yourself writing a compile or link command in a
leaf `Makefile`, the rule belongs in `rules.mk` instead.

### Why `.DEFAULT_GOAL` is set explicitly

`rules.mk` is included _last_, so the `all:` rule it defines is not the first
rule make reads — a leaf `Makefile` that adds prerequisites (e.g.
`$(EXES): ../lib/libv2lin.a`) would otherwise silently become the default
goal and only one target would be built. `defs.mk` therefore pins
`.DEFAULT_GOAL := all`.

---

## 1.3 Declaring targets

A leaf `Makefile` declares targets through three list variables and a
`<target>_OBJS` variable per target:

```make
ARLIBS  := libfoo.a         # static archives
EXES    := prog             # C executables
CXXEXES := cpp_prog         # C++ executables

libfoo.a_OBJS   := a.o b.o
prog_OBJS       := main.o
cpp_prog_OBJS   := main.o

prog_LDFLAGS   := -L.       # optional, applied to this target only
prog_LDLIBS    := -lfoo     # optional, applied to this target only

EXTRA_CLEAN    := prog.log  # optional, extra files for `make clean`
```

`rules.mk` uses GNU Make secondary expansion to resolve each target's
`<target>_OBJS`, `<target>_LDFLAGS`, and `<target>_LDLIBS` variables after
the target name is known. `TARGETS` is derived as `$(ARLIBS) $(EXES)
$(CXXEXES)` and `all:` depends on it.

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

## 1.5 Static linking

Every executable receives the in-tree archive paths explicitly. `STATIC=1`
(the default) also passes `-static`, preventing the cross linker from selecting
a target or host shared object. The resulting samples and tests have no v2lin
runtime loader path or `LD_LIBRARY_PATH` requirement.

Use `STATIC=0` only when the target sysroot deliberately lacks static system
archives; v2lin itself remains archive-only in either mode.

---

## 1.6 What gets built

| Artifact                                        | Contents                                                                         | Link it when                                                         |
| ----------------------------------------------- | -------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `lib/libv2lin.a`                                | `ltaskLib`, `lsemLib`, `lmsgQLib`, `lwdLib`, `lkernelLib`, `v2ltime`, `v2ldebug` | always                                                               |
| `lib/libv2linmain.a`                            | `main_impl.o` — the default `main()`                                             | your app has `user_sysinit()`/`user_syskill()` instead of a `main()` |
| `samples/with_sysinit`                          | VxWorks-style entry point                                                        | —                                                                    |
| `samples/with_main/with_main`                   | plain-Linux entry point                                                          | —                                                                    |
| `samples/shared_library/{load,libsample_lib.a}` | statically linked sample module                                                  | —                                                                    |
| `tests/{test,test_sem,test_time,demo}`          | see [note 4](04-running-the-tests.md)                                            | —                                                                    |
| `cpp_tests/static_smoke`                        | C++ semaphore, message queue, pthread, and tick smoke test                       | —                                                                    |

Only static archives are produced.

### Deliberately _not_ built

| File                                | Why                                                                                                                                                                                      |
| ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `lib/loadLib.c`, `lib/taskVarLib.c` | empty stubs for the two VxWorks facilities with no direct POSIX equivalent. Use `pthread_key_create()` for task-local data; runtime modules are not supported by this static-only build. |
| `tests/tasks_sub.c`                 | a superseded copy of task bodies that now live in `test_msgq.c` / `test_mutexes.c` / `test_semaphores.c`; linking it in produces duplicate-symbol errors.                                |

---

## 1.7 Notable compiler flags and why they are there

Set in the top-level `defs.mk`:

| Flag                           | Reason                                                                                                                                                                                     |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `-D_GNU_SOURCE`                | needed for `gettid()`, `pthread_mutex_timedlock()`, `TIMEVAL_TO_TIMESPEC()` and `__BEGIN_DECLS`                                                                                            |
| `-D_USR_SYS_INIT_KILL`         | selects the `user_sysinit()`/`user_syskill()` entry-point style over plain `main()`                                                                                                        |
| `-pthread`                     | correct threading macros _and_ the right link behaviour                                                                                                                                    |
| `-fcommon`                     | the test programs share globals through tentative definitions in several translation units (`test_child_id`, `queue1_id`, …). That was the default until gcc 10 switched to `-fno-common`. |
| `-Wno-format`, `-Wno-unused-*` | the 2000-2006 sources predate several now-default warnings; they are demoted rather than the code being rewritten                                                                          |
| `-O0` (default)                | the suite is thread-timing sensitive and `-O0` keeps it reproducible and gdb-friendly                                                                                                      |

`LDLIBS` is `-pthread -lrt`: `-lrt` is for `clock_getres()`.

---

## 1.8 AArch64 Linux toolchain

The build is fixed to the GNU AArch64 toolchain. On an AMD64 Linux build host,
install `make`, `gcc-aarch64-linux-gnu`, `binutils-aarch64-linux-gnu`, and
`libc6-dev-arm64-cross`, then run `make` or `make lib`.

The output is for 64-bit ARM Linux. Compile and link checks can run on the
AMD64 build host; execute `make test` and `make run` on a native AArch64 Linux
system.

MinGW/MSYS `gcc` will **not** work: there is no POSIX `SCHED_FIFO`,
no `/proc/uptime`, and `pthread_mutex_timedlock()` semantics differ.

---

## 1.10 Troubleshooting

| Symptom                                          | Cause / fix                                                                                                          |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| static system library missing                    | install the target's static C/C++ development archives, or deliberately build with `STATIC=0`.                       |
| Only one target gets built in a directory        | a rule was added _before_ `include $(top)/defs.mk`, so `.DEFAULT_GOAL` was not yet set. Move the include to the top. |
| `multiple definition of 'x'` when linking a test | a new `.c` was added to `test_OBJS` that re-defines a symbol; check `tests/tasks_sub.c` is not in the list.          |
| Edits to a header have no effect                 | the `.d` files were deleted without deleting the `.o`s. `make clean` fixes it.                                       |
| `Operation not permitted` in a log               | `SCHED_FIFO`/`SCHED_RR` needs privilege — see 1.9.                                                                   |
