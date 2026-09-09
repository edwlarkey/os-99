# Else exist specifically for clang
ifeq ($(CXX),g++)
    EXTRA_FLAGS = --no-gnu-unique
else
    EXTRA_FLAGS =
endif

CXXFLAGS ?= -O2
CXXFLAGS += -shared -fPIC -std=c++2b -Wno-c++11-narrowing
INCLUDES = `pkg-config --cflags pixman-1 libdrm hyprland libinput libudev wayland-server xkbcommon`
LIBS =

# GLOB, do not list. Upstream's Makefile named three files explicitly while its
# CMakeLists used file(GLOB_RECURSE "*.cpp"), so the two build systems disagreed
# the moment this fork added ninePatch.cpp. Building with cmake worked and
# building with make produced a .so that dlopen rejected:
#
#   Hyprland: symbol lookup error: libhyprbars-os99-*.so:
#     undefined symbol: _Z12parseBorders...
#
# An undefined symbol aborts the compositor at load with no core and no usable
# backtrace, so it does not look like a build problem at all. A wildcard cannot
# drift out of step with the directory.
SRC = $(wildcard *.cpp)
TARGET = hyprbars.so

# REBUILD WHEN HYPRLAND'S HEADERS MOVE, not only when our sources do.
#
# A Hyprland plugin is ABI-pinned to a string assembled from version.h --
# GIT_COMMIT_HASH plus the aquamarine/hyprutils/hyprgraphics/hyprcursor/hyprlang
# versions. A distro rebuild that bumps only aquamarine changes that string
# while leaving the Hyprland commit alone, so the .so stops loading with
#
#   [hyprbars] Failure in initialization: Version mismatch
#
# and NOTHING in this directory has changed. With only $(SRC) as prerequisites
# make says "Nothing to be done for 'all'" and os99-hyprbars-rebuild cheerfully
# content-hashes and installs the STALE object under a fresh name, reporting
# success. That happened on 2026-09-09 (aquamarine 0.14 -> 0.15).
#
# Found through pkg-config rather than hardcoded: /usr/include is wrong on
# NixOS, and a path that does not exist would be no prerequisite at all --
# silently restoring the bug this line exists to fix.
HYPR_VERSION_H := $(firstword $(wildcard \
  $(patsubst -I%,%/version.h,$(shell pkg-config --cflags-only-I hyprland))))

all: $(TARGET)

# The recipe names $(SRC) and not $^: version.h is a prerequisite so that an ABI
# bump forces a recompile, but it is not an input to the compile. $^ hands the
# whole prerequisite list to g++ and version.h lands on the command line as a
# source file. It builds anyway, which is the bad kind of wrong.
$(TARGET): $(SRC) $(HYPR_VERSION_H)
	$(CXX) $(CXXFLAGS) $(LDFLAGS) $(EXTRA_FLAGS) $(INCLUDES) $(SRC) -o $@ $(LIBS)

clean:
	rm -f ./$(TARGET)

meson-build:
	mkdir -p build
	cd build && meson .. && ninja

.PHONY: all meson-build clean
