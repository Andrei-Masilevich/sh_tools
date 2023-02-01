#!/bin/bash

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/lib_tests.sh
source $THIS_DIR/../scripts/lib_profiler.sh

INSTALL_SCRIPT=$THIS_DIR/../install.sh
SYS_PROFILE='.profile'
SYS_BASH='.bashrc'

create_home_dir()
{
    declare -n TMP_DIR_=$1
    local TMP_DIR__=$(mktemp -d /tmp/$(basename $0).XXXXXX)

    SH_TEST_FMK_TMP_DIRS="${SH_TEST_FMK_TMP_DIRS} ${TMP_DIR__}"

    echo "# Fake $SYS_PROFILE" >> ${TMP_DIR__}/$SYS_PROFILE
    echo "# "                  >> ${TMP_DIR__}/$SYS_PROFILE

    echo "# Fake $SYS_BASH"    >> ${TMP_DIR__}/$SYS_BASH
    echo "# "                  >> ${TMP_DIR__}/$SYS_BASH

    TMP_DIR_=${TMP_DIR__} 
}

MASTER_PASSPHRASE="secret2"
INSTALL_PREFIX="test"

test_install_from_scratch()
{
START_TEST_SUITE "Test from scratch" $(basename ${BASH_SOURCE})

    TEST "Target script exists" "[ -f  ${INSTALL_SCRIPT} ]"

    create_home_dir TEST_HOME_DIR

    TEST "Home folder exists" "[ -d  ${TEST_HOME_DIR} ]"

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${TEST_HOME_DIR}
    # fi

    # Replace HOME folder for tested script 
    export SH_TOOLS_INSTALL_HOME=${TEST_HOME_DIR}

    TEST_APP_OUTPUT "Home folder applied" ${INSTALL_SCRIPT} "Default:" "${TEST_HOME_DIR}/.local/sh_tools" -h

    TEST_APP_OUTPUT "Check for -x option" ${INSTALL_SCRIPT} -- "-x" -h
    TEST_APP_OUTPUT "Check for -P option" ${INSTALL_SCRIPT} -- "-P" -h
    TEST_APP_OUTPUT "Check for -Z option" ${INSTALL_SCRIPT} -- "-Z" -h
    TEST_APP_OUTPUT "Check for -i option" ${INSTALL_SCRIPT} -- "-i" -h

    TEST_APP "Install into empty home"  ${INSTALL_SCRIPT} -x $INSTALL_PREFIX -P "${MASTER_PASSPHRASE}"

    TEST "Environment file exists" "[ -f  ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/env ]"

    local MASTER_KEY_PATH=$(crypted_name ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/.data/.master)

    TEST "Master key exists" "[ -f  ${MASTER_KEY_PATH} ]"

    local EXPECTED_CONFIG_LINE=". ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/env"

    TEST "$SYS_PROFILE configured" "[ \"${EXPECTED_CONFIG_LINE}\" == \"\$(tail -n 1 ${TEST_HOME_DIR}/$SYS_PROFILE)\" ]"
    TEST "$SYS_BASH configured" "[ \"${EXPECTED_CONFIG_LINE}\" == \"\$(tail -n 1 ${TEST_HOME_DIR}/$SYS_BASH)\" ]"

    TEST "Binaries are not empty" "[ -n \"\$(ls -A ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/bin)\" ]"

END_TEST_SUITE    

}

MASTER_PASSPHRASE_FOR_BACKUP="secret"

PATH_TO_DATA_OPEN_TYPE="ssh/pubs"
PATH_TO_DATA_FULL_ENCRYPTED_TYPE="ssh/keys"
PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE="proxy"

