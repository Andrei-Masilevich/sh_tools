#!/bin/bash

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/../scripts/lib_profiler.sh
source $THIS_DIR/fmk/lib_sh_test_fmk.sh

SH_TEST_FMK_SUPPRESS_WELCOM=1
INIT_SH_TEST_FMK "lib_profiler.sh/cpu_check_time function test"

START_TEST_SUITE

    TEST "Initialized" "[ -n \"$__CURRENT_TIME_MARK \" ]" 
    sleep 1
    TEST "Payload" "cpu_check_time \"Payload is about 1 second\""
    TEST "Instant Payload" cpu_check_time
    sleep 1
    TEST "Payload" "cpu_check_time \"Payload is about 1 second\" ELAPSED"

    TEST "ELAPSED exists" "[ -n \"$ELAPSED \" ]"
    TEST "ELAPSED >= 1000"  "[ $ELAPSED -ge 1000 ]"
    TEST "ELAPSED < 1100" "[ $ELAPSED -lt 1100 ]"

END_TEST_SUITE
