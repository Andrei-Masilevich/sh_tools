#!/bin/bash

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/lib_tests.sh


test_crypted_name()
{

START_TEST_SUITE "File name modification" $(basename ${BASH_SOURCE})

    local TMP_FILE="/tmp/secret"
    SH_TEST_FMK_TMP_FILES="${SH_TEST_FMK_TMP_FILES} ${TMP_FILE}"

    local CRYPTED_NAME=$(crypted_name ${TMP_FILE})

    TEST "Crypted name" "[ ${CRYPTED_NAME} != $TMP_FILE ]"

    local ORIGINAL_NAME=$(restore_name ${CRYPTED_NAME})

    TEST "Restore name" "[ ${ORIGINAL_NAME} == $TMP_FILE ]"

END_TEST_SUITE

}

test_encrypt_data()
{

START_TEST_SUITE "Encrypt data" $(basename ${BASH_SOURCE})

    local DATA="secret data"
    local PASSPHRASE="secret passphrase"

    encrypt_data_with_passphrase "${DATA}" "${PASSPHRASE}" ENCRYPTED_RESULT_

    TEST "Encrypted result" "[ -n  \"$ENCRYPTED_RESULT_\" ]"

    MESSAGE $ENCRYPTED_RESULT_

    decrypt_data_with_passphrase "${ENCRYPTED_RESULT_}"  "${PASSPHRASE}" DECRYPTED_RESULT_

    TEST "Decrypted result" "[ -n  \"$DECRYPTED_RESULT_\" ]"
    TEST "Valid decrypted result" "[ \"${DATA}\" == \"${DECRYPTED_RESULT_}\" ]"

    DECRYPTED_RESULT_=
    decrypt_data_with_passphrase "Wrong data"  "${PASSPHRASE}" DECRYPTED_RESULT_ >/dev/null 2>&1

    TEST "Wrong decrypted result" "[ -z  \"$DECRYPTED_RESULT_\" ]"

END_TEST_SUITE

}

test_encrypt_file()
{

START_TEST_SUITE "Encrypt file with passphase" $(basename ${BASH_SOURCE})

    create_temp_kb_file TMP_FILE

    TEST "Input file" "[ -f  \"$TMP_FILE\" ]"

    local PASSPHRASE="secret passphrase"

    encrypt_file ${TMP_FILE} "${PASSPHRASE}"

    TEST "Encrypted file" "[ -f  $(crypted_name $TMP_FILE) ]"
    TEST "Input file was renamed" "[ ! -f  $TMP_FILE ]"

    decrypt_file $(crypted_name $TMP_FILE) "${PASSPHRASE}"

    TEST "Decrypted file" "[ -f  $TMP_FILE ]"

END_TEST_SUITE

}

test_encrypt_file_with_key_file()
{

START_TEST_SUITE "Encrypt file with key file" $(basename ${BASH_SOURCE})

    create_temp_kb_file TMP_FILE

    TEST "Input file" "[ -f  \"$TMP_FILE\" ]"

    create_temp_kb_file KEY_FILE

    TEST "Key file" "[ -f  \"$KEY_FILE\" ]"

    local PASSPHRASE="secret passphrase"

    encrypt_file_with_key_file ${TMP_FILE} ${KEY_FILE}

    TEST "Encrypted file" "[ -f  $(crypted_name $TMP_FILE) ]"
    TEST "Input file was renamed" "[ ! -f  $TMP_FILE ]"

    decrypt_file_with_key_file $(crypted_name $TMP_FILE) ${KEY_FILE}

    TEST "Decrypted file" "[ -f  $TMP_FILE ]"

END_TEST_SUITE

}

test_encrypt_name()
{

START_TEST_SUITE "Encrypt file name with passphase" $(basename ${BASH_SOURCE})

    create_temp_kb_file TMP_FILE

    TEST "Input file" "[ -f  \"$TMP_FILE\" ]"

    local PASSPHRASE="secret passphrase"

    MESSAGE $TMP_FILE

    encrypt_name ${TMP_FILE} "${PASSPHRASE}" 0 ENCRYPTED_FILE

    MESSAGE $ENCRYPTED_FILE

    TEST "Input file was renamed" "[ ! -f  $TMP_FILE ]"
    TEST "Encrypted file" "[ -f  $ENCRYPTED_FILE ]"

    SH_TEST_FMK_TMP_FILES="${SH_TEST_FMK_TMP_FILES} ${ENCRYPTED_FILE}"

    decrypt_name $ENCRYPTED_FILE "${PASSPHRASE}"

    TEST "Decrypted file" "[ -f  $TMP_FILE ]"
    TEST "Decrypted file was renamed" "[ ! -f  $ENCRYPTED_FILE ]"

END_TEST_SUITE
}

