# Beginner Guide: Port and Test a VxWorks Program on Linux with ZeroMQ

This guide shows a practical first step for moving a VxWorks-oriented program
to 64-bit ARM Linux using v2lin, then measuring application messaging with
ZeroMQ. Build and run the benchmark on the real Cortex-A53 or Cortex-A78 board.

v2lin is a source-compatibility layer, not a Linux operating-system builder.
It maps part of the VxWorks task, semaphore, queue, watchdog, and tick APIs to
POSIX/Linux. Linux hardware drivers, BSP code, interrupt handlers, and missing
VxWorks APIs must be ported separately.

## 1. Prepare the board toolchain

The build expects these programs:

```sh
aarch64-linux-gnu-gcc --version
aarch64-linux-gnu-ar --version
make --version
```

Install the AArch64 sysroot development package for ZeroMQ as well. The exact
package name depends on the board SDK. It must provide both `zmq.h` and
`libzmq.so` for the target, not the build host.

For native compilation on the board, use the board's `gcc`, `ar`, `make`, and
ZeroMQ development package instead. Override the project defaults when building:

```sh
make CC=gcc AR=ar
```

## 2. Build v2lin

From the v2lin project root:

```sh
make clean
make lib
```

This produces:

```text
lib/libv2lin.so       VxWorks API compatibility library
lib/libv2linmain.so   optional user_sysinit() startup main()
```

For the first port, use the ordinary Linux `main()` style. It gives the
application normal control over command-line parsing, files, network sockets,
and ZeroMQ setup.

## 3. Make the first source changes

In each VxWorks-oriented source file that uses v2lin calls, include:

```c
#include "vxw_hdrs.h"
```

Keep the v2lin-compatible calls that the library implements, for example:

```c
v2lin_init();
taskSpawn("WORKER", 100, 0, 0, worker, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
semTake(ready, WAIT_FOREVER);
msgQSend(queue, message, size, WAIT_FOREVER, MSG_PRI_NORMAL);
```

Call `v2lin_init()` once, before the first v2lin call. Do not call it from a
worker task.

Replace unsupported parts before testing:

| VxWorks dependency | Linux replacement |
| --- | --- |
| BSP or direct register access | board Linux driver, ioctl, sysfs, or device-specific SDK |
| ISR code | kernel driver, eventfd, poll/epoll, or a vendor interrupt API |
| `taskVarLib` | C `__thread` storage or POSIX thread-local storage |
| `loadModule()` | `dlopen()` and `dlsym()` |
| `taskSuspend()` / `taskResume()` | redesign around a semaphore or condition variable |

See [Using v2lin](03-using-v2lin.md) for the supported API subset and link
modes.

## 4. Create a separate ZeroMQ benchmark program

Do not put ZeroMQ into the v2lin library. Keep it in an application or test
program, so the v2lin compatibility layer remains independent of networking.

Create a directory next to the existing samples, for example
`benchmarks/zeromq/`, with a program called `zeromq_pingpong.c`. This minimal
example creates two local ZeroMQ PAIR sockets in one process and sends a fixed
message from a v2lin task to the main task.

```c
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <zmq.h>
#include "vxw_hdrs.h"

static void *context;
static void *sender;
static const char payload[] = "ping";

static int64_t monotonic_ns(void)
{
    struct timespec time_value;

    clock_gettime(CLOCK_MONOTONIC, &time_value);
    return (int64_t)time_value.tv_sec * 1000000000LL + time_value.tv_nsec;
}

static int sender_task(int unused1, int unused2, int unused3, int unused4,
                       int unused5, int unused6, int unused7, int unused8,
                       int unused9, int unused10)
{
    (void)unused1; (void)unused2; (void)unused3; (void)unused4; (void)unused5;
    (void)unused6; (void)unused7; (void)unused8; (void)unused9; (void)unused10;

    if (zmq_send(sender, payload, sizeof(payload), 0) != sizeof(payload))
        perror("zmq_send");
    return 0;
}

int main(void)
{
    void *receiver;
    char received[sizeof(payload)];
    int64_t started_ns;
    int64_t elapsed_ns;

    if (v2lin_init() != OK) {
        fprintf(stderr, "v2lin_init failed\n");
        return 1;
    }

    context = zmq_ctx_new();
    sender = zmq_socket(context, ZMQ_PAIR);
    receiver = zmq_socket(context, ZMQ_PAIR);
    if (context == NULL || sender == NULL || receiver == NULL ||
        zmq_bind(sender, "inproc://v2lin-benchmark") != 0 ||
        zmq_connect(receiver, "inproc://v2lin-benchmark") != 0) {
        perror("ZeroMQ setup");
        return 1;
    }

    started_ns = monotonic_ns();
    if (taskSpawn("ZMQ_SEND", 100, 0, 0, sender_task,
                  0, 0, 0, 0, 0, 0, 0, 0, 0, 0) == ERROR ||
        zmq_recv(receiver, received, sizeof(received), 0) < 0) {
        perror("benchmark");
        return 1;
    }
    elapsed_ns = monotonic_ns() - started_ns;

    printf("inproc send latency: %lld ns\n", (long long)elapsed_ns);
    zmq_close(receiver);
    zmq_close(sender);
    zmq_ctx_term(context);
    return 0;
}
```