create_backup_fixture()
{
    declare -n THIS_CRYPT_SANDBOX_=$1

    create_home_dir THIS_CRYPT_SANDBOX
    mkdir -p ${THIS_CRYPT_SANDBOX}/.local/sh_tools/$INSTALL_PREFIX/.data
    init_crypt_tests_fixture DATA_DIR ${THIS_CRYPT_SANDBOX}/.local/sh_tools/$INSTALL_PREFIX/.data

    # Create fake schema
    PATH_TO_DATA_OPEN_TYPE=${DATA_DIR}/${PATH_TO_DATA_OPEN_TYPE}
    mkdir -p ${PATH_TO_DATA_OPEN_TYPE}
    PATH_TO_DATA_FULL_ENCRYPTED_TYPE=${DATA_DIR}/${PATH_TO_DATA_FULL_ENCRYPTED_TYPE}
    mkdir -p ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE}
    PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE=${DATA_DIR}/${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE}
    mkdir -p ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE}

    create_master_key ${MASTER_PASSPHRASE_FOR_BACKUP} __MASTER_PASSPHRASE

    local MASTER_KEY=$(crypted_name ${SH_TOOLS_MASTER_KEY_PATH})
    TEST "Master key exists" "[ -n \"${MASTER_KEY}\" ]"
    TEST "Master key is not empty" "SZ=\$(du ${MASTER_KEY} |cut -f 1); (( SZ > 0 ))"
    TEST "Master key is valid" "[ -n \"${__MASTER_PASSPHRASE}\" ]"

    create_file_in_dir ${PATH_TO_DATA_OPEN_TYPE} TMP_FILE
    PATH_TO_DATA_OPEN_TYPE=${TMP_FILE}
    TMP_FILE=

    create_file_in_dir ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE} TMP_FILE
    PATH_TO_DATA_FULL_ENCRYPTED_TYPE=${TMP_FILE}
    TMP_FILE=
    encrypt_file ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE} ${__MASTER_PASSPHRASE}
    PATH_TO_DATA_FULL_ENCRYPTED_TYPE=$(crypted_name ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE})
    TEST "Encryption" "[ -f ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE} ]"
    encrypt_name ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE} ${__MASTER_PASSPHRASE}

    create_file_in_dir ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE} TMP_FILE
    PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE=${TMP_FILE}
    TMP_FILE=
    encrypt_file ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE} ${__MASTER_PASSPHRASE}
    PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE=$(crypted_name ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE})
    TEST "Encryption" "[ -f ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE} ]"

    THIS_CRYPT_SANDBOX_=${THIS_CRYPT_SANDBOX}
}

BACKUP_SCRIPT=$THIS_DIR/../scripts/backup.sh