test_encrypt_name_with_key_file()
{

START_TEST_SUITE "Encrypt file name with key file" $(basename ${BASH_SOURCE})

    create_temp_kb_file TMP_FILE

    TEST "Input file" "[ -f  \"$TMP_FILE\" ]"

    create_temp_kb_file KEY_FILE

    TEST "Key file" "[ -f  \"$KEY_FILE\" ]"

    local PASSPHRASE="secret passphrase"

    MESSAGE $TMP_FILE

    encrypt_file_with_key_file ${TMP_FILE} ${KEY_FILE} 0 ENCRYPTED_FILE

    MESSAGE $ENCRYPTED_FILE

    TEST "Encrypted file" "[ -f  $(crypted_name $TMP_FILE) ]"
    TEST "Input file was renamed" "[ ! -f  $TMP_FILE ]"

    decrypt_file_with_key_file $(crypted_name $TMP_FILE) ${KEY_FILE}

    TEST "Decrypted file" "[ -f  $TMP_FILE ]"

END_TEST_SUITE

}

test_total_encryption_file()
{

START_TEST_SUITE "Total encryption" $(basename ${BASH_SOURCE})

    create_temp_kb_file TMP_FILE

    TEST "Input file" "[ -f  \"$TMP_FILE\" ]"

    local PASSPHRASE="secret passphrase"

    MESSAGE $TMP_FILE

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

    check_file_totally_encrypted ${TMP_FILE} __ENCRYPTED_NAME __ENCRYPTED_CONTENT

    TEST "File is open" "[[ ! -n  \"$__ENCRYPTED_NAME\" && ! -n \"$__ENCRYPTED_CONTENT\" ]]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

    encrypt_file ${TMP_FILE} "${PASSPHRASE}"

    local ENCRYPTED_CONTENT_FILE=$(crypted_name ${TMP_FILE})

    SH_TEST_FMK_TMP_FILES="${SH_TEST_FMK_TMP_FILES} ${ENCRYPTED_CONTENT_FILE}"

    TEST "Input file was renamed" "[ ! -f  $TMP_FILE ]"
    TEST "Encrypted content of file" "[ -f  $ENCRYPTED_CONTENT_FILE ]"

    check_file_totally_encrypted ${ENCRYPTED_CONTENT_FILE} __ENCRYPTED_NAME __ENCRYPTED_CONTENT

    TRACE "($(basename ${BASH_SOURCE}):${LINENO}) $__ENCRYPTED_NAME; $__ENCRYPTED_CONTENT"

    TEST "File content was encrypted" "[[ ! -n  \"$__ENCRYPTED_NAME\" && -n \"$__ENCRYPTED_CONTENT\" ]]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

    encrypt_name ${ENCRYPTED_CONTENT_FILE} "${PASSPHRASE}" 0 ENCRYPTED_FILE

    TEST "Input file was renamed" "[ ! -f  $ENCRYPTED_CONTENT_FILE ]"
    TEST "Totally encrypted file" "[ -f  $ENCRYPTED_FILE ]"

    check_file_totally_encrypted ${ENCRYPTED_FILE} __ENCRYPTED_NAME __ENCRYPTED_CONTENT

    TRACE "($(basename ${BASH_SOURCE}):${LINENO}) $__ENCRYPTED_NAME; $__ENCRYPTED_CONTENT"

    TEST "File was totally encrypted" "[[ -n  \"$__ENCRYPTED_NAME\" && -n \"$__ENCRYPTED_CONTENT\" ]]"

    __ENCRYPTED_NAME=
    __ENCRYPTED_CONTENT=

    MESSAGE $ENCRYPTED_FILE

    SH_TEST_FMK_TMP_FILES="${SH_TEST_FMK_TMP_FILES} ${ENCRYPTED_FILE}"

    decrypt_name $ENCRYPTED_FILE "${PASSPHRASE}"

    TEST "Decrypted name of file" "[ -f  $ENCRYPTED_CONTENT_FILE ]"
    TEST "Decrypted file was renamed" "[ ! -f  $ENCRYPTED_FILE ]"

    decrypt_file $ENCRYPTED_CONTENT_FILE "${PASSPHRASE}"

    TEST "Decrypted content of file" "[ -f  $TMP_FILE ]"
    TEST "Decrypted file was renamed" "[ ! -f  $ENCRYPTED_CONTENT_FILE ]"

END_TEST_SUITE
}

SH_TEST_FMK_SUPPRESS_WELCOM=1
INIT_SH_TEST_FMK "lib_crypt.sh test"

init_crypt_tests_fixture THIS_CRYPT_SANDBOX

test_crypted_name
test_encrypt_data
test_encrypt_file
test_encrypt_file_with_key_file
test_encrypt_name
test_encrypt_name_with_key_file
test_total_encryption_file
