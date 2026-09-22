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
#  This project is built for 64-bit ARM Linux from an AMD64 Linux host.
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
# GNU AArch64 cross tools.  Command-line CC=, CXX=, and AR= assignments still win.
CC       = aarch64-linux-gnu-gcc
CXX      = aarch64-linux-gnu-g++ #kim
AR       = aarch64-linux-gnu-ar
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

# Link executables fully statically by default. Set STATIC=0 only when the
# target sysroot lacks static system archives.
STATIC ?= 1#kim

# ---------------------------------------------------------------------------
#  Where the library itself lives
# ---------------------------------------------------------------------------
V2LIN_SRCDIR := $(top)/lib

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

CXXFLAGS += -g $(OPTIM) #kim
CXXFLAGS += -pthread #kim
CXXFLAGS += -fmessage-length=0 #kim
CXXFLAGS += -std=c++17 #kim

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
# Link against the in-tree static archives explicitly. Archive order matters:
# libv2linmain.a must appear before libv2lin.a for user_sysinit() programs.
V2LIN_LDFLAGS  := #kim
V2LIN_LDLIBS   := $(V2LIN_SRCDIR)/libv2lin.a #kim
V2LMAIN_LDLIBS := $(V2LIN_SRCDIR)/libv2linmain.a #kim

ifeq ($(STATIC),1)#kim
LDFLAGS += -static#kim
endif#kim

SHARED_LDFLAGS := #kim

LDLIBS += -pthread -lrt #kim

# `all' lives in rules.mk, which is included last, so name it explicitly here
# instead of letting make pick whichever rule happens to be read first.
.DEFAULT_GOAL := all

endif # V2LIN_DEFS_MK_INCLUDED
