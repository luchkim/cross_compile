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

top := ..
include $(top)/defs.mk
include defs.mk

SUBDIRS := with_main shared_library

# ---------------------------------------------------------------------------
#  with_sysinit - the "VxWorks style" entry point: the application supplies
#  user_sysinit()/user_syskill() and links libv2linmain, which provides main().
# ---------------------------------------------------------------------------
EXES := with_sysinit

with_sysinit_OBJS := with_sysinit.o

LDFLAGS += $(V2LIN_LDFLAGS)
LDLIBS  := $(V2LMAIN_LDLIBS) $(V2LIN_LDLIBS) $(LDLIBS)

$(EXES): $(V2LIN_SRCDIR)/libv2lin.so $(V2LIN_SRCDIR)/libv2linmain.so

.PHONY: $(SUBDIRS) run

all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

run: all
	@echo "== with_sysinit =="
	./with_sysinit
	$(MAKE) -C with_main run
	$(MAKE) -C shared_library run

include $(top)/rules.mk

# rules.mk owns clean/distclean here; extend both into the sub-directories.
clean:     clean-subdirs
distclean: distclean-subdirs

.PHONY: clean-subdirs distclean-subdirs
clean-subdirs:
	for d in $(SUBDIRS); do $(MAKE) -C $$d clean; done

distclean-subdirs:
	for d in $(SUBDIRS); do $(MAKE) -C $$d distclean; done