This is a functional smoke test and a starting measurement, not a reliable
benchmark result. It includes task creation and scheduling time in one sample.
A real benchmark must warm up, repeat many times, and report a distribution.

## 5. Build the benchmark

Adapt these paths to the v2lin checkout and the board SDK:

```sh
aarch64-linux-gnu-gcc -D_GNU_SOURCE -I../lib -I/path/to/target/zeromq/include \
    -g -O2 -pthread -o zeromq_pingpong zeromq_pingpong.c \
    -L../lib -L/path/to/target/zeromq/lib \
    -lv2lin -lzmq -pthread -lrt -ldl
```

The order matters: object files appear before libraries; `-lv2lin` appears
before its system libraries. An application that uses `user_sysinit()` instead
of its own `main()` must link `-lv2linmain -lv2lin -lzmq`.

If the board loader cannot find the shared libraries, install v2lin and ZeroMQ
under the board's normal library directory, then run `ldconfig` when supported.
For temporary development only, set a loader path explicitly:

```sh
export LD_LIBRARY_PATH=/opt/v2lin/lib:/opt/zeromq/lib
```

## 6. Run functional checks before performance tests

Copy the v2lin libraries and the benchmark to the board. On the board, first
confirm the dynamic loader sees the expected libraries:

```sh
ldd ./zeromq_pingpong
./zeromq_pingpong
```

Then run the v2lin regression suite on the board:

```sh
make test
```

The existing suite checks functional behavior; it is not a performance suite.
Known historical failures are described in [Running the tests](04-running-the-tests.md).
Do not use its elapsed time as a benchmark value.

## 7. Turn the smoke test into a benchmark

Use the same message pattern for at least these cases:

| Case | What it measures |
| --- | --- |
| `inproc://` PAIR, one process | v2lin task scheduling plus ZeroMQ in-process overhead |
| `ipc://` PAIR, two processes | Unix-domain socket transport and process scheduling |
| `tcp://127.0.0.1` PAIR, two processes | local TCP stack overhead |
| board-to-board TCP | network, driver, and system latency |

For every case:

1. Warm up at least 1,000 exchanges before recording results.
2. Measure at least 10,000 round trips with `CLOCK_MONOTONIC`.
3. Record minimum, median, p95, p99, maximum, and messages per second.
4. Test several payload sizes: 64 bytes, 256 bytes, 1 KiB, 4 KiB, and the
   expected production size.
5. Record board model, Cortex core, RAM, Linux kernel version, compiler version,
   compiler flags, CPU governor, and whether CPU affinity was used.
6. Repeat while the board is idle and while the expected production workload is
   active.

For a two-way test, send a sequence number from one endpoint, echo it back at
the other endpoint, and measure the round-trip time. Divide the median by two
only as an approximate one-way latency; scheduling and ZeroMQ transport are
not necessarily symmetric.

## 8. Check real-time assumptions

v2lin requests `SCHED_FIFO` or `SCHED_RR` priorities. The board process needs
`CAP_SYS_NICE` or an appropriate `RLIMIT_RTPRIO` to obtain them. Otherwise the
program can still run, but Linux uses ordinary scheduling and its latency
figures do not demonstrate real-time behavior.

Keep a timeout in every benchmark receive operation. A missing peer or failed
task should produce a clear test failure, not an indefinite hang.

## 9. Decide readiness

Treat the port as ready for the next stage only when all of these are true:

- The v2lin functional suite has no unexpected failures on the board.
- Your ported application has tests for every replaced BSP, driver, and
  unsupported API behavior.
- The ZeroMQ benchmark reports repeatable latency percentiles under expected
  system load.
- The worst-case latency and loss behavior meet the board project's requirement.
- The tests have been repeated after changing kernel, SDK, compiler, ZeroMQ, or
  board configuration.
