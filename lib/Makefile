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
#  libv2lin - the VxWorks API emulation itself.
#
#  loadLib.c and taskVarLib.c are deliberately NOT built: they are empty
#  stubs for the two VxWorks facilities that have no direct POSIX equivalent
#  (see README).  Use dlopen()/pthread_key_create() instead.
# ---------------------------------------------------------------------------
V2LIN_OBJS := \
	lkernelLib.o \
	ltaskLib.o \
	lmsgQLib.o \
	lsemLib.o \
	lwdLib.o \
	v2ldebug.o \
	v2ltime.o

# ---------------------------------------------------------------------------
#  libv2linmain - the default main() that drives user_sysinit()/user_syskill().
#  Applications that provide their own main() link against libv2lin only.
# ---------------------------------------------------------------------------
V2LMAIN_OBJS := main_impl.o

ARLIBS := libv2lin.a libv2linmain.a
SHLIBS := libv2lin.so libv2linmain.so

libv2lin.a_OBJS      := $(V2LIN_OBJS)
libv2lin.so_OBJS     := $(V2LIN_OBJS)
libv2linmain.a_OBJS  := $(V2LMAIN_OBJS)
libv2linmain.so_OBJS := $(V2LMAIN_OBJS)

# libv2linmain calls taskInit()/taskActivate(), which live in libv2lin.
libv2linmain.so_LDFLAGS := -L.
libv2linmain.so_LDLIBS  := -lv2lin

# libv2lin.so must exist before libv2linmain.so can resolve against it
# (order-only, so it is not passed to the linker a second time).
libv2linmain.so: | libv2lin.so

include $(top)/rules.mk
