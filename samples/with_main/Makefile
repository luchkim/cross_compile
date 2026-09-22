#  Copyright (C) 2004, 2005, 2006 v2lin Team <http://v2lin.sf.net>
#
#  This file is part of the v2lin Library.
#  VxWorks is a registered trademark of Wind River Systems, Inc.
#
#  Initial implementation Gary S. Robertson, 2000, 2001.
#  Contributed by Andrew Skiba, skibochka@sourceforge.net, 2004.
#  Contributed by Mike Kemelmakher, mike@ubxess.com, 2005.
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
include ../defs.mk

# ---------------------------------------------------------------------------
#  with_main - the "plain Linux" entry point: the application keeps its own
#  main() and only has to call v2lin_init() before any other v2lin function.
#  It therefore links libv2lin but NOT libv2linmain.
# ---------------------------------------------------------------------------
EXES := with_main

with_main_OBJS := with_main.o

LDFLAGS += $(V2LIN_LDFLAGS)
LDLIBS  := $(V2LIN_LDLIBS) $(LDLIBS) #kim

$(EXES): $(V2LIN_SRCDIR)/libv2lin.a #kim

.PHONY: run
run: all
	@echo "== with_main =="
	./with_main

include $(top)/rules.mk
