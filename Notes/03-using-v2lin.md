# 3. Using v2lin in your own application

A practical checklist for moving a VxWorks program onto Linux with this
library.

---

## 3.1 Choose an entry-point style

| | (a) VxWorks style | (b) Linux style |
|---|---|---|
| You write | `user_sysinit()` + `user_syskill()` | `main()` |
| `main()` comes from | `libv2linmain` | you |
| Initialisation | automatic | you call `v2lin_init()` first |
| Link with | `-lv2linmain -lv2lin` | `-lv2lin` |
| Example | `samples/with_sysinit.c` | `samples/with_main/with_main.c` |
| Best for | a straight port of an existing VxWorks image | embedding v2lin in a larger Linux program |

Style (a) is closest to the original VxWorks startup and is what the test
suite uses. Style (b) is the one to pick if the program also has to do
ordinary Linux things (parse argv, open sockets, be a daemon) before the RTOS
part starts.

With style (b), **`v2lin_init()` must be the first v2lin call you make.**
Calling `taskSpawn()` before it will not work: the root and exception tasks do
not exist yet, so watchdogs never fire.

---

## 3.2 Build and link

From the build tree:

```sh
gcc -D_GNU_SOURCE -Ipath/to/v2lin/lib -pthread -c myapp.c
gcc -o myapp myapp.o -Lpath/to/v2lin/lib -Wl,-rpath,path/to/v2lin/lib \
    -lv2linmain -lv2lin -pthread -lrt -ldl
```

After `make install`:

```sh
gcc -D_GNU_SOURCE -I$(prefix)/include/v2lin -pthread -c myapp.c
gcc -o myapp myapp.o -lv2linmain -lv2lin -pthread -lrt -ldl
```

Required pieces, and why:

| Flag | Why |
|---|---|
| `-D_GNU_SOURCE` | `v2ldebug.h` uses `gettid()`; the API uses `pthread_mutex_timedlock()` and `TIMEVAL_TO_TIMESPEC()` |
| `-pthread` | both at compile and link time |
| `-lrt` | `clock_getres()` in `sysClkRateGet()` |
| `-ldl` | only if you use `dlopen()` as the `loadModule()` replacement |
| `-lv2linmain` | **only** for entry-point style (a) |

Static linking works too — `libv2lin.a` and `libv2linmain.a` are built
alongside the shared objects. Put `-lv2linmain` before `-lv2lin`.

