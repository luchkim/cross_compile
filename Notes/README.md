# v2lin Notes

Working notes for **v2lin 0.2** — the library that lets Wind River VxWorks(R)
application code be built and run on Linux on top of POSIX threads.

These notes were written while modernising the build system so the 2006
sources compile, link and run on a current Linux toolchain (gcc 13, glibc
2.39). They are meant to be read in order, but each one stands alone.

| #   | Note                                                     | Read it when you want to…                                                     |
| --- | -------------------------------------------------------- | ----------------------------------------------------------------------------- |
| 1   | [Build system](01-build-system.md)                       | build the tree, add a file, change a flag, cross-compile                      |
| 2   | [Understanding v2lin](02-understanding-v2lin.md)         | know what the library actually does and how it maps VxWorks onto Linux        |
| 3   | [Using v2lin in your own application](03-using-v2lin.md) | port a VxWorks program, pick a link mode, avoid the known traps               |
| 4   | [Running the tests](04-running-the-tests.md)             | run the suite, read a log, understand the known failures                      |
| 5   | [Modernisation log](05-modernisation-log.md)             | know at a glance what was changed in this tree and why                        |
| 6   | [File-by-file change list](06-file-change-list.md)       | **reproduce these changes in another checkout** — exact before/after per file |

Note 5 is the summary; **note 6 is the one to use when applying these changes
to a different copy of the source.** Note 6 is backed by
[`v2lin-modernisation.patch`](v2lin-modernisation.patch), a real unified diff
against the pristine 2006 sources.

## 30-second version

```sh
make            # build lib/, samples/ and tests/
make test       # build everything, then run the test suite
make run        # run the sample programs
make help       # list every target and build knob
```

v2lin is **Linux-only**. It uses `pthreads`, `clock_getres()`, `/proc/uptime`
and `SCHED_FIFO`/`SCHED_RR`, so it does not build on Windows or macOS. If you
are on Windows, see the "Building on Windows" section of
[Build system](01-build-system.md).

## Where things live

```
defs.mk               shared build configuration (flags, paths, knobs)
rules.mk              shared compile/link/clean rules
Makefile              top-level orchestration

lib/                  the library itself
  Makefile            -> libv2lin.{so,a}, libv2linmain.{so,a}
  vxw_hdrs.h          the public VxWorks API surface
  vxw_defs.h          VxWorks constants and error codes
  v2lpthread.h        the task control block (task_t / WIND_TCB)
  v2ldebug.h          TRACEF/TRACEV/CHK/CHK0 tracing and checking macros
  ltaskLib.c          taskLib   - tasks   -> pthreads
  lsemLib.c           semLib    - semaphores -> mutex + condvar
  lmsgQLib.c          msgQLib   - message queues
  lwdLib.c            wdLib     - watchdog timers
  lkernelLib.c        kernelLib - v2lin_init(), round-robin control
  v2ltime.c           tickLib/sysLib - tickGet/tickSet/sysClkRateGet
  main_impl.c         the default main() (goes into libv2linmain)

samples/              worked examples, one per integration style
tests/                the regression suite
Notes/                you are here
```
