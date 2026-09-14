# Per-directory overrides for samples/shared_library/.
# load.c reports what it loaded through TRACEF(), so tracing must be on.
CPPFLAGS += -DDEBUG

# Uncomment to also trace entry/exit of every checked call (very verbose).
#CPPFLAGS += -DTRACE_IN_OUT
