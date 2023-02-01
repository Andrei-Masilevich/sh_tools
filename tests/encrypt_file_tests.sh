#!/bin/bash

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/lib_tests.sh
source $THIS_DIR/../scripts/lib_crypt.sh

ENCRYPT_SCRIPT=$THIS_DIR/../scripts/encrypt_file.sh
DECRYPT_SCRIPT=$THIS_DIR/../scripts/decrypt_file.sh

test_with_passphrase()
{

START_TEST_SUITE "Test With Passphrase" $(basename ${BASH_SOURCE})

    init_crypt_tests_fixture THIS_CRYPT_SANDBOX

    TEST "$(basename ${ENCRYPT_SCRIPT}) script exists" "[ -f  ${ENCRYPT_SCRIPT} ]"
    TEST "$(basename ${DECRYPT_SCRIPT}) script exists" "[ -f  ${DECRYPT_SCRIPT} ]"

    create_temp_kb_file TMP_FILE

    TEST "Data file exists" "[[ ! -z ${TMP_FILE} && -f ${TMP_FILE} ]]"

    # Calculate checksum
    local CHECK_IN=$(sha256sum ${TMP_FILE}|cut -d ' ' -f 1)

    MESSAGE $CHECK_IN

    local PASSPHRASE="SECRET"

    local ENCRYPTED_TMP_FILE=$(crypted_name ${TMP_FILE})
    SH_TEST_FMK_TMP_FILES="${SH_TEST_FMK_TMP_FILES} ${ENCRYPTED_TMP_FILE}"

    TEST_APP "Encryption Test" ${ENCRYPT_SCRIPT} -vP ${PASSPHRASE} ${TMP_FILE}

    TEST "Encrypted file exists" "[ -f  ${ENCRYPTED_TMP_FILE} ]"

    TEST "Encrypted File Test" "[ ! -f  ${TMP_FILE} ]" "Encrypted file renamed"

    MESSAGE $(xxd -l 16 $ENCRYPTED_TMP_FILE)

    local CHECK_OUT=$(sha256sum ${ENCRYPTED_TMP_FILE}|cut -d ' ' -f 1)

    MESSAGE $CHECK_OUT

    TEST "Encrypted file was changed" "[ \"$CHECK_IN\" != \"$CHECK_OUT\" ]"

    TEST_APP "Decryption Test" ${DECRYPT_SCRIPT} -vP ${PASSPHRASE} ${ENCRYPTED_TMP_FILE}

    TEST "Decrypted file exists" "[ -f  ${TMP_FILE} ]"

    TEST  "Decrypted file renamed" "[ ! -f  ${ENCRYPTED_TMP_FILE} ]"

    MESSAGE $(xxd -l 16 $TMP_FILE)

    CHECK_OUT=$(sha256sum ${TMP_FILE}|cut -d ' ' -f 1)

    MESSAGE $CHECK_OUT

    TEST "Encrypted file was successfully decrypted" "[ \"$CHECK_IN\" == \"$CHECK_OUT\" ]"

END_TEST_SUITE

}

test_with_key_file()
{

START_TEST_SUITE "Test With Key File" $(basename ${BASH_SOURCE})

    init_crypt_tests_fixture THIS_CRYPT_SANDBOX

    TEST "$(basename ${ENCRYPT_SCRIPT}) script exists" "[ -f  ${ENCRYPT_SCRIPT} ]"
    TEST "$(basename ${DECRYPT_SCRIPT}) script exists" "[ -f  ${DECRYPT_SCRIPT} ]"

    create_temp_kb_file TMP_FILE

    TEST "Data file exists" "[[ ! -z ${TMP_FILE} && -f ${TMP_FILE} ]]"

    # Calculate checksum
    local CHECK_IN=$(sha256sum ${TMP_FILE}|cut -d ' ' -f 1)

    MESSAGE $CHECK_IN

    local TMP_KEY_FILE=$(mktemp /tmp/$(basename $0).XXXXXX)
    SH_TEST_FMK_TMP_FILES="${SH_TEST_FMK_TMP_FILES} ${TMP_KEY_FILE}"

    echo "SECRET" > ${TMP_KEY_FILE}

    local ENCRYPTED_TMP_FILE=$(crypted_name ${TMP_FILE})
    SH_TEST_FMK_TMP_FILES="${SH_TEST_FMK_TMP_FILES} ${ENCRYPTED_TMP_FILE}"

    TEST_APP "Encryption Test" ${ENCRYPT_SCRIPT} -v ${TMP_FILE} ${TMP_KEY_FILE}

    TEST "Encrypted file exists" "[ -f  ${ENCRYPTED_TMP_FILE} ]"

    TEST "Encrypted File Test" "[ ! -f  ${TMP_FILE} ]" "Encrypted file renamed"

    MESSAGE $(xxd -l 16 $ENCRYPTED_TMP_FILE)

    local CHECK_OUT=$(sha256sum ${ENCRYPTED_TMP_FILE}|cut -d ' ' -f 1)

    MESSAGE $CHECK_OUT

    TEST "Encrypted file was changed" "[ \"$CHECK_IN\" != \"$CHECK_OUT\" ]"

    TEST_APP "Decryption Test" ${DECRYPT_SCRIPT} -v ${ENCRYPTED_TMP_FILE} ${TMP_KEY_FILE}

    TEST "Decrypted file exists" "[ -f  ${TMP_FILE} ]"

    TEST  "Decrypted file renamed" "[ ! -f  ${ENCRYPTED_TMP_FILE} ]"

    MESSAGE $(xxd -l 16 $TMP_FILE)

    CHECK_OUT=$(sha256sum ${TMP_FILE}|cut -d ' ' -f 1)

    MESSAGE $CHECK_OUT

    TEST "Encrypted file was successfully decrypted" "[ \"$CHECK_IN\" == \"$CHECK_OUT\" ]"

    TMP_FILE=

END_TEST_SUITE

}

SH_TEST_FMK_SUPPRESS_WELCOM=1
INIT_SH_TEST_FMK "encrypt_file.sh/descrypt_file.sh tests"

test_with_passphrase
test_with_key_file
