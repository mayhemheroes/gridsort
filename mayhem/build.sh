#!/usr/bin/env bash
#
# mayhem/build.sh — build gridsort's fuzz harness + the upstream bench/validate suite.
#
# gridsort is a header-only library (src/gridsort.h includes gridsort.c); there is no
# upstream build system. Everything compiles directly with clang.
set -euo pipefail

[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

# 1) + 2) The library is header-only, so the harness build IS the instrumented project
#    build: gridsort.c/quadsort.c are #include'd into the harness translation unit and
#    compiled with $SANITIZER_FLAGS.
$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    "$SRC/mayhem/gridsort-fuzz.c" -I"$SRC/src" -o /mayhem/gridsort-fuzz

# Standalone run-once reproducer (same harness, no libFuzzer runtime).
$CC $SANITIZER_FLAGS $DEBUG_FLAGS "$STANDALONE_FUZZ_MAIN" \
    "$SRC/mayhem/gridsort-fuzz.c" -I"$SRC/src" -o /mayhem/gridsort-fuzz-standalone

# 3) Upstream functional suite: src/bench.c — validate() plus per-run output verification
#    of gridsort/quadsort against qsort. Built with NORMAL flags; mayhem/test.sh runs it.
$CC -O2 $COVERAGE_FLAGS -o /mayhem/bench "$SRC/src/bench.c"
