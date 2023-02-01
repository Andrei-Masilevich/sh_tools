#!/bin/bash

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/lib_tests.sh
source $THIS_DIR/../scripts/lib_crypt.sh

BACKUP_SCRIPT=$THIS_DIR/../scripts/backup.sh

PATH_TO_DATA_OPEN_TYPE="aaa"
PATH_TO_DATA_FULL_ENCRYPTED_TYPE="bbb"
PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE="aaa/cccc/bbb"
PATH_TO_DATA_UNKNOWN_TYPE="aaa/dd"

MASTER_PASSPHRASE="secret"
MASTER_PASSPHRASE_NEW="secret2"

init_this_tests_fixture()
{
    init_crypt_tests_fixture THIS_CRYPT_SANDBOX

    # Create fake schema
    PATH_TO_DATA_OPEN_TYPE=${THIS_CRYPT_SANDBOX}/${PATH_TO_DATA_OPEN_TYPE}
    mkdir -p ${PATH_TO_DATA_OPEN_TYPE}
    PATH_TO_DATA_FULL_ENCRYPTED_TYPE=${THIS_CRYPT_SANDBOX}/${PATH_TO_DATA_FULL_ENCRYPTED_TYPE}
    mkdir -p ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE}
    PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE=${THIS_CRYPT_SANDBOX}/${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE}
    mkdir -p ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE}
    PATH_TO_DATA_UNKNOWN_TYPE=${THIS_CRYPT_SANDBOX}/${PATH_TO_DATA_UNKNOWN_TYPE}
    mkdir -p ${PATH_TO_DATA_UNKNOWN_TYPE}

    create_master_key ${MASTER_PASSPHRASE} __MASTER_PASSPHRASE

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

    local TEST_UNKNOWN_PASSPHRASE="unknown"

    create_file_in_dir ${PATH_TO_DATA_UNKNOWN_TYPE} TMP_FILE
    PATH_TO_DATA_UNKNOWN_TYPE=${TMP_FILE}
    TMP_FILE=
    encrypt_file ${PATH_TO_DATA_UNKNOWN_TYPE} "${TEST_UNKNOWN_PASSPHRASE}"
    PATH_TO_DATA_UNKNOWN_TYPE=$(crypted_name ${PATH_TO_DATA_UNKNOWN_TYPE})
    TEST "Encryption" "[ -f ${PATH_TO_DATA_UNKNOWN_TYPE} ]"

}

