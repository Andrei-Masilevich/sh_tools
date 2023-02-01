#!/bin/bash

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/fmk/lib_sh_test_fmk.sh

INIT_SH_TEST_FMK "SH_TOOLS Tests"

. ${THIS_DIR}/common_tests.sh
. ${THIS_DIR}/profiler_tests.sh
. ${THIS_DIR}/crypt_tests.sh
. ${THIS_DIR}/encrypt_file_tests.sh
. ${THIS_DIR}/backup_tests.sh
. ${THIS_DIR}/install_tests.sh
