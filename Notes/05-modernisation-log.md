# 5. Modernisation log

Exactly what was changed in this tree to make the 2006 sources build, link and
run on a current Linux toolchain (verified with gcc 13.3 / glibc 2.39 /
GNU Make 4.3 on Ubuntu 24.04, x86-64).

Everything here is either a build-system change or the minimum source change
needed to compile or link. No API behaviour was redesigned.

---

## 5.1 Build system — rewritten

| File | Change |
|---|---|
| `defs.mk` | Rewritten. Toolchain selection, install paths, `DEBUG`/`TRACE_IN_OUT`/`OPTIM`/`V` knobs, `CPPFLAGS` vs `CFLAGS` separation, `V2LIN_RPATH`, `.DEFAULT_GOAL`. |
| `rules.mk` | Rewritten. Pattern rule with automatic dependency generation; `$(eval)`-generated link rules for static libs, shared libs and executables; `clean`/`distclean`. |
| `Makefile` | Rewritten. Orchestration, `install`/`uninstall`, `help`. |
| `lib/Makefile` | Rewritten declaratively; now also builds static archives. |
| `tests/Makefile` | Rewritten; adds `test_time`, `demo`, and per-program `run-*` targets with a real pass/fail verdict. |
| `samples/Makefile`, `samples/with_main/Makefile`, `samples/shared_library/Makefile` | Rewritten declaratively; added `run` targets. |
| `*/defs.mk` | Converted from `CFLAGS+=-DDEBUG` to `CPPFLAGS += -DDEBUG`, with comments explaining why the override exists. |
| `tests/check-log.sh` | **New.** Turns a test log into a verdict against a known-failures baseline. |
| `tests/known-failures.txt` | **New.** The six pre-existing test failures, annotated. |

### Defects in the old build that this fixes

1. **`make depend` ran everywhere, including directories with no `.c` files**,
   producing `cc1: fatal error: *.c: No such file or directory` on every top-level
   build. Dependencies are now a side effect of compiling.
2. **`clean` used `$(shell ls *.c)`**, which failed the same way, and was
   defined in both `Makefile` and `rules.mk` — every run started with
   `warning: overriding recipe for target 'clean'`.
3. **The `lib%.so:` pattern rule referenced `$(LDFLAGS-lib%.so)`**, which is not
   valid variable syntax and always expanded to nothing.
4. **Header dependencies were regenerated wholesale into `.deps.mk`** by a rule
   that raced with compilation; editing a header often did not rebuild anything.
5. **Executables were linked by make's built-in rules**, so link flags could not
   be set per target.
6. **`LDFLAGS` carried `-l` libraries**, which places them before the objects on
   the command line — order-dependent and fragile. Libraries now live in
   `LDLIBS`.
7. **Every run required `export LD_LIBRARY_PATH=../lib`.** Binaries now carry an
   rpath.
8. **`make` recursed with `make` rather than `$(MAKE)`**, losing `-j`, `-n` and
   variable propagation.
9. **`tests/run` reported success whenever `grep` found no `ERROR`** — including
   when the program had crashed, and including when tracing was compiled out and
   the log was empty.
10. **Only the first target in a directory was built**, because `rules.mk` is
    included last and a leaf rule listed earlier became the default goal. Fixed
    with an explicit `.DEFAULT_GOAL`.

---

## 5.2 Source changes required to compile

### `lib/v2ldebug.c`, `lib/v2ldebug.h` — `gettid()`

```c
_syscall0(pid_t, gettid)        /* removed */
```

The kernel's `_syscall0()` macro was removed from the exported UAPI headers
long ago, so this was a hard error. Replaced with a `syscall(SYS_gettid)`
wrapper that is compiled only when the C library does not already provide one
(glibc grew `gettid()` in 2.30). The matching declaration in `v2ldebug.h` is
guarded the same way, and `<linux/unistd.h>` was replaced by `<unistd.h>`.

### `tests/demo.c` — opaque `pthread_attr_t`

```c
policy = (cur_task->attr).__schedpolicy;                       /* removed */
printf(...((cur_task->attr).__schedparam).sched_priority);     /* removed */
printf(...(cur_task->attr).__detachstate);                     /* removed */
```

`pthread_attr_t` became an opaque blob in glibc 2.x. Replaced with the POSIX
accessors `pthread_attr_getschedpolicy()`, `pthread_attr_getschedparam()` and
`pthread_attr_getdetachstate()`.

### `-fcommon`