test_install_from_backup()
{
START_TEST_SUITE "Test from backup" $(basename ${BASH_SOURCE})

    TEST "Target script exists" "[ -f  ${INSTALL_SCRIPT} ]"
    TEST "Backup script exists" "[ -f  ${BACKUP_SCRIPT} ]"

    create_backup_fixture TEST_HOME_DIR

    TEST "Home folder exists" "[ -d  ${TEST_HOME_DIR} ]"

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${TEST_HOME_DIR}
    # fi

    # Replace HOME folder for tested script 
    export SH_TOOLS_INSTALL_HOME=${TEST_HOME_DIR}
    
    TEST_APP_OUTPUT "Home folder applied" ${INSTALL_SCRIPT} "Default:" "${TEST_HOME_DIR}/.local/sh_tools" -h

    local BACKUP_DIR=$(mktemp -d /tmp/$(basename $0).XXXXXX)

    TEST "Backup folder exists" "[ -d  ${BACKUP_DIR} ]"

    SH_TEST_FMK_TMP_DIRS="${SH_TEST_FMK_TMP_DIRS} ${BACKUP_DIR}"

    create_temp_kb_file TMP_KEY_FILE

    TEST "Key file exists" "[ -f  ${TMP_KEY_FILE} ]"

    local ARCHIVE="store"

    MESSAGE ${BACKUP_SCRIPT} -P "${MASTER_PASSPHRASE_FOR_BACKUP}" -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}
    TEST_APP "Backup" ${BACKUP_SCRIPT} -P "${MASTER_PASSPHRASE_FOR_BACKUP}" -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${BACKUP_DIR}
    # fi

    ARCHIVE=$(crypted_name ${BACKUP_DIR}/${ARCHIVE}.tar.gz)

    TEST "Archive file exists" "[ -f  ${ARCHIVE} ]"

    rm -rf ${TEST_HOME_DIR}/.local/sh_tools

    TEST "Home folder is empty" "[ ! -d  ${TEST_HOME_DIR}/.local/sh_tools ]"

    MESSAGE ${INSTALL_SCRIPT} -x $INSTALL_PREFIX -P "${MASTER_PASSPHRASE}" -i ${ARCHIVE} -Z ${TMP_KEY_FILE}
    TEST_APP "Install from backup (from scratch)" ${INSTALL_SCRIPT} -x $INSTALL_PREFIX -P "${MASTER_PASSPHRASE}" -i ${ARCHIVE} -Z ${TMP_KEY_FILE}

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${TEST_HOME_DIR}
    # fi

    TEST "Data exists" "[ -d ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/.data ]"

    local MASTER_KEY_PATH=$(crypted_name ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/.data/.master)

    TEST "Master key exists" "[ -f  ${MASTER_KEY_PATH} ]"

    TEST "Environment file exists" "[ -f  ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/env ]"

    local EXPECTED_CONFIG_LINE=". ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/env"

    TEST "$SYS_PROFILE configured" "[ \"${EXPECTED_CONFIG_LINE}\" == \"\$(tail -n 1 ${TEST_HOME_DIR}/$SYS_PROFILE)\" ]"
    TEST "$SYS_BASH configured" "[ \"${EXPECTED_CONFIG_LINE}\" == \"\$(tail -n 1 ${TEST_HOME_DIR}/$SYS_BASH)\" ]"

    TEST "Binaries are not empty" "[ -n \"\$(ls -A ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/bin)\" ]"

    TEST "Open type exists" "[ -f ${PATH_TO_DATA_OPEN_TYPE} ]"
    TEST "Full encrypted type exists" "[ ! -f ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE} ]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

    TEST "Content encrypted type exists" "[ -f ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE} ]"

    check_file_totally_encrypted ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE} __ENCRYPTED_NAME __ENCRYPTED_CONTENT

    TEST "Content encrypted type is valid" "[[ ! -n  \"$__ENCRYPTED_NAME\" && -n \"$__ENCRYPTED_CONTENT\" ]]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

    rm -f ${ARCHIVE}

    TEST "Archive file doesn't exist" "[ ! -f  ${ARCHIVE} ]"

    ARCHIVE="store"

    MESSAGE ${BACKUP_SCRIPT} -P "${MASTER_PASSPHRASE}" -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}
    TEST_APP "Backup" ${BACKUP_SCRIPT} -P "${MASTER_PASSPHRASE}" -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${BACKUP_DIR}
    # fi

    ARCHIVE=$(crypted_name ${BACKUP_DIR}/${ARCHIVE}.tar.gz)

    TEST "Archive file exists" "[ -f  ${ARCHIVE} ]"

    TEST "Home folder is not empty" "[ -d  ${TEST_HOME_DIR}/.local/sh_tools ]"

    MESSAGE ${INSTALL_SCRIPT} -x $INSTALL_PREFIX -P "${MASTER_PASSPHRASE}" -i ${ARCHIVE} -Z ${TMP_KEY_FILE}
    TEST_APP "Install from backup (override)" ${INSTALL_SCRIPT} -x $INSTALL_PREFIX -P "${MASTER_PASSPHRASE}" -i ${ARCHIVE} -Z ${TMP_KEY_FILE}

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${TEST_HOME_DIR}
    # fi

    TEST "Data exists" "[ -d ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/.data ]"

    local MASTER_KEY_PATH=$(crypted_name ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/.data/.master)

    TEST "Master key exists" "[ -f  ${MASTER_KEY_PATH} ]"

    TEST "Environment file exists" "[ -f  ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/env ]"

    local EXPECTED_CONFIG_LINE=". ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/env"

    TEST "$SYS_PROFILE configured" "[ \"${EXPECTED_CONFIG_LINE}\" == \"\$(tail -n 1 ${TEST_HOME_DIR}/$SYS_PROFILE)\" ]"
    TEST "$SYS_BASH configured" "[ \"${EXPECTED_CONFIG_LINE}\" == \"\$(tail -n 1 ${TEST_HOME_DIR}/$SYS_BASH)\" ]"

    TEST "Binaries are not empty" "[ -n \"\$(ls -A ${TEST_HOME_DIR}/.local/sh_tools/$INSTALL_PREFIX/bin)\" ]"

    TEST "Open type exists" "[ -f ${PATH_TO_DATA_OPEN_TYPE} ]"
    TEST "Full encrypted type exists" "[ ! -f ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE} ]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

    TEST "Content encrypted type exists" "[ -f ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE} ]"

    check_file_totally_encrypted ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE} __ENCRYPTED_NAME __ENCRYPTED_CONTENT

    TEST "Content encrypted type is valid" "[[ ! -n  \"$__ENCRYPTED_NAME\" && -n \"$__ENCRYPTED_CONTENT\" ]]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

END_TEST_SUITE    

}

SH_TEST_FMK_SUPPRESS_WELCOM=1
INIT_SH_TEST_FMK "install.sh tests"

test_install_from_scratch
test_install_from_backup