test_base_archive()
{

START_TEST_SUITE "Test Base Archive" $(basename ${BASH_SOURCE})

    init_this_tests_fixture

    TEST "Target script exists" "[ -f  ${BACKUP_SCRIPT} ]"

    TEST "Data folder exists" "[ -d  ${THIS_CRYPT_SANDBOX} ]"
    TEST "Data folder is not empty" "[ -n \"\$(ls -A ${THIS_CRYPT_SANDBOX})\" ]"

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${THIS_CRYPT_SANDBOX}
    # fi

    local BACKUP_DIR=$(mktemp -d /tmp/$(basename $0).XXXXXX)

    TEST "Backup folder exists" "[ -d  ${BACKUP_DIR} ]"

    SH_TEST_FMK_TMP_DIRS="${SH_TEST_FMK_TMP_DIRS} ${BACKUP_DIR}"

    create_temp_kb_file TMP_KEY_FILE

    TEST "Key file exists" "[ -f  ${TMP_KEY_FILE} ]"

    local ARCHIVE="store"

    MESSAGE ${BACKUP_SCRIPT} -P ${MASTER_PASSPHRASE} -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}
    TEST_APP "Backup Test" ${BACKUP_SCRIPT} -P ${MASTER_PASSPHRASE} -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${BACKUP_DIR}
    # fi

    ARCHIVE=$(crypted_name ${BACKUP_DIR}/${ARCHIVE}.tar.gz)

    TEST "Archive file exists" "[ -f  ${ARCHIVE} ]"

    rm -f ${ARCHIVE}

    TEST "Archive file doesn't exist" "[ ! -f  ${ARCHIVE} ]"

    ARCHIVE="store"

    MESSAGE ${BACKUP_SCRIPT} -P "${MASTER_PASSPHRASE}" -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}
    TEST_APP "Backup again" ${BACKUP_SCRIPT} -P "${MASTER_PASSPHRASE}" -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}

    ARCHIVE=$(crypted_name ${BACKUP_DIR}/${ARCHIVE}.tar.gz)

    TEST "Archive file exists" "[ -f  ${ARCHIVE} ]"

    rm -rf ${THIS_CRYPT_SANDBOX}

    TEST "Data folder doesn't exist" "[ ! -d  ${THIS_CRYPT_SANDBOX} ]"

    # Data dir should exist even empty
    mkdir ${THIS_CRYPT_SANDBOX}

    TEST "Data folder exists" "[ -d  ${THIS_CRYPT_SANDBOX} ]"

    MESSAGE ${BACKUP_SCRIPT} -rP ${MASTER_PASSPHRASE_NEW} -Z ${TMP_KEY_FILE} ${ARCHIVE}
    TEST_APP "Restore Test (from scratch)" ${BACKUP_SCRIPT} -rP ${MASTER_PASSPHRASE_NEW} -Z ${TMP_KEY_FILE} ${ARCHIVE}

    TEST "Data folder exists" "[ -d  ${THIS_CRYPT_SANDBOX} ]"

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${THIS_CRYPT_SANDBOX}
    # fi

    rm -f ${ARCHIVE}

    TEST "Archive file doesn't exist" "[ ! -f  ${ARCHIVE} ]"

    ARCHIVE="store"

    MESSAGE ${BACKUP_SCRIPT} -P "${MASTER_PASSPHRASE_NEW}" -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}
    TEST_APP "Backup again" ${BACKUP_SCRIPT} -P "${MASTER_PASSPHRASE_NEW}" -Z ${TMP_KEY_FILE} ${BACKUP_DIR} ${ARCHIVE}

    ARCHIVE=$(crypted_name ${BACKUP_DIR}/${ARCHIVE}.tar.gz)

    TEST "Archive file exists" "[ -f  ${ARCHIVE} ]"

    MESSAGE ${BACKUP_SCRIPT} -rfP ${MASTER_PASSPHRASE_NEW} -Z ${TMP_KEY_FILE} ${ARCHIVE}
    TEST_APP "Restore Test (override)" ${BACKUP_SCRIPT} -rfP ${MASTER_PASSPHRASE_NEW} -Z ${TMP_KEY_FILE} ${ARCHIVE}

    TEST "Data folder exists" "[ -d  ${THIS_CRYPT_SANDBOX} ]"

    # if [ -n "$(which tree)" ]; then
    #     tree -a ${THIS_CRYPT_SANDBOX}
    # fi

    TEST "Open type exists" "[ -f ${PATH_TO_DATA_OPEN_TYPE} ]"
    TEST "Full encrypted type exists" "[ ! -f ${PATH_TO_DATA_FULL_ENCRYPTED_TYPE} ]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

    TEST "Content encrypted type exists" "[ -f ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE} ]"

    check_file_totally_encrypted ${PATH_TO_DATA_CONTENT_ENCRYPTED_TYPE} __ENCRYPTED_NAME __ENCRYPTED_CONTENT

    TEST "Content encrypted type is valid" "[[ ! -n  \"$__ENCRYPTED_NAME\" && -n \"$__ENCRYPTED_CONTENT\" ]]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

    TEST "Unknown type exists" "[ -f ${PATH_TO_DATA_UNKNOWN_TYPE} ]"

    check_file_totally_encrypted ${PATH_TO_DATA_UNKNOWN_TYPE} __ENCRYPTED_NAME __ENCRYPTED_CONTENT

    TEST "Unknown type is valid" "[[ -n  \"$__ENCRYPTED_NAME\" || -n \"$__ENCRYPTED_CONTENT\" ]]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

END_TEST_SUITE    

}

SH_TEST_FMK_SUPPRESS_WELCOM=1
INIT_SH_TEST_FMK "backup.sh tests"

test_base_archive