The test programs define `test_child_id`, `queue1_id`, `queue2_id`,
`queue3_id` and `task8_id` as tentative definitions in more than one
translation unit. gcc merged those into a single common symbol until gcc 10
switched the default to `-fno-common`, after which they are
`multiple definition` link errors. `-fcommon` restores the old behaviour
rather than re-plumbing the test globals.

### `samples/shared_library/load.c` — `dlsym()` typo

```c
dlsym(handle, "sample_function ")   /* trailing space */
```

`dlsym()` matches exactly, so the sample failed at run time with
`undefined symbol: sample_function`. Space removed.

---

## 5.3 64-bit correctness fixes

The sources were written for 32-bit targets and truncate pointers to `int` in
several places. On x86-64 this is at best a warning and at worst a real bug.

| Location | Was | Now |
|---|---|---|
| `lib/v2ldebug.h`, `CHK()` | `int ret; ... (int)(command)` | `intptr_t ret; ... (intptr_t)(command)` — `CHK()` is used on `SEM_ID`/`MSG_Q_ID`/`WDOG_ID` pointers, and truncating one whose low 32 bits happen to be zero would report a spurious failure |
| `lib/v2ldebug.h`, `TRACEF()` | `"task=%x", (int)my_task()` | `"task=%p", (void *)my_task()` |
| `lib/ltaskLib.c`, `taskInit()` | `task->taskid = (int)task;` | `task->taskid = (int)(intptr_t)task;` (+ `<stdint.h>`), with a comment noting this is a provisional id that `taskActivate()` replaces |
| `lib/lmsgQLib.c`, `fetch_msg_from()` | `*element = (char) NULL;` | `*element = '\0';` |

---

## 5.4 Test-code fixes

Only defects that were undefined behaviour or that produced compiler warnings.
The six *logic* failures listed in
[note 4](04-running-the-tests.md#45-the-six-known-failures) were left alone and
recorded in `tests/known-failures.txt` instead, because fixing them means
deciding intended VxWorks semantics rather than repairing a build.

### `tests/test_msgq.c` — sequence point violation

```c
int len;
CHK(len == (len = msgQReceive(queue1_id, msg.blk, 16, 100)));   /* removed */
```

`len` was read and written without an intervening sequence point, and was
uninitialised on the first iteration. Replaced with a plain assignment; the
`CHK()` was dropped because a short read is the loop's normal exit condition
and would have logged a spurious `ERROR` on every run.

### `tests/test_msgq.c` — uninitialised read

`msg_count` was traced but never assigned (the assignment is commented out
upstream). Initialised to `0`.

### `tests/test.c` — `__USE_GNU`

```c
#define __USE_GNU   /* removed */
```

Defining a glibc-internal feature macro after `<stdio.h>` had already been
included produced a redefinition warning and did nothing useful. The build
system defines `_GNU_SOURCE` globally instead, which is the supported way.

---

## 5.5 Verification performed

* Clean build from `make distclean`: **0 warnings, 0 errors**.
* All 12 artifacts produced: 4 libraries, 4 sample binaries, 4 test binaries.
* Incremental rebuild is a genuine no-op.
* `touch lib/vxw_hdrs.h && make` rebuilds exactly the 20 dependent objects.
* `make test` → `test`, `test_sem`, `test_time` all PASS (6 known failures
  matched against the baseline, 0 unexpected).
* `make run` → all three samples run to completion; `load` prints
  `loaded: 12345` and calls into the dlopen'd module.
* Binaries run with `LD_LIBRARY_PATH` unset.
* `make install DESTDIR=… prefix=…` stages 4 libraries and 9 headers.
* `make clean` leaves no `.o`, `.d`, `.so` or `.a` behind; rebuild after clean
  succeeds.
* `make V=1`, `DEBUG=1`, `OPTIM=-O2` all behave as documented.

---

## 5.6 Not done

Deliberately out of scope, listed so the next person does not have to
rediscover them:

* The six known test failures (see note 4). Each needs a semantics decision.
* `taskSuspend()`/`taskResume()` still return `ENOSYS`.
* `taskVarLib` and `loadLib` remain empty stubs; they are not compiled.
* `semCCreate()` still ignores `SEM_Q_PRIORITY`, `SEM_DELETE_SAFE` and
  `SEM_INVERSION_SAFE`.
* No priority inheritance on mutexes.
* No `pkg-config` file is installed.
* The `.svn/` directories from the original 2006 checkout are still present and
  are ignored by the build.
