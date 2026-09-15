# 6. File-by-file change list

Every file this tree touched, with the exact before/after text, so the same
changes can be reproduced in another checkout by hand.

Line numbers are **post-change** and are anchors, not addresses — match on the
quoted text, not the number.

Legend for the **Required** column:

- **compile** — without it the file does not compile or link on a modern toolchain
- **correctness** — it compiled before, but was wrong on 64-bit or was undefined behaviour
- **build** — build-system only, no effect on the shipped code
- **cosmetic** — removes a warning, no behaviour change

---

## 6.0 Summary

| File                              | Kind         | Required              |
| --------------------------------- | ------------ | --------------------- |
| `lib/v2ldebug.c`                  | source edit  | compile               |
| `lib/v2ldebug.h`                  | source edit  | compile + correctness |
| `lib/ltaskLib.c`                  | source edit  | correctness           |
| `lib/lmsgQLib.c`                  | source edit  | correctness           |
| `tests/demo.c`                    | source edit  | compile               |
| `tests/test.c`                    | source edit  | cosmetic              |
| `tests/test_msgq.c`               | source edit  | correctness           |
| `samples/shared_library/load.c`   | source edit  | correctness (runtime) |
| `defs.mk`                         | **replaced** | build                 |
| `rules.mk`                        | **replaced** | build                 |
| `Makefile`                        | **replaced** | build                 |
| `lib/Makefile`                    | **replaced** | build                 |
| `lib/defs.mk`                     | **replaced** | build                 |
| `samples/Makefile`                | **replaced** | build                 |
| `samples/defs.mk`                 | **replaced** | build                 |
| `samples/with_main/Makefile`      | **replaced** | build                 |
| `samples/shared_library/Makefile` | **replaced** | build                 |
| `samples/shared_library/defs.mk`  | **replaced** | build                 |
| `tests/Makefile`                  | **replaced** | build                 |
| `tests/defs.mk`                   | **replaced** | build                 |
| `tests/check-log.sh`              | **new**      | build                 |
| `tests/known-failures.txt`        | **new**      | build                 |
| `Notes/*.md`                      | **new**      | documentation         |

### Source-edit audit

The eight entries marked **source edit** above are every C or C-header file
modified during this modernization. Their precise before/after changes are
documented in sections 6.1 through 6.8 below. All later work on the Makefiles
changes compilation, linking, or test invocation only; it does not change the
v2lin API implementation.

**Not modified:** `lib/lkernelLib.c`, `lib/lsemLib.c`, `lib/lwdLib.c`,
`lib/main_impl.c`, `lib/v2ltime.c`, `lib/loadLib.c`, `lib/loadLib.h`,
`lib/taskVarLib.c`, `lib/taskVarLib.h`, `lib/sysLib.h`, `lib/tickLib.h`,
`lib/v2lpthread.h`, `lib/vxw_defs.h`, `lib/vxw_hdrs.h`, `lib/internal.h`,
`tests/test_tasks.c`, `tests/test_semaphores.c`, `tests/test_mutexes.c`,
`tests/test_watchdog.c`, `tests/test_sem.c`, `tests/test_time.c`,
`tests/test.h`, `tests/tasks_sub.c`, `tests/run.gdb`,
`samples/with_sysinit.c`, `samples/with_main/with_main.c`,
`samples/shared_library/sample_lib.c`, `samples/shared_library/sample_lib.h`,
`README`, `ChangeLog`, `COPYRIGHT`, `HEADER`, `GNU_lgpl.txt`.

