#  Copyright (C) 2004, 2005, 2006 v2lin Team <http://v2lin.sf.net>
#
#  This file is part of the v2lin Library.
#  VxWorks is a registered trademark of Wind River Systems, Inc.
#
#  Contributed by Constantine Shulyupin, conan.sh@gmail.com, 2006.
#
#  The v2lin library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  The v2lin Library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.

top := ..
include $(top)/defs.mk
include defs.mk

# ---------------------------------------------------------------------------
#  Test programs
#
#  `test`      - the full regression suite (tasks, semaphores, mutexes,
#                message queues, watchdogs), driven by user_sysinit().
#  `test_sem`  - focused semaphore stress test.
#  `test_time` - sysClkRateGet()/tickGet()/tickSet()/taskDelay() smoke test.
#  `demo`      - the original MontaVista demo application.
#
#  tasks_sub.c is NOT built: it is a superseded copy of the task bodies that
#  now live in test_msgq.c / test_mutexes.c / test_semaphores.c and would
#  collide with them at link time.
# ---------------------------------------------------------------------------
EXES := test test_sem test_time demo

test_OBJS := \
	test.o \
	test_tasks.o \
	test_semaphores.o \
	test_msgq.o \
	test_watchdog.o \
	test_mutexes.o

test_sem_OBJS  := test_sem.o
test_time_OBJS := test_time.o
demo_OBJS      := demo.o

# Every test program supplies user_sysinit()/user_syskill(), so they all need
# the main() from libv2linmain in addition to the emulation library itself.
LDFLAGS += $(V2LIN_LDFLAGS)
LDLIBS  := $(V2LMAIN_LDLIBS) $(V2LIN_LDLIBS) $(LDLIBS)

$(EXES): $(V2LIN_SRCDIR)/libv2lin.so $(V2LIN_SRCDIR)/libv2linmain.so

# Logs produced by the `run` target.
EXTRA_CLEAN := test.log test_sem.log test_time.log demo.log

# ---------------------------------------------------------------------------
#  Running
# ---------------------------------------------------------------------------
#  The suite is timing sensitive: `nice` keeps it from fighting the rest of
#  the machine, and a 30 s watchdog inside test.c bounds the total runtime.
#
#  A run is judged by check-log.sh, which compares the CHK()/CHK0() failures
#  found in the log against tests/known-failures.txt.  Only failures that are
#  not in that baseline fail the build.
# ---------------------------------------------------------------------------
CHECK_LOG      := /bin/sh ./check-log.sh
KNOWN_FAILURES := known-failures.txt

.PHONY: run run-test run-sem run-time run-demo gdb

run: run-test run-sem run-time
	@echo "Test suite finished."

run-test: test
	@echo "== test (full regression suite, takes up to ~1 min) =="
	$(Q)nice -n 15 ./test 2> test.log; \
	  rc=$$?; \
	  echo "   exit code       : $$rc"; \
	  echo "   log lines       : `wc -l < test.log`"; \
	  if [ $$rc -ne 0 ]; then echo "   FAILED: non-zero exit status"; exit 1; fi
	$(Q)$(CHECK_LOG) test.log $(KNOWN_FAILURES)

run-sem: test_sem
	@echo "== test_sem =="
	$(Q)./test_sem > test_sem.log 2>&1; \
	  rc=$$?; \
	  if [ $$rc -ne 0 ]; then echo "   FAILED: exit code $$rc"; exit 1; fi
	$(Q)$(CHECK_LOG) test_sem.log

run-time: test_time
	@echo "== test_time =="
	$(Q)./test_time > test_time.log 2>&1; \
	  rc=$$?; \
	  if [ $$rc -ne 0 ]; then echo "   FAILED: exit code $$rc"; exit 1; fi
	$(Q)$(CHECK_LOG) test_time.log

# The MontaVista demo is interactive-ish and never terminates on its own, so
# it is built but not part of `make run`.
run-demo: demo
	$(Q)./demo

gdb: test
	gdb -q --command run.gdb ./test

include $(top)/rules.mk
