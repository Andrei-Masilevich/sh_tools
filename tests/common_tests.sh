#!/bin/bash

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/../scripts/lib_common.sh
source $THIS_DIR/../scripts/lib_realpath.sh
source $THIS_DIR/fmk/lib_sh_test_fmk.sh

function test_files()
{

START_TEST_SUITE "Test Files" $(basename ${BASH_SOURCE})

    local BUGGY_NAME="/tmp/-76oDG8DTpZ5YpPvyZy0Iq0{EzkJ970Y3MYfb94dNTCiEOne4xE8DqeQaXNHbVg_.~"
    local EXT=$(get_file_extention ${BUGGY_NAME})

    TEST "get_file_extention" "[ \"${EXT}\" ==  \"~\" ]" 

    local TEST_PATH=${BUGGY_NAME}
    local REAL_PATH=$(get_realpath ${TEST_PATH} 2>/dev/null)

    TEST "get_realpath for absolute path" "[ \"${REAL_PATH}\" ==  \"${TEST_PATH}\" ]"

    TEST_PATH=$THIS_DIR/../scripts/lib_common.sh
    REAL_PATH=$(get_realpath ${TEST_PATH} 2>/dev/null)

    TEST "get_realpath for relative path" "[ \"${REAL_PATH}\" !=  \"${TEST_PATH}\" ]"

    # Should have invalid folder in relative path
    local INVALID_PATH="$THIS_DIR/../blabladir/blablafile"

    TEST "Path is invalid" "[ ! -e \"\$(dirname ${INVALID_PATH})\" ]"

    REAL_PATH=$(get_realpath ${INVALID_PATH} 2>/dev/null)

    TEST "get_realpath for invalid path" "[ ! -n \"${REAL_PATH}\" ]"

END_TEST_SUITE

}

SH_TEST_FMK_SUPPRESS_WELCOM=1
INIT_SH_TEST_FMK "lib_common.sh test"

test_files
