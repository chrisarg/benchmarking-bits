CC ?= gcc

# Keep flags conservative/portable; override on CLI if desired:
#   make CFLAGS='-O3 -march=native -Wall -Wextra -std=c11'
CFLAGS ?= -O3 -Wextra -std=c11 -Wno-pointer-sign

# Some environments inject -flto via CFLAGS; disable it for portability.
CFLAGS += -fno-lto

# clock_gettime/CLOCK_MONOTONIC are exposed by POSIX feature-test macros.
CPPFLAGS ?= -D_POSIX_C_SOURCE=200809L

LDFLAGS ?=
LDFLAGS += -fno-lto

# libbit.a uses OpenMP internally; link libgomp.
LDLIBS ?= -lrt
LDLIBS += -fopenmp

TARGET := benchmark
SRC := benchmark.c
BITLIB := c-libs/libbit.a

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(SRC) benchmark_helper.h c-libs/bit.h c-libs/roaring.c c-libs/roaring.h c-libs/libpopcnt.h $(BITLIB)
	$(CC) $(CPPFLAGS) $(CFLAGS) $(SRC) -o $@ $(LDFLAGS) $(BITLIB) $(LDLIBS)

clean:
	rm -f $(TARGET)
