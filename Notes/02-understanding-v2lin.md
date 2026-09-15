# 2. Understanding v2lin

What the library actually is, how a VxWorks concept becomes a Linux one, and
where the emulation is thin.

---

## 2.1 The idea in one paragraph

VxWorks applications are written against a small, very specific kernel API:
`taskSpawn()`, `semTake()`, `msgQSend()`, `wdStart()`. v2lin implements that
API on top of POSIX threads so the application source can be recompiled for
Linux **without being rewritten**. A VxWorks _task_ becomes a pthread, a
VxWorks _semaphore_ becomes a mutex plus condition variable, a _message
queue_ becomes a ring buffer guarded by the same primitives, and a _watchdog_
becomes a tick counter polled by a dedicated high-priority thread.

It is an emulation of the _API_, not of the _kernel_. The whole application
still runs as one ordinary Linux process; there is no separate address space
per task, no kernel mode, and no hard real-time guarantee.

Lineage: MontaVista's `legacy2linux` project (Gary S. Robertson, 2000-2001),
extended by Andrew Skiba (2004), Mike Kemelmakher (2005) and Constantine
Shulyupin (2006). This tree is release 0.2.

---

## 2.2 The mapping

| VxWorks                                                                   | v2lin source      | Linux mechanism                                                               |
| ------------------------------------------------------------------------- | ----------------- | ----------------------------------------------------------------------------- |
| `taskLib` — `taskSpawn`, `taskDelete`, `taskDelay`, `taskPrioritySet`, …  | `ltaskLib.c`      | `pthread_create`, `pthread_cancel`, `nanosleep`, `pthread_attr_setschedparam` |
| `semLib` — `semBCreate`, `semCCreate`, `semMCreate`, `semTake`, `semGive` | `lsemLib.c`       | `pthread_mutex_t` + `pthread_cond_t` + a token count                          |
| `msgQLib` — `msgQCreate`, `msgQSend`, `msgQReceive`                       | `lmsgQLib.c`      | a ring buffer of fixed-size slots, same mutex/condvar pattern                 |
| `wdLib` — `wdCreate`, `wdStart`, `wdCancel`                               | `lwdLib.c`        | a linked list of tick counters, decremented by the exception task             |
| `kernelLib` — `kernelTimeSlice`, round-robin control                      | `lkernelLib.c`    | `SCHED_FIFO` vs `SCHED_RR`                                                    |
| `tickLib`, `sysLib` — `tickGet`, `tickSet`, `sysClkRateGet`               | `v2ltime.c`       | `/proc/uptime`, `clock_getres(CLOCK_REALTIME)`                                |
| `loadLib` — `loadModule`                                                  | _not implemented_ | `dlopen()`/`dlsym()` — see `samples/shared_library/`                          |
| `taskVarLib` — `taskVarAdd`/`Get`/`Set`                                   | _not implemented_ | `__thread` or `pthread_key_create()`                                          |

The public surface is a single header: **`lib/vxw_hdrs.h`**. Constants and
error codes (`WAIT_FOREVER`, `SEM_Q_FIFO`, `S_objLib_OBJ_TIMEOUT`, …) are in
**`lib/vxw_defs.h`**.

---

## 2.3 Tasks

### The task control block

`lib/v2lpthread.h` defines `task_t`, also available as `WIND_TCB` for source
compatibility. It holds the `pthread_t`, the `pthread_attr_t`, the VxWorks
priority, a state bitmask (`READY`/`PEND`/`DELAY`/`SUSPEND`/`TIMEOUT`/`DEAD`),
the deletion-safety nesting count, and the linked-list pointers used to build
the global task list and the per-object wait lists.

All live tasks are on one global list (`task_list`), serialised by
`task_list_lock`. `my_task()` finds the caller's control block; `task_for(id)`
finds one by ID.

### Priorities are inverted

This is the single most common source of confusion.

```
VxWorks:  0 = highest priority .. 255 = lowest      (MAX_V2PT_PRIORITY = 0)
POSIX:    high number = high priority
```

`translate_priority()` in `ltaskLib.c` flips and rescales between the two.
Always express priorities in VxWorks terms in application code
(`taskSpawn("TSK2", 20, ...)` is _lower_ priority than `taskSpawn("TSK8", 10, ...)`).

### Task IDs

`taskInit()` assigns a provisional ID derived from the control block address;
`taskActivate()` then replaces it with a small sequential number (< 65536).
Do not persist a task ID across `taskActivate()`.

### Scheduling policy

Tasks are created `SCHED_FIFO` by default, or `SCHED_RR` when
`enableRoundRobin()` has been called _before_ the task is spawned
(`roundRobinIsEnabled()` is read at `taskInit()` time — enabling it later has
no effect on existing tasks).

