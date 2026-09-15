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

top := .
include $(top)/defs.mk

# ===========================================================================
#  Top level orchestration.  Run `make help` for the list of targets.
# ===========================================================================

PUBLIC_HEADERS := \
	lib/vxw_hdrs.h \
	lib/vxw_defs.h \
	lib/v2lpthread.h \
	lib/v2ldebug.h \
	lib/internal.h \
	lib/sysLib.h \
	lib/tickLib.h \
	lib/taskVarLib.h \
	lib/loadLib.h

INSTALL_LIBS := \
	lib/libv2lin.so \
	lib/libv2lin.a \
	lib/libv2linmain.so \
	lib/libv2linmain.a

.PHONY: all lib samples tests test check run clean distclean install uninstall \
        help tags TODO defined tgz

all: lib samples tests

# --- the three build products -----------------------------------------------
lib:
	$(MAKE) -C lib

samples: lib
	$(MAKE) -C samples

tests: lib
	$(MAKE) -C tests

# --- running ----------------------------------------------------------------
test check: tests
	$(MAKE) -C tests run

run: samples
	$(MAKE) -C samples run

# --- installation -----------------------------------------------------------
install: lib
	$(INSTALL) -d $(DESTDIR)$(libdir) $(DESTDIR)$(includedir)
	$(INSTALL) -m 0755 $(INSTALL_LIBS) $(DESTDIR)$(libdir)
	$(INSTALL) -m 0644 $(PUBLIC_HEADERS) $(DESTDIR)$(includedir)

uninstall:
	$(RM) $(addprefix $(DESTDIR)$(libdir)/,$(notdir $(INSTALL_LIBS)))
	$(RM) -r $(DESTDIR)$(includedir)

# --- housekeeping -----------------------------------------------------------
clean:
	$(MAKE) -C lib clean
	$(MAKE) -C samples clean
	$(MAKE) -C tests clean

distclean:
	$(MAKE) -C lib distclean
	$(MAKE) -C samples distclean
	$(MAKE) -C tests distclean
	$(RM) tags .deps.mk

tgz: distclean
	tar czf ../`basename $(CURDIR)`.tgz -C .. `basename $(CURDIR)`

tags:
	ctags -R lib samples tests

TODO:
	-grep TODO -w . -rn -1 --color --exclude-dir=.svn

defined:
	@echo "Functions declared by the v2lin public headers:"
	@ctags -x --c-kinds=p --file-scope=no lib/*.h | cut -f 1 -d ' '

help:
	@echo "v2lin build targets"
	@echo "  make                 build lib, samples and tests"
	@echo "  make lib             build lib/libv2lin.{so,a} and lib/libv2linmain.{so,a}"
	@echo "  make samples         build the example programs"
	@echo "  make tests           build the test programs"
	@echo "  make test            build and run the test suite (alias: check)"
	@echo "  make run             run the sample programs"
	@echo "  make install         install into \$$(prefix) [$(prefix)]"
	@echo "  make clean           remove objects and build products"
	@echo "  make distclean       clean + logs, tags, editor backups"
	@echo ""
	@echo "AArch64 Linux build options"
	@echo "  DEBUG=1              compile in the TRACEF()/TRACEV() tracing"
	@echo "  TRACE_IN_OUT=1       also trace CHK() entry/exit"
	@echo "  OPTIM=-O2            change the optimisation level"
	@echo "  prefix=/usr          change the install prefix"
