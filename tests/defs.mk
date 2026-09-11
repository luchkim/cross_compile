# Per-directory overrides for tests/.  Included after $(top)/defs.mk.
#
# The test suite reports failures through the TRACEF()-based CHK()/CHK0()
# macros, so tracing must always be compiled in here regardless of the
# global DEBUG setting - `make run` greps the captured stderr for "ERROR".
CPPFLAGS += -DDEBUG

# Uncomment to also trace entry/exit of every checked call (very verbose).
#CPPFLAGS += -DTRACE_IN_OUT
