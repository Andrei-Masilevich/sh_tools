#!/bin/bash

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/fmk/lib_sh_test_fmk.sh
source $THIS_DIR/../scripts/lib_common.sh
source $THIS_DIR/../scripts/lib_crypt.sh


# Create binary file with random content and prity random size
function __create_data_file()
{
    local FILE_PATH=$1
    if  [[ -z $FILE_PATH || ! -f $FILE_PATH ]]; then
        ERROR "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments"
    fi

    local SZ_FACTOR=$2
    if (($SZ_FACTOR < 1)); then
        ERROR "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments"
    fi

    declare -n FILE_PATH__=$3

    SH_TEST_FMK_TMP_FILES="${SH_TEST_FMK_TMP_FILES} ${FILE_PATH}"

    # Create random several MB size for new file
    local RND=$(date +%s%N | cut -b10-19)
    local SZ=$((1$RND / 1024 / $SZ_FACTOR + 1))
    if (( ${RND: -1} > 5 )); then
        # to make not odd rest from time to time
        SZ=$(($SZ * 2))
    fi

    if (($SZ < 1)); then
        ERROR "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments"
    fi

    # Create file for test
    dd if=/dev/urandom count=1 bs=$SZ of=$FILE_PATH 2>/dev/null

    MESSAGE "File => $(stat $FILE_PATH|grep Size)"

    # Show peace of file
    MESSAGE $(xxd -l 16 $FILE_PATH)   

    FILE_PATH__=${FILE_PATH} 
}

function create_temp_mb_file()
{
    local TMP_FILE__=$(mktemp /tmp/$(basename $0).XXXXXX)
   __create_data_file ${TMP_FILE__} 9 $@
}

function create_temp_kb_file()
{
    local TMP_FILE__=$(mktemp /tmp/$(basename $0).XXXXXX)
    __create_data_file ${TMP_FILE__} 99 $@
}

function create_file_in_dir()
{
    local DIR_PATH=$1
    if [[ -z ${DIR_PATH} || ! -d ${DIR_PATH} ]]; then
        ERROR "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments"
    fi

    shift
    local TMP_FILE__=$(mktemp ${DIR_PATH}/XXXXXX)

    __create_data_file ${TMP_FILE__} 99 $@
}

# Create wrapper script for target function to check 
# negative cases when function invokes 'exit'
function create_function_sandbox()
{
    local FUNC_NAME=$1
    if [ -z ${FUNC_NAME} ]; then
        ERROR "($(basename ${BASH_SOURCE}):${LINENO}) Function required"
    fi

    shopt -s extdebug
    local FUNC_INFO=$(declare -F ${FUNC_NAME})
    shopt -u extdebug
    if [ -n "${FUNC_INFO}" ]; then
        local FUNC_SRC_PATH=$(echo ${FUNC_INFO}|cut -d ' ' -f 3)
        if [[ -z ${FUNC_SRC_PATH} || ! -f ${FUNC_SRC_PATH} ]]; then
            ERROR "($(basename ${BASH_SOURCE}):${LINENO}) Function is not found"
        fi
        FUNC_SRC_PATH=$(realpath ${FUNC_SRC_PATH})
        if [ $? -ne 0 ]; then
            ERROR "($(basename ${BASH_SOURCE}):${LINENO}) Function is not found"
        fi

        declare -n FILE_PATH__=$2

        FILE_PATH__=$(mktemp /tmp/$(basename $0).XXXXXX)
        echo "#!/bin/bash"              >> ${FILE_PATH__}
        echo                            >> ${FILE_PATH__}
        echo "source ${FUNC_SRC_PATH}"  >> ${FILE_PATH__}
        echo                            >> ${FILE_PATH__}
        echo "${FUNC_NAME} \$@"         >> ${FILE_PATH__}

        SH_TEST_FMK_TMP_FILES="${SH_TEST_FMK_TMP_FILES} ${FILE_PATH__}"
    else
        ERROR "($(basename ${BASH_SOURCE}):${LINENO}) Function is not found"
    fi
}

function init_crypt_tests_fixture()
{
    create_function_sandbox init_crypt INIT_CRYPT_SANDBOX

    declare -n DATA_DIR_PATH_=$1
    local DATA_DIR_PATH=$2
    local TMP_DIR=
    if [ -z ${DATA_DIR_PATH} ]; then
        TMP_DIR=$(mktemp -d /tmp/$(basename $0).XXXXXX)
        DATA_DIR_PATH=${TMP_DIR}
    fi

    export SH_TOOLS_DATA_DIR_PATH=${DATA_DIR_PATH}

    SH_TEST_FMK_REPORT_ERRORS_ONLY=1
    TEST_APP "Check crypt requirements" ${INIT_CRYPT_SANDBOX}
    SH_TEST_FMK_REPORT_ERRORS_ONLY=0
    init_crypt

    MESSAGE "Sandbox master key path is \"${SH_TOOLS_MASTER_KEY_PATH}\""

    if [ -n "${TMP_DIR}" ]; then
        SH_TEST_FMK_TMP_DIRS="${SH_TEST_FMK_TMP_DIRS} ${TMP_DIR}"
    fi

    DATA_DIR_PATH_=${DATA_DIR_PATH}
}
