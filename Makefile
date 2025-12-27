CC ?= gcc

# Keep flags conservative/portable; override on CLI if desired:
#   make CFLAGS='-O3 -march=native -Wall -Wextra -std=c11'
CFLAGS ?= -O3 -Wall -Wextra -std=c11

# clock_gettime/CLOCK_MONOTONIC are exposed by POSIX feature-test macros.
# This is widely needed on Linux when compiling with -std=c11.
CPPFLAGS ?= -D_POSIX_C_SOURCE=200809L
LDFLAGS ?=
LDLIBS ?= -lrt

TARGET := benchmark
SRC := benchmark.c
BITLIB := c-libs/libbit.so

# Link against libbit.so in ./c-libs
BITLIB_LDFLAGS := -L./c-libs -lbit

# Ensure the binary can find ./c-libs/libbit.so at runtime.
RPATH_LDFLAGS := -Wl,-rpath,'$$ORIGIN/c-libs'

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC) benchmark_helper.h c-libs/bit.h c-libs/roaring.c c-libs/roaring.h c-libs/libpopcnt.h $(BITLIB)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(SRC) -o $@ $(LDFLAGS) $(RPATH_LDFLAGS) $(BITLIB_LDFLAGS) $(LDLIBS)

clean:
	rm -f $(TARGET)
