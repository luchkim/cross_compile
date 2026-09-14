# Per-directory overrides for samples/.  Included after $(top)/defs.mk.
#
# The samples are only interesting when they print something, and everything
# they print goes through TRACEF(), so tracing is always compiled in here.
CPPFLAGS += -DDEBUG

# Uncomment to also trace entry/exit of every checked call (very verbose).
#CPPFLAGS += -DTRACE_IN_OUT
