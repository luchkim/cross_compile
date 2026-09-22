top := ..
include $(top)/defs.mk

CXXEXES := static_smoke #kim

static_smoke_OBJS := static_smoke.o #kim
static_smoke_LDLIBS := $(V2LIN_LDLIBS) #kim

static_smoke: $(V2LIN_SRCDIR)/libv2lin.a #kim

.PHONY: run
run: static_smoke
	./static_smoke

include $(top)/rules.mk