Both policies require privilege on Linux. Without it,
`pthread_attr_setschedparam()` fails with `EPERM` and the thread runs
`SCHED_OTHER` at normal priority. The library logs this and carries on, so
programs still work — they just do not get real-time scheduling. See
[note 3](03-using-v2lin.md#35-real-time-scheduling-privileges).

---

## 2.4 The two system tasks

`v2lin_init()` (in `lkernelLib.c`) starts two internal tasks before anything
else can run:

| Task       | Priority    | Job                                                                                                       |
| ---------- | ----------- | --------------------------------------------------------------------------------------------------------- |
| `tUsrRoot` | highest     | the context in which `user_sysinit()` runs, so that initialisation code may call blocking v2lin functions |
| `tExcTask` | highest - 1 | the "exception task": it calls `taskDelay(1)` in a loop and drives every watchdog timer                   |

Because watchdog callbacks execute **in the exception task's context**, not in
an interrupt handler, a slow callback delays every other watchdog. Keep them
short.

---

## 2.5 Ticks

`V2PT_TICK` (in `v2lpthread.h`) is **10 ms**. Every `ticks` argument in the
API — `taskDelay(50)`, `semTake(sem, 100)`, `wdStart(wd, 1, ...)` — is in
units of that tick, so `taskDelay(50)` sleeps roughly half a second.

`tickGet()`/`tickSet()` are implemented by reading `/proc/uptime` and applying
an offset, so they are wall-clock based rather than a real kernel tick
counter. `sysClkRateGet()` returns `1e9 / clock_getres(CLOCK_REALTIME)`.

---

## 2.6 The two entry-point styles

This is the decision you make first when porting, and it decides what you link
against.

### (a) VxWorks style — you supply `user_sysinit()` / `user_syskill()`

```c
void user_sysinit(void)   /* runs in the root task; may block */
{
    taskSpawn("TSK1", 20, 0, 0, my_task_fn, 0,0,0,0,0,0,0,0,0,0);
}

void user_syskill(void)   /* runs in the main process context */
{
    sleep(1);             /* or wait for a shutdown condition */
}
```

`main()` comes from **`libv2linmain`**, which calls `taskInit()`/
`taskActivate()` for the root task and then blocks in `user_syskill()`. The
process exits when `user_syskill()` returns.

Link: `-lv2linmain -lv2lin`
Example: `samples/with_sysinit.c`, and every program in `tests/`.

### (b) Linux style — you keep your own `main()`

```c
int main(int argc, char **argv)
{
    v2lin_init();         /* MUST be called before any other v2lin function */
    taskSpawn(...);
    ...
}
```

Link: `-lv2lin` only (do **not** link `libv2linmain`, you would get two
`main()`s).
Example: `samples/with_main/with_main.c`.

Style (a) is selected at compile time by `-D_USR_SYS_INIT_KILL`, which the
build system defines globally; the test sources use it to switch between the
two code paths with `#ifdef`.

---

## 2.7 The tracing and checking macros

`lib/v2ldebug.h` is worth reading before anything else, because every source
file in the tree reports through it.

| Macro              | Purpose                                                                                                                           |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `TRACEF("fmt", …)` | timestamped trace line: `file:line function() message`. Also prints a `thread=/task=` banner whenever the calling thread changes. |
| `TRACEV("%i", x)`  | print one variable as `x=<value>`                                                                                                 |
| `CHK(expr)`        | evaluate `expr`, log `ERROR: <expr>` + `errno` if it is **zero**. Use for pointer-returning and "expect true" checks.             |
| `CHK0(expr)`       | evaluate `expr`, log `ERROR: <expr>` + status if it is **non-zero**. Use for functions that return `0` on success.                |
| `FN_IN`/`FN_OUT`   | function entry/exit tracing, enabled by `TRACE_IN_OUT`                                                                            |

All of them compile to nothing unless `DEBUG` is defined. That is why
`tests/defs.mk` and `samples/defs.mk` force `-DDEBUG` on: the test verdict is
derived from the `ERROR:` lines these macros emit on stderr.

`CHK()` and `CHK0()` do **not** abort. They log and continue (`ON_ERR` is
defined as "ignore"), so a single failure produces one log line rather than
stopping the run. That is deliberate: it lets one run surface every problem.

A trace line looks like:

```
thread=21 task=0x7ffc10261220 tUsrRoot
time=2026-09-11 15:33:47.314043
uptime=0.512000 s +0.011000
test_tasks.c:151 test_tasks_delete() ERROR: taskIsReady(temp_taskid)
	errno=0(0) OK
```

`VxWorksError()` renders the numeric status as a VxWorks error name, which is
why `errno=1` shows as `Operation not permitted` and `0x3d0004` as
`S_objLib_OBJ_TIMEOUT`.

---

## 2.8 Where the emulation is thin

Documented in the top-level `README`, confirmed while building:

**Not implemented**

- `semCCreate(SEM_Q_PRIORITY, 0)`
- `semCCreate(SEM_DELETE_SAFE, 0)`
- `semCCreate(SEM_INVERSION_SAFE, 0)`
- `taskSuspend()` / `taskResume()` — return `ENOSYS`; POSIX has no portable
  way to suspend an arbitrary thread

**Cannot be implemented directly**

- `taskVarLib` — use `__thread` or `pthread_key_create()`
- `loadLib` (`loadModule`, `loadModuleAt`) — use `dlopen()`/`dlsym()`

**Behavioural differences to expect**

- No memory protection between tasks — they are threads in one process.
- Priority inversion protection is not implemented, so a low-priority task
  holding a mutex can block a high-priority one indefinitely.
- `taskDelete()` is implemented with `pthread_cancel()`, so it takes effect at
  the next cancellation point, not instantly.
- Timing is best-effort. Without `SCHED_FIFO` privilege it is ordinary Linux
  fair scheduling.

---

## 2.9 Reading order for the source

If you want to understand the implementation rather than just use it:

1. `lib/v2lpthread.h` — the data model (`task_t`)
2. `lib/v2ldebug.h` — how everything reports
3. `lib/lkernelLib.c` — `v2lin_init()` and the exception task; short
4. `lib/ltaskLib.c` — the core; `taskInit`, `taskActivate`,
   `translate_priority`, `task_wrapper`
5. `lib/lsemLib.c` — the mutex/condvar pattern every other object reuses
6. `lib/lmsgQLib.c`, `lib/lwdLib.c` — the same pattern applied again