The easiest way to add your own program to this tree is to drop it in a new
directory with a leaf `Makefile` modelled on `samples/with_main/Makefile`; see
[note 1](01-build-system.md#13-declaring-targets).

---

## 3.3 Include exactly one header

```c
#include "vxw_hdrs.h"     /* the whole API; pulls in vxw_defs.h and v2lpthread.h */
```

Add `#include "v2ldebug.h"` if you want `TRACEF()`/`CHK()` in your own code —
remember they are no-ops unless you compile with `-DDEBUG`.

`sysLib.h` and `tickLib.h` exist separately for `sysClkRateGet()`,
`tickGet()` and `tickSet()`.

---

## 3.4 Port the things that do not map

| VxWorks | Replace with |
|---|---|
| `taskVarAdd()` / `taskVarGet()` / `taskVarSet()` | `__thread int myvar;` (simplest) or `pthread_key_create()` / `pthread_setspecific()` / `pthread_getspecific()` |
| `loadModule()` / `loadModuleAt()` | build the module as a shared object and use `dlopen()` + `dlsym()` — working example in `samples/shared_library/` |
| `taskSuspend()` / `taskResume()` | redesign around a semaphore the task pends on; v2lin returns `ENOSYS` |
| `semCCreate(SEM_Q_PRIORITY \| SEM_DELETE_SAFE \| SEM_INVERSION_SAFE, …)` | not implemented — use `SEM_Q_FIFO`, and guard deletion yourself with `taskSafe()`/`taskUnsafe()` |
| Direct hardware / BSP access | there is no BSP; this has to be rewritten against Linux drivers |

### The `dlopen()` pattern

```c
void *h = dlopen("libmymodule.so", RTLD_LAZY);
if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); return -1; }

my_struct_t *p  = dlsym(h, "my_struct");
void (*fn)(void) = dlsym(h, "my_function");
if (dlerror()) { /* handle */ }

fn();
dlclose(h);
```

Two traps, both of which this tree hit:

* `dlsym()` symbol names are matched **exactly** — a stray space in the string
  yields a silent `undefined symbol` at run time.
* A bare soname is resolved against the **RUNPATH of the calling binary**, so
  link `load` with `-Wl,-rpath,<dir containing the module>` or set
  `LD_LIBRARY_PATH`.

---

## 3.5 Real-time scheduling privileges

v2lin asks for `SCHED_FIFO` (or `SCHED_RR`) priorities. An unprivileged Linux
process cannot have them, so you will see this in the logs:

```
	errno=1(1) Operation not permitted
```

The program still runs correctly; it just gets ordinary fair scheduling and
therefore no priority guarantees. To get the real behaviour, choose one:

```sh
sudo ./myapp                                   # simplest
sudo setcap cap_sys_nice+ep ./myapp            # no root at run time
# or raise RLIMIT_RTPRIO for the user in /etc/security/limits.conf:
#   myuser  -  rtprio  99
```

In Docker: `docker run --cap-add=sys_nice --ulimit rtprio=99 …`

Do not do this for the test suite unless you are investigating timing — a
real-time-priority busy loop can lock up a desktop.

---

## 3.6 Behaviour to re-check after porting

Things that behave subtly differently from real VxWorks and are worth an
explicit test in your application:

1. **Priority direction.** VxWorks `0` is the *highest* priority. A port that
   treats priorities as "bigger is more important" will be inverted.
2. **Tick length.** One tick is 10 ms (`V2PT_TICK`). If your code assumed a
   different system clock rate, every `taskDelay()` and semaphore timeout is
   scaled wrong.
3. **No memory protection.** Tasks are threads. A wild pointer in one task
   corrupts all of them, where on VxWorks with an MMU-enabled BSP it might
   have been contained.
4. **`taskDelete()` is `pthread_cancel()`.** Deletion happens at the next
   cancellation point. Code that assumed immediate death, or that held a lock
   at the moment of deletion, needs review. Use `taskSafe()`/`taskUnsafe()`
   around critical sections.
5. **No priority inheritance.** A low-priority task holding a mutex will block
   a high-priority task for as long as it likes.
6. **`errno` vs return value.** The v2lin wrappers set `errno` to VxWorks
   status codes (`S_objLib_OBJ_TIMEOUT`, …), but the underlying `pthread_*`
   functions return their error instead of setting `errno`. If you call
   pthreads directly, check the return value.

---

## 3.7 A minimal working program

```c
/* myapp.c - entry-point style (b) */
#include <stdio.h>
#include <unistd.h>
#include "vxw_hdrs.h"

static SEM_ID go;

static int worker(int a0,int a1,int a2,int a3,int a4,
                  int a5,int a6,int a7,int a8,int a9)
{
    for (;;) {
        if (semTake(go, WAIT_FOREVER) != OK)
            break;
        printf("worker woke up\n");
    }
    return 0;
}

int main(void)
{
    v2lin_init();

    go = semBCreate(SEM_Q_FIFO, SEM_EMPTY);
    taskSpawn("WORK", 20, 0, 0, worker, 0,0,0,0,0,0,0,0,0,0);

    for (int i = 0; i < 3; i++) {
        taskDelay(100);          /* 100 ticks == ~1 s */
        semGive(go);
    }
    taskDelay(50);
    return 0;
}
```

```sh
gcc -D_GNU_SOURCE -Ilib -pthread -o myapp myapp.c \
    -Llib -Wl,-rpath,$PWD/lib -lv2lin -lrt -ldl
./myapp
```

---

## 3.8 Debugging a port

```sh
make DEBUG=1                     # trace every v2lin call site
make DEBUG=1 TRACE_IN_OUT=1      # also trace entry/exit of checked calls
```

Then in your own code, wrap every v2lin call so failures are self-reporting:

```c
#include "v2ldebug.h"

CHK(sem = semBCreate(SEM_Q_FIFO, SEM_EMPTY));   /* non-zero == success */
CHK0(semTake(sem, WAIT_FOREVER));               /* zero == success     */
```

Useful run-time introspection (all take a `FILE *`):

```c
taskList(stderr, 0);    /* every task, state and priority */
semList(stderr, 0);     /* every semaphore and its waiters */
msgQList(stderr, 0);    /* every message queue */
wdogShow(stderr);       /* every watchdog */
```

Under gdb, `info threads` maps directly onto the task list; `tests/run.gdb`
is a two-line example.
