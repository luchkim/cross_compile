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

top := ../..

include $(top)/defs.mk
include defs.mk

# ---------------------------------------------------------------------------
#  The sample module is emitted in both archive and shared-object forms.  The
#  load executable links the archive so v2lin consumers remain static.
# ---------------------------------------------------------------------------
ARLIBS := libsample_lib.a #kim
SHLIBS := libsample_lib.so #kim
EXES   := load

libsample_lib.a_OBJS  := sample_lib.o #kim
libsample_lib.so_OBJS := sample_lib.o #kim
load_OBJS             := load.o

LDLIBS  := libsample_lib.a $(V2LIN_LDLIBS) $(LDLIBS) #kim

load: $(V2LIN_SRCDIR)/libv2lin.a libsample_lib.a #kim

.PHONY: run
run: all
	@echo "== shared_library/load =="
	./load

include $(top)/rules.mk
