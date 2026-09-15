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
#

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

# ===========================================================================
#  rules.mk - the compile/link/clean rules shared by every leaf directory.
#
#  A leaf Makefile declares WHAT to build, never HOW:
#
#      top    := ..
#      include $(top)/defs.mk
#      include defs.mk                 # optional per-directory overrides
#
#      ARLIBS := libfoo.a              # static archives
#      SHLIBS := libfoo.so             # shared objects
#      EXES   := prog                  # executables
#
#      libfoo.a_OBJS  := a.o b.o
#      libfoo.so_OBJS := a.o b.o
#      prog_OBJS      := main.o
#      prog_LDLIBS    := -lfoo         # optional, per target
#      prog_LDFLAGS   := -L.           # optional, per target
#
#      include $(top)/rules.mk
#
#  Header dependencies are generated automatically by gcc (-MMD -MP), so
#  editing a .h rebuilds exactly the objects that include it.
# ===========================================================================

ARLIBS ?=
SHLIBS ?=
EXES   ?=

TARGETS ?= $(ARLIBS) $(SHLIBS) $(EXES)

# Every object mentioned by any target in this directory.
OBJS := $(sort $(foreach t,$(ARLIBS) $(SHLIBS) $(EXES),$($(t)_OBJS)))

# Only depend-track objects built here; objects pulled in from another
# directory (e.g. ../lib/main_impl.o) are that directory's business.
LOCAL_OBJS := $(filter-out ../%,$(OBJS))
DEPS       := $(LOCAL_OBJS:.o=.d)

.PHONY: all clean distclean depend
.SUFFIXES:

all: $(TARGETS)

# ---------------------------------------------------------------------------
#  Compilation
# ---------------------------------------------------------------------------
%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -MF $(@:.o=.d) -c -o $@ $<

# ---------------------------------------------------------------------------
#  Link rules.  Secondary expansion resolves each target's <target>_OBJS
#  list after $@ is known, avoiding generated rules.
# ---------------------------------------------------------------------------
.SECONDEXPANSION:

$(ARLIBS): $$($$@_OBJS)
	$(RM) $@
	$(AR) $(ARFLAGS) $@ $^

$(SHLIBS): $$($$@_OBJS)
	$(CC) $(CFLAGS) -shared -Wl,-soname,$(notdir $@) -o $@ $^ \
		$(LDFLAGS) $($@_LDFLAGS) $($@_LDLIBS) $(LDLIBS)

$(EXES): $$($$@_OBJS)
	$(CC) $(CFLAGS) -o $@ $^ \
		$(LDFLAGS) $($@_LDFLAGS) $($@_LDLIBS) $(LDLIBS)

# ---------------------------------------------------------------------------
#  Housekeeping
# ---------------------------------------------------------------------------
clean:
	$(RM) $(TARGETS) $(LOCAL_OBJS) $(DEPS) $(EXTRA_CLEAN)

distclean: clean
	$(RM) *.log *.bak *~ *.orig tags core core.*

# `make depend` is a no-op kept for backwards compatibility: dependencies are
# now produced as a side effect of every compile.
depend:
	@echo "dependencies are generated automatically (-MMD -MP)"

-include $(DEPS)
