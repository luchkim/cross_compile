#  Copyright (C) 2004, 2005, 2006 v2lin Team <http://v2lin.sf.net>
#
#  This file is part of the v2lin Library.
#  VxWorks is a registered trademark of Wind River Systems, Inc.
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

# ===========================================================================
#  defs.mk - build configuration shared by every directory of the tree.
#
#  Each sub-Makefile sets `top` (relative path back to the source root), then
#  includes this file FIRST, its own local defs.mk SECOND and
#  $(top)/rules.mk LAST.
#
#  Everything below can be overridden on the command line, e.g.
#      make CC=arm-linux-gnueabihf-gcc OPTIM=-O2 DEBUG=0 V=1
# ===========================================================================

ifndef top
$(error `top' is not set - include $$(top)/defs.mk from a sub-Makefile)
endif

# --- guard against double inclusion (samples/with_main pulls in two defs) ---
ifndef V2LIN_DEFS_MK_INCLUDED
V2LIN_DEFS_MK_INCLUDED := 1

# ---------------------------------------------------------------------------
#  Toolchain
# ---------------------------------------------------------------------------
# Kernel-style toolchain prefix, e.g. CROSS_COMPILE=arm-linux-gnueabihf-
# An explicit CC=/AR= on the command line still wins over it.
CROSS_COMPILE ?=

# `CC ?= gcc' would not take effect: make pre-defines CC as `cc', so the
# variable already counts as defined.  Only replace make's own default.
ifeq ($(origin CC),default)
CC := $(CROSS_COMPILE)gcc
endif
AR       = $(CROSS_COMPILE)ar
ARFLAGS  = rcs
RM       = rm -f
INSTALL ?= install

# ---------------------------------------------------------------------------
#  Installation layout (used by `make install`)
# ---------------------------------------------------------------------------
prefix      ?= /usr/local
exec_prefix ?= $(prefix)
libdir      ?= $(exec_prefix)/lib
includedir  ?= $(prefix)/include/v2lin

# ---------------------------------------------------------------------------
#  Build knobs
# ---------------------------------------------------------------------------

# DEBUG=1 compiles in the TRACEF()/TRACEV() tracing macros of v2ldebug.h.
# tests/ forces it on: the pass/fail verdict is derived from the "ERROR"
# lines those macros write to stderr.
DEBUG ?= 0

# TRACE_IN_OUT=1 additionally traces entry/exit of every CHK()-wrapped call.
TRACE_IN_OUT ?= 0

# -O0 keeps the (thread-timing sensitive) test suite reproducible and the
# stack frames gdb-friendly.
OPTIM ?= -O0

# V=1 echoes full command lines instead of the short "  CC   foo.o" form.
V ?= 0

# ---------------------------------------------------------------------------
#  Where the library itself lives
# ---------------------------------------------------------------------------
V2LIN_SRCDIR := $(top)/lib
V2LIN_LIBDIR := $(abspath $(top)/lib)

# ---------------------------------------------------------------------------
#  Preprocessor flags
# ---------------------------------------------------------------------------
CPPFLAGS += -I$(V2LIN_SRCDIR)

# gettid(), pthread_mutex_timedlock(), TIMEVAL_TO_TIMESPEC(), __BEGIN_DECLS
CPPFLAGS += -D_GNU_SOURCE

# Selects the user_sysinit()/user_syskill() entry point style over plain
# main().  See Notes/02-understanding-v2lin.md.
CPPFLAGS += -D_USR_SYS_INIT_KILL

ifeq ($(DEBUG),1)
CPPFLAGS += -DDEBUG
endif

ifeq ($(TRACE_IN_OUT),1)
CPPFLAGS += -DTRACE_IN_OUT
endif

# ---------------------------------------------------------------------------
#  Compiler flags
# ---------------------------------------------------------------------------
CFLAGS += -g $(OPTIM)
CFLAGS += -fPIC
CFLAGS += -pthread
CFLAGS += -fmessage-length=0

# The test programs share globals through tentative definitions in several
# translation units (e.g. test_child_id, queue1_id).  That was legal-by-default
# until gcc 10 switched to -fno-common, so ask for the old behaviour back.
CFLAGS += -fcommon

# The 2000-2006 sources predate warnings gcc now enables by default; they are
# noisy but harmless here, so they are demoted instead of rewriting the code.
V2LIN_WARNINGS ?= -Wall \
                  -Wno-format \
                  -Wno-unused-label \
                  -Wno-unused-variable \
                  -Wno-unused-but-set-variable \
                  -Wno-unused-function \
                  -Wno-unused-value
CFLAGS += $(V2LIN_WARNINGS)

# ---------------------------------------------------------------------------
#  Linker flags
# ---------------------------------------------------------------------------
#  -rpath bakes the in-tree lib/ directory into every binary so samples and
#  tests can be started directly, without exporting LD_LIBRARY_PATH.  The path
#  is absolute and local to this machine, so pass V2LIN_RPATH= (empty) when
#  building binaries that will be deployed on a target.
V2LIN_RPATH ?= -Wl,-rpath,$(V2LIN_LIBDIR)

# Link against the in-tree shared libraries.
V2LIN_LDFLAGS  := -L$(V2LIN_SRCDIR) $(V2LIN_RPATH)
V2LIN_LDLIBS   := -lv2lin
V2LMAIN_LDLIBS := -lv2linmain

LDLIBS += -pthread -lrt -ldl

# ---------------------------------------------------------------------------
#  Pretty printing
# ---------------------------------------------------------------------------
ifeq ($(V),1)
  Q :=
  E := @true
else
  Q := @
  E := @echo
endif

# `all' lives in rules.mk, which is included last, so name it explicitly here
# instead of letting make pick whichever rule happens to be read first.
.DEFAULT_GOAL := all

endif # V2LIN_DEFS_MK_INCLUDED