**If you only want it to compile and run**, apply Part A (8 files, 11 hunks).
Part B is optional if your workplace already has its own build system — but
read [6.11](#611-flags-your-own-build-system-must-set) for the four flags it
must set.

---

# Part A — source code changes

## 6.1 `lib/v2ldebug.c`

**One hunk, around line 19.** _(compile — hard error without it)_

The kernel's `_syscall0()` macro was removed from the exported UAPI headers,
so this line no longer compiles at all:
`error: expected declaration specifiers or '...' before 'gettid'`.

**Before**

```c
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include "v2lpthread.h"
#include <stdlib.h>
#include "v2ldebug.h"
#include <sys/wait.h>

_syscall0(pid_t,gettid)

int tid;
```

**After**

```c
#include <stdio.h>
#include <unistd.h>
#include <signal.h>
#include "v2lpthread.h"
#include <stdlib.h>
#include "v2ldebug.h"
#include <sys/wait.h>
#include <sys/syscall.h>

/* glibc only grew a gettid() wrapper in 2.30; before that the kernel's
 * _syscall0() macro was used, which no longer exists in the UAPI headers. */
#if !defined(__GLIBC__) || __GLIBC__ < 2 || (__GLIBC__ == 2 && __GLIBC_MINOR__ < 30)
pid_t gettid(void)
{
	return (pid_t) syscall(SYS_gettid);
}
#endif

int tid;
```

The `#if` keeps this working on old glibc (where you must define it yourself)
_and_ new glibc (where defining it again would shadow the library symbol).

---

## 6.2 `lib/v2ldebug.h`

**Three hunks.** Hunk 1 is _compile_; hunks 2 and 3 are _correctness_.

### Hunk 1 — around line 27: `gettid()` declaration

`<linux/unistd.h>` is the kernel UAPI header and should not be included by
userspace for this; the declaration must also not fight glibc's own.

**Before**

```c
#include <sys/types.h>
#include <linux/unistd.h>
pid_t gettid(void);
```

**After**

```c
#include <sys/types.h>
#include <stdint.h>
#include <unistd.h>
#if !defined(__GLIBC__) || __GLIBC__ < 2 || (__GLIBC__ == 2 && __GLIBC_MINOR__ < 30)
pid_t gettid(void);
#endif
```

`<stdint.h>` is added here for the `intptr_t` used in hunk 3.

### Hunk 2 — line 59, inside `TRACEF()`: pointer printed as `%x`

A 64-bit `task_t *` was truncated to `int` for the trace banner.

**Before**

```c
		fprintf(stderr,"\nthread=%i task=%x %s\n",(int)tid,(int)my_task(),my_task()?my_task()->taskname:NULL); }; \
```

**After**

```c
		fprintf(stderr,"\nthread=%i task=%p %s\n",(int)tid,(void *)my_task(),my_task()?my_task()->taskname:NULL); }; \
```

Trace output only, but it removes a warning at every one of the ~1000 `TRACEF`
expansion sites.

### Hunk 3 — around line 95, `CHK()`: **this one is a real bug**

`CHK()` is used throughout the tests and library on pointer-returning calls:

```c
CHK(sem1_id  = semBCreate(SEM_Q_FIFO, SEM_EMPTY));
CHK(queue1_id = msgQCreate(9, 16, MSG_Q_PRIORITY));
CHK(wdog1_id = wdCreate());
```

Casting a 64-bit pointer to `int` keeps only the low 32 bits. A perfectly
valid allocation whose low word happens to be zero would be reported as a
failure. Rare, but non-deterministic and very hard to diagnose.

**Before**

```c
// CHK supposes !0 is success, suitable for checking pointers
// and functions in form: CHK(0<read(fd,buff,count));
#define CHK(command)    \
	do {	int ret;\
		FN_IN(#command); \
		if ( ! (ret=(int) (command)) ) {    \
```

**After**

```c
// CHK supposes !0 is success, suitable for checking pointers
// and functions in form: CHK(0<read(fd,buff,count));
// `ret' is intptr_t so that a 64-bit SEM_ID/MSG_Q_ID/WDOG_ID is not truncated.
#define CHK(command)    \
	do {	intptr_t ret;\
		FN_IN(#command); \
		if ( ! (ret=(intptr_t) (command)) ) {    \
```

The rest of the macro body is unchanged. `CHK0()` was **not** touched — it
tests an `int` status, which is correct as-is.

---

## 6.3 `lib/ltaskLib.c`

**Two hunks.** _(correctness)_

### Hunk 1 — line 29: add `<stdint.h>`

**Before**

```c
#include <errno.h>
#include <assert.h>
#include <unistd.h>
#include <sched.h>
#include <sys/mman.h>
```

**After**

```c
#include <errno.h>
#include <assert.h>
#include <unistd.h>
#include <sched.h>
#include <stdint.h>
#include <sys/mman.h>
```

### Hunk 2 — line 801, in `taskInit()`

**Before**

```c
	memset(task,0,sizeof(*task));
	task->pthrid = 0;
	task->taskid =  (int)task;
```

**After**

```c
	memset(task,0,sizeof(*task));
	task->pthrid = 0;
	// Provisional unique id; taskActivate() replaces it with a small number.
	task->taskid =  (int)(intptr_t)task;
```

This is still a truncation — `taskid` is declared `int` in `task_t` — but the
value is only a provisional unique key that `taskActivate()` overwrites, and
the explicit two-step cast documents that and silences
`-Wpointer-to-int-cast`. **Do not "fix" this by widening `taskid`**: it is part
of the public API (`taskIdSelf()`, `taskDelete(int)`, `taskIdListGet(int[])`)
and widening it would break every caller.

---

## 6.4 `lib/lmsgQLib.c`

**One hunk, line 358, in `fetch_msg_from()`.** _(correctness)_

Casting the `NULL` macro to `char` is a pointer-to-integer conversion.

**Before**

```c
	element = (char *) &((queue->queue_head)->msgbuf);
	*element = (char) NULL;
```

**After**

```c
	element = (char *) &((queue->queue_head)->msgbuf);
	*element = '\0';
```

Same generated code, no cast diagnostic.

---

## 6.5 `tests/demo.c`

**One hunk, `display_task()`, lines 50-83.** _(compile — hard error without it)_

`pthread_attr_t` became an opaque blob in glibc 2.x; the `__schedpolicy`,
`__schedparam` and `__detachstate` members no longer exist:
`error: 'pthread_attr_t' has no member named '__schedpolicy'`.

**Before**

```c
static void display_task(void)
{
	int policy;
	task_t *cur_task;
	cur_task = my_task();
	if (cur_task == (task_t *) NULL)
		return;
	printf
		("\r\nTask Name: %s  Task ID: %d  Thread ID: %ld  Vxworks priority: %d",
		 cur_task->taskname, cur_task->taskid, cur_task->pthrid, cur_task->vxw_priority);
	policy = (cur_task->attr).__schedpolicy;
	switch (policy) {
	...
	}
	printf(" priority %d ", ((cur_task->attr).__schedparam).sched_priority);
	printf(" prv_priority %d ", (cur_task->prv_priority).sched_priority);
	printf(" detachstate %d ", (cur_task->attr).__detachstate);
}
```

**After**

```c
static void display_task(void)
{
	int policy;
	int detachstate;
	struct sched_param param;
	task_t *cur_task;
	cur_task = my_task();
	if (cur_task == (task_t *) NULL)
		return;
	printf
		("\r\nTask Name: %s  Task ID: %d  Thread ID: %ld  Vxworks priority: %d",
		 cur_task->taskname, cur_task->taskid, cur_task->pthrid, cur_task->vxw_priority);
	// pthread_attr_t became opaque in glibc 2.x; use the POSIX accessors
	// instead of the old __schedpolicy/__schedparam/__detachstate members.
	pthread_attr_getschedpolicy(&(cur_task->attr), &policy);
	switch (policy) {
	...unchanged...
	}
	pthread_attr_getschedparam(&(cur_task->attr), &param);
	printf(" priority %d ", param.sched_priority);
	printf(" prv_priority %d ", (cur_task->prv_priority).sched_priority);
	pthread_attr_getdetachstate(&(cur_task->attr), &detachstate);
	printf(" detachstate %d ", detachstate);
}
```

Three added declarations, three member reads replaced by accessor calls. The
`switch` body is untouched.

> **Check your own code for this pattern.** Any application that pokes at
> `task_t.attr` directly hits the same wall. `lib/ltaskLib.c` and
> `lib/lsemLib.c` already used the accessors and needed no change.

---

## 6.6 `tests/test.c`

**One hunk, around line 30.** _(cosmetic)_

`__USE_GNU` is a glibc-**internal** macro derived from `_GNU_SOURCE`. Defining
it by hand, after `<stdio.h>` has already been included, is both too late and
unsupported: `warning: "__USE_GNU" redefined`.

**Before**

```c
#include <errno.h>
#define __USE_GNU // for TIMEVAL_TO_TIMESPEC
#include <time.h>
//#define __USE_XOPEN2K // for pthread_mutex_timedlock
#include <pthread.h>
```

**After**

```c
#include <errno.h>
// TIMEVAL_TO_TIMESPEC and pthread_mutex_timedlock come from _GNU_SOURCE,
// which the build system defines globally (see defs.mk).
#include <time.h>
#include <pthread.h>
```

**This hunk only works if `-D_GNU_SOURCE` is on the command line** (see
[6.11](#611-flags-your-own-build-system-must-set)). If your build does not set
it, keep the old lines or you will lose `TIMEVAL_TO_TIMESPEC` and
`pthread_mutex_timedlock`.

---

## 6.7 `tests/test_msgq.c`

**Two hunks.** _(correctness — both were undefined behaviour)_

### Hunk 1 — line 55, in `test_msg_queues()`

`msg_count` was passed to `TRACEV()` at line ~293 but never assigned; the
assignment is commented out upstream.

**Before**

```c
	STATUS err;
	int message_num;
	int msg_count;
```

**After**

```c
	STATUS err;
	int message_num;
	int msg_count = 0;
```

### Hunk 2 — line ~429, in `task9()`

`len` was read and written in one expression with no sequence point between
them, _and_ was uninitialised on the first read. The result of the comparison
was meaningless, and `CHK()` logged a spurious `ERROR` every time the loop
exited normally.

**Before**

```c
	while (1) {
		int len;
		CHK(len == (len = msgQReceive(queue1_id, msg.blk, 16, 100)));
		if (len != 16)
			break;
```

**After**

```c
	while (1) {
		// A short read (or -1 once MSQ1 is deleted) is the expected way out,
		// so this receive is deliberately not wrapped in CHK().
		int len = msgQReceive(queue1_id, msg.blk, 16, 100);
		if (len != 16)
			break;
```

The `TRACEF` below and the rest of the loop are unchanged.

---

## 6.8 `samples/shared_library/load.c`

**One hunk, line 50.** _(correctness — runtime failure)_

`dlsym()` matches symbol names byte-for-byte. The trailing space made the
sample fail at run time with
`libsample_lib.so: undefined symbol: sample_function`.

**Before**

```c
	sample_function2 = dlsym(handle, "sample_function ");
```

**After**

```c
	sample_function2 = dlsym(handle, "sample_function");
```

---

# Part B — build system

These files were **replaced wholesale**, not patched. Copy them across rather
than trying to merge. Their design is described in
[note 1](01-build-system.md).

## 6.9 Replaced files

| File                                                                                | What it now contains                                                                                                                                                                                                          |
| ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `defs.mk`                                                                           | toolchain (`CROSS_COMPILE`/`CC`/`AR`/`ARFLAGS`/`INSTALL`), install paths (`prefix`/`libdir`/`includedir`), knobs (`DEBUG`, `TRACE_IN_OUT`, `OPTIM`, `V`), `CPPFLAGS`/`CFLAGS`/`LDLIBS`, `V2LIN_RPATH`, `.DEFAULT_GOAL := all` |
| `rules.mk`                                                                          | `%.o: %.c` with `-MMD -MP`; direct rules for `ARLIBS`/`SHLIBS`/`EXES` using secondary expansion; `clean`; `distclean`; `-include $(DEPS)`                                                                                     |
| `Makefile`                                                                          | recursion into `lib`/`samples`/`tests`, `test`/`check`, `run`, `install`/`uninstall`, `clean`/`distclean`, `tags`, `help`                                                                                                     |
| `lib/Makefile`                                                                      | declares `libv2lin.{so,a}` and `libv2linmain.{so,a}` and their object lists                                                                                                                                                   |
| `tests/Makefile`                                                                    | declares `test`, `test_sem`, `test_time`, `demo`; `run-test`/`run-sem`/`run-time`/`run-demo`/`gdb`                                                                                                                            |
| `samples/Makefile`                                                                  | declares `with_sysinit`, recurses into the two sub-directories, `run`                                                                                                                                                         |
| `samples/with_main/Makefile`                                                        | declares `with_main` (links `-lv2lin` only)                                                                                                                                                                                   |
| `samples/shared_library/Makefile`                                                   | declares `load` + `libsample_lib.so`, adds the `dlopen` rpath                                                                                                                                                                 |
| `lib/defs.mk`, `samples/defs.mk`, `samples/shared_library/defs.mk`, `tests/defs.mk` | `CFLAGS+=-DDEBUG` changed to `CPPFLAGS += -DDEBUG`, with a comment saying why each directory overrides the global setting                                                                                                     |

### Behaviour changes you will notice

1. **Static archives are now built too** (`libv2lin.a`, `libv2linmain.a`).
   The old build produced only `.so`s.
2. **`LD_LIBRARY_PATH` is no longer needed.** Binaries are linked with
   `-Wl,-rpath,<abs path of lib/>`. The rpath is absolute, so a built tree
   cannot be moved — `make clean && make` after relocating.
3. **`tests/demo` and `tests/test_time` are now built by default.** `demo` was
   never built by the old makefiles and had rotted (see 6.5).
4. **`make install` / `make uninstall` exist**, honouring `prefix` and `DESTDIR`.
5. **`make test` now has a real verdict** — see 6.10.
6. **`make depend` is a no-op.** Header dependencies are a side effect of
   compiling.
7. **Cross-compiling is supported** via `CROSS_COMPILE=<prefix>`, with
   `V2LIN_RPATH=` to drop the development rpath. Verified for armhf and
   aarch64 — see [note 1 §1.8](01-build-system.md#18-cross-compiling).

## 6.10 New files

### `tests/check-log.sh`

Turns a test log into a pass/fail verdict. It extracts every `ERROR:`
expression the `CHK()`/`CHK0()` macros wrote, and compares that set against a
baseline. Unlisted failures fail the run; listed ones are tolerated and
counted; listed ones that stopped happening are reported so the baseline can
be trimmed.

```sh
sh check-log.sh test.log known-failures.txt
sh check-log.sh test_sem.log           # no baseline: any ERROR fails
```

This replaces the old `grep ERROR -w test.log && ... || echo No errors`, which
reported success when the program had crashed and reported success when
tracing was compiled out and the log was empty.

### `tests/known-failures.txt`

The six pre-existing test-code failures, one expression per line, each
annotated with why it fails. Analysed in
[note 4 §4.5](04-running-the-tests.md#45-the-six-known-failures). **No test
expectation was changed to make the suite green** — the failures are recorded,
not hidden.

### `Notes/*.md`

Six documents; this is number 6.

---

## 6.11 Flags your own build system must set

If you keep your workplace's build instead of copying Part B, these four are
the ones that matter. Everything else is convenience.

| Flag                   | Consequence if missing                                                                                                                                                        |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-D_GNU_SOURCE`        | `gettid`, `pthread_mutex_timedlock`, `TIMEVAL_TO_TIMESPEC` all disappear. **Required** by hunk 6.6.                                                                           |
| `-fcommon`             | `multiple definition of 'test_child_id' / 'queue1_id' / 'queue2_id' / 'queue3_id' / 'task8_id'` at link time on gcc ≥ 10. Only affects the _test_ programs — not the library. |
| `-pthread`             | at compile **and** link time                                                                                                                                                  |
| `-D_USR_SYS_INIT_KILL` | selects the `user_sysinit()`/`user_syskill()` entry-point style; omit it if your app has its own `main()`                                                                     |

Link libraries: `-lrt` (for `clock_getres()` in `sysClkRateGet()`) and `-ldl`
(only if you use the `dlopen()` replacement for `loadModule()`).

The `-fcommon` alternative, if your policy forbids it: pick one translation
unit to own each of those five globals, and add `extern` to the declarations
in the others.

---

## 6.12 Applying this to a different v2lin checkout

Order matters slightly — Part A first, so you can build before changing the
build.

1. Apply 6.1 and 6.2 hunk 1 → `lib/` compiles.
2. Apply 6.5 → `tests/demo.c` compiles (skip if you do not build `demo`).
3. Add `-fcommon` and `-D_GNU_SOURCE` → everything links.
4. Apply 6.6 → warning gone.
5. Apply 6.2 hunk 3, 6.3, 6.4 → 64-bit correctness. **Do these even if you are
   only interested in getting a build.** They are latent bugs, not warnings.
6. Apply 6.7 and 6.8 → test and sample correctness.
7. Optionally replace Part B.

Sanity check after each step:

```sh
make clean && make 2>&1 | grep -c warning     # target: 0
make test                                     # target: exit 0
```

---

## 6.13 Machine-readable patch

Everything in Part A and the per-directory makefiles is also available as a
real unified diff:

**[`Notes/v2lin-modernisation.patch`](v2lin-modernisation.patch)** — 17 files,
564 lines.

It was generated by diffing the working tree against the pristine 2006 sources
that the original SVN checkout still carries in each `.svn/text-base/`
directory, so it is authoritative rather than hand-written:

```sh
for dir in lib tests samples samples/with_main samples/shared_library; do
    for pristine in "$dir"/.svn/text-base/*.svn-base; do
        name=$(basename "$pristine" .svn-base)
        cur="$dir/$name"
        [ -f "$cur" ] && ! cmp -s "$pristine" "$cur" &&
            diff -u --label "a/$cur" --label "b/$cur" "$pristine" "$cur"
    done
done > Notes/v2lin-modernisation.patch
```

Apply it to an unmodified 0.2 checkout with:

```sh
patch -p1 --dry-run < Notes/v2lin-modernisation.patch   # check first
patch -p1           < Notes/v2lin-modernisation.patch
```

Source-only subset (the 11 hunks of Part A, skipping the build files):

```sh
filterdiff -i '*.c' -i '*.h' Notes/v2lin-modernisation.patch | patch -p1
```

### What the patch does **not** cover

Three top-level files have no pristine copy in `.svn` (the original checkout
did not version the root directory), so they are absent from the diff and must
be copied across by hand:

- `defs.mk`
- `rules.mk`
- `Makefile`

Nor does it contain the new files: `tests/check-log.sh`,
`tests/known-failures.txt`, `Notes/*.md`.
