# 4. Running the tests

---

## 4.1 Run everything

```sh
make test          # from the top of the tree; `make check` is a synonym
```

Expected output on a healthy tree:

```
== test (full regression suite, takes up to ~1 min) ==
Test finished
   exit code       : 0
   log lines       : 240
   known failures  : 6 (see known-failures.txt)
   PASSED
== test_sem ==
   PASSED
== test_time ==
   PASSED
Test suite finished.
```

`make test` exits non-zero if any program crashes, returns non-zero, or
produces a failure that is not in the known-failures baseline.

## 4.2 Run one program at a time

From `tests/`:

```sh
make run-test      # the full regression suite
make run-sem       # the semaphore state-machine test
make run-time      # the tick/clock test
make run-demo      # the MontaVista producer/consumer demo (does not self-terminate)
```

Or run the binaries directly — they are linked with an rpath, so no
`LD_LIBRARY_PATH` is needed:

```sh
cd tests
./test 2> test.log
./test_sem
./test_time
```

---

## 4.3 What each program covers

| Program | Sources | Covers |
|---|---|---|
| `test` | `test.c` + `test_tasks.c`, `test_semaphores.c`, `test_mutexes.c`, `test_msgq.c`, `test_watchdog.c` | the whole API. A "sequencer" task (`TESTER`) drives ten worker tasks through a scripted handshake so the interleaving is reproducible. |
| `test_sem` | `test_sem.c` | a semaphore state machine: binary / counting / mutex semaphores, same-thread vs cross-thread give and take, blocking and unblocking, and the error returned when a thread gives a mutex it does not own. |
| `test_time` | `test_time.c` | `sysClkRateGet()`, `tickGet()`, `tickSet()`, and that `taskDelay()` advances the tick count. |
| `demo` | `demo.c` | the original MontaVista producer/consumer example — one producer, two consumers, dynamic message blocks. Built but not part of `make run` because it never terminates on its own. |

`test` runs in phases: tasks → semaphores → mutexes → message queues →
watchdogs. `test.c` arms a 30 s `pthread_mutex_timedlock()` watchdog around
the whole thing, so a deadlock produces a timeout rather than a hang.

`tests/tasks_sub.c` is **not** built — it is a superseded copy of task bodies
that now live in the per-feature files.

---

## 4.4 How a run is judged

The `CHK()` / `CHK0()` macros do not abort. They write one line per failed
check to stderr:

```
test_tasks.c:151 test_tasks_delete() ERROR: taskIsReady(temp_taskid)
	errno=0(0) OK
```

So the verdict is: **collect the set of `ERROR:` expressions in the log and
compare it against a baseline.** That is what `tests/check-log.sh` does:

* a failure listed in `tests/known-failures.txt` → tolerated, counted as "known"
* a failure **not** listed → the run fails, and the expression is printed
* a listed failure that did **not** occur → reported as "no longer failing",
  so the baseline can be trimmed

This keeps genuine regressions visible without drowning them in the
historical noise of an unmaintained 2006 codebase.

Running the checker by hand:

```sh
cd tests
sh check-log.sh test.log known-failures.txt
sh check-log.sh test_sem.log            # no baseline: any ERROR fails
```

This is also why `tests/defs.mk` forces `-DDEBUG` on: without it the tracing
macros compile to nothing, the log is empty, and every run would "pass"
vacuously.

---

## 4.5 The six known failures

All six are defects in the **test code**, inherited from the last upstream
release. They are not caused by the modernised build. The authoritative list
is `tests/known-failures.txt`; the reasoning is here.

### `taskIsReady(temp_taskid)` and `!taskIsReady(temp_taskid)`
`test_tasks.c`, `test_tasks_delete()`

At the point of the first check, `temp_task` has signalled `complt1` and
entered a `taskDelay(50)` loop — so it is in the `DELAY` state and
`taskIsReady()` correctly returns false. The two assertions also expect
opposite answers in equivalent situations, so one of them must fail whatever
the library does. The test needs a handshake that pins down the temporary
task's state; correcting it means deciding what VxWorks `taskIsReady()` should
report for a delaying task, which is a semantics question, not a build one.

### `test_semaphores_1_status==OK` and `test_semaphores_1()`
`test_semaphores.c`, `test_semaphores_1()`

```c
CHK(t = taskSpawn(NULL, 20, 0, 0, test_sem_1_sub, ...));
semGive(s1);
CHK(test_semaphores_1_status==OK);   /* <-- no synchronisation */
```

The spawned task is not guaranteed to have been scheduled — let alone to have
returned from `semTake()` and set the flag — by the time the parent reads it.
The commented-out `taskDelay(0)` calls on either side show the original author
was aware. A correct fix is a completion semaphore that the sub-task gives and
the parent takes with a timeout.

### `pthread_mutex_timedlock(&test_finished,&ts)`
`test.c`, `test_wait()`

`test_wait()` decides success by inspecting `errno`, but `pthread_*` functions
report through their **return value** and leave `errno` untouched. The
`CHK0()` therefore logs the non-zero return while the `switch (errno)` below
it still takes the `case OK:` branch and prints "Test finished". The check and
the verdict disagree with each other.

### `3 == taskList(stderr, 0)`
`test.c`, `test_wait()`

A hard-coded expectation that exactly three tasks survive the run. The actual
residue depends on how the phases tear down, and does not match.

### Updating the baseline

If you fix one of these, delete its line from `tests/known-failures.txt`. The
checker will tell you when a listed failure stops happening:

```
   no longer failing: 1 - please remove from known-failures.txt
     + test_semaphores_1()
```

**Do not trim the baseline on the strength of a single run.** Two of the six
are timing dependent and simply do not fire in a slower environment — running
the armhf build under `qemu-arm` reports `pthread_mutex_timedlock(...)` and
`3 == taskList(stderr, 0)` as "no longer failing", because the emulation
changes the interleaving. Remove an entry only when you have actually fixed
the underlying test, not when it merely stopped reproducing.

---

## 4.6 Reading a log

`tests/test.log` (stderr of the last `./test`) is the primary artifact.
`make clean` removes it.

```
thread=21 task=0x7ffc10261220 tUsrRoot     <- printed when the running thread changes
time=2026-09-11 15:33:47.314043            <- absolute time, printed once
uptime=0.512000 s +0.011000                <- since start, and since previous trace
test_tasks.c:151 test_tasks_delete() ...   <- file:line function()
	errno=0(0) OK                          <- errno rendered as a VxWorks status name
```

Useful one-liners:

```sh
grep -w ERROR tests/test.log                     # every failed check
sed -n 's/.*ERROR: //p' tests/test.log | sort -u # just the expressions
grep -n "^thread=" tests/test.log                # task switch points
awk '/uptime=/{print}' tests/test.log | tail     # where time went
```

`errno=1(1) Operation not permitted` is **expected** when running
unprivileged: it is the library failing to install `SCHED_FIFO` priorities.
It does not fail the run. See
[note 3](03-using-v2lin.md#35-real-time-scheduling-privileges).

---

## 4.7 Debugging a failing test

```sh
cd tests
make gdb                       # gdb with run.gdb: run, then `info threads`
```

`info threads` maps one-to-one onto the v2lin task list. From a breakpoint you
can call the introspection helpers directly:

```
(gdb) call taskList(stderr, 0)
(gdb) call semList(stderr, 0)
(gdb) call msgQList(stderr, 0)
```

For more detail in the log, rebuild with entry/exit tracing:

```sh
make -C .. clean
make -C .. TRACE_IN_OUT=1
make run-test
```

Because the suite is timing sensitive, a failure that does not reproduce is
usually a scheduling race rather than a logic bug. Try:

```sh
for i in $(seq 10); do ./test 2>/dev/null; echo "run $i -> $?"; done
```

and compare `sed -n 's/.*ERROR: //p' test.log | sort -u` between runs.

---

## 4.8 Running the tests in a container

The suite needs a Linux host. From Windows or macOS:

```sh
docker run --rm -v "$PWD:/src" -w /src ubuntu:24.04 \
  bash -lc "apt-get update -qq && apt-get install -y -qq build-essential && make test"
```

The default container has no real-time scheduling privileges, which is fine —
the suite passes either way. Add `--cap-add=sys_nice --ulimit rtprio=99` only
if you are specifically investigating priority behaviour.
