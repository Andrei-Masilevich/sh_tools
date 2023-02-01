#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh
source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_realpath.sh


######################################################################################
# ENCRYPTION constants

__ENCRYPTED_EXT_SYMBOL='~'
__FAKE_PREFIX='-> '
__FAKE_PASSPHRASE='xxxxxx'
__LIB_CRYPT_ERROR=6
__KEY_DUMP='--'
__KEY_MINSIZE=5
__PROTECT_MASTER_KEY=1
__MAX_ENCRYPTED_FILENAME=200
__CUT_MAX_ENCRYPTED_FILENAME=

######################################################################################

function __echo_check_silency()
{
    (( $LIB_CRYPT_OPTION_VERBOSE )) && echo $@
}

function __print_error_check_silency()
{
    (( $LIB_CRYPT_OPTION_VERBOSE )) && print_error $@
}

######################################################################################
# ENCRYPTION implementation

# Return function conception and error handling:
#
# It doesn't use 'return' keyword to avoid forcing application code
# to process invalid result (by simplification sake)
# If the issue can't be solved inside the function itself it does 'exit' 
# Decryption function is exception but the invalid value returned
# via the reference argument.

function init_crypt()
{
    if [ -z ${SH_TOOLS_DATA_DIR_PATH} ]; then
        print_error "Environment has not been set!"
        exit $__LIB_CRYPT_ERROR
    fi

    if [ ! -d ${SH_TOOLS_DATA_DIR_PATH} ]; then
        print_error "Invalid environment \"${SH_TOOLS_DATA_DIR_PATH}\"!"
        exit $__LIB_CRYPT_ERROR
    fi

    check_crypt_requirements

    # Use OPTIONS:
    #
    #   LIB_CRYPT_OPTION_VERBOSE
    #   LIB_CRYPT_OPTION_FAKE_DEBUG

    SH_TOOLS_MASTER_KEY_PATH=${SH_TOOLS_DATA_DIR_PATH}/.master
    if [ -f "${SH_TOOLS_MASTER_KEY_PATH}" ]; then
        SH_TOOLS_MASTER_KEY_PATH=$(get_realpath ${SH_TOOLS_MASTER_KEY_PATH})
    fi

    if (( LIB_CRYPT_OPTION_VERBOSE )); then
        echo "$(emoji $EMOJI_ID_16_OK) ($(basename $0) -> $(basename ${BASH_SOURCE})) INITIALIZED (${SH_TOOLS_MASTER_KEY_PATH})"
    fi
}

function check_crypt_requirements()
{
    if [[ -z $(find_ccrypt) ]]; then
        print_error "CCRYPT required for this library (https://ccrypt.sourceforge.net/#downloading)!"
        exit $__LIB_CRYPT_ERROR
    fi
    if [ -z $(which sha256sum) ]; then
        print_error "sha256sum utility is required!"
        exit $__LIB_CRYPT_ERROR
    fi
    if [ -z $(which base64) ]; then
        print_error "base64 utility is required!"
        exit $__LIB_CRYPT_ERROR
    fi
}

function crypted_name()
{
    if [ $# -ge 1 ]; then
        local CRYPT_EXTENTION=$2
        if [ -z $CRYPT_EXTENTION ]; then
            CRYPT_EXTENTION=.$__ENCRYPTED_EXT_SYMBOL
        fi
        echo "${1}${CRYPT_EXTENTION}"
    else
        echo
    fi
}

function restore_name()
{
    if [ $# -ge 1 ]; then
        local CRYPT_EXTENTION=$2
        if [ -z $CRYPT_EXTENTION ]; then
            CRYPT_EXTENTION=.$__ENCRYPTED_EXT_SYMBOL
        fi

        local FILE_NAME=${1} 
        FILE_NAME=${FILE_NAME:0:-$((${#CRYPT_EXTENTION}))}

        echo "${FILE_NAME}"
    else
        echo
    fi
}

function __encrypt_file_with_passphrase()
{
    local DATA_FILE=${1}
    local KEY_PASSPHRASE="${2}"
    
    local EXT_OPT=
    (( $LIB_CRYPT_OPTION_VERBOSE )) && EXT_OPT='-q'
    
    local BIN=ccencrypt
    (( $LIB_CRYPT_OPTION_FAKE_DEBUG )) && BIN="echo $__FAKE_PREFIX $BIN"
    (( $LIB_CRYPT_OPTION_FAKE_DEBUG )) && KEY_PASSPHRASE=$__FAKE_PASSPHRASE
    
    __echo_check_silency ">> $BIN ${EXT_OPT} -K $__FAKE_PASSPHRASE -S .$__ENCRYPTED_EXT_SYMBOL ${DATA_FILE}"

    $BIN ${EXT_OPT} -K "${KEY_PASSPHRASE}" -S .$__ENCRYPTED_EXT_SYMBOL ${DATA_FILE}
}

function __decrypt_file_with_passphrase()
{
    local DATA_FILE=${1}
    local KEY_PASSPHRASE=${2}
    declare -n DECRYPTION_ERROR=$3
    local EXT_OPT=
    (( $LIB_CRYPT_OPTION_VERBOSE )) && EXT_OPT='-q'
    
    local BIN=ccdecrypt
    (( $LIB_CRYPT_OPTION_FAKE_DEBUG )) && BIN="echo $__FAKE_PREFIX $BIN"
    (( $LIB_CRYPT_OPTION_FAKE_DEBUG )) && KEY_PASSPHRASE=$__FAKE_PASSPHRASE

    __echo_check_silency ">> $BIN ${EXT_OPT} -K $__FAKE_PASSPHRASE -S .$__ENCRYPTED_EXT_SYMBOL ${DATA_FILE}"

    $BIN ${EXT_OPT} -K "${KEY_PASSPHRASE}" -S .$__ENCRYPTED_EXT_SYMBOL ${DATA_FILE} 2>/dev/null
    if [ $? -ne 0 ]; then
        DECRYPTION_ERROR=1
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Wrong key!" 
    fi
}

function __encode_base64()
{
    local BASE64=${1}
    local _E=$BASE64
    _E=${_E//+/-}; _E=${_E////\{}; _E=${_E//=/_}
    echo $_E
}

function __decode_base64()
{
    local EBASE64=${1}
    local _E=$EBASE64
    _E=${_E//-/+}; _E=${_E//\{//}; _E=${_E//_/=}
    echo $_E
}

function __decode_encrypted_data()
{
    local DATA_EBASE64=${1}

    local BASE64=$(__decode_base64 $DATA_EBASE64)

    echo -n ${BASE64}|base64 -d > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo ${BASE64}
    fi
}

function encrypt_data_with_passphrase()
{
    local DATA_TXT=${1}
    local KEY_PASSPHRASE=${2}
    declare -n ENCRYPTED_RESULT=$3
    
    local EXT_OPT=
    (( $LIB_CRYPT_OPTION_VERBOSE )) && EXT_OPT='-q'
    
    local BIN=ccencrypt
    local CMD="$BIN ${EXT_OPT} -K "

    __echo_check_silency ">> $__FAKE_PREFIX | $CMD $__FAKE_PASSPHRASE "

    local BASE64=$(echo -n ${DATA_TXT}|${CMD} "${KEY_PASSPHRASE}"|base64 -w0)
    ENCRYPTED_RESULT=$(__encode_base64 $BASE64)
}

function decrypt_data_with_passphrase()
{
    local DATA_EBASE64=${1}
    local KEY_PASSPHRASE=${2}
    declare -n DECRYPTED_RESULT=$3

    local EXT_OPT=
    (( $LIB_CRYPT_OPTION_VERBOSE )) && EXT_OPT='-q'

    local BIN=ccdecrypt
    local CMD="$BIN ${EXT_OPT} -K "

    __echo_check_silency ">> $__FAKE_PREFIX | $CMD $__FAKE_PASSPHRASE "

    local BASE64=$(__decode_encrypted_data $DATA_EBASE64)
    if [ -n "${BASE64}" ]; then
        DECRYPTED_RESULT=$(echo -n ${BASE64}|base64 -d|${CMD} "${KEY_PASSPHRASE}" 2>/dev/null)
        if [ $? -ne 0 ]; then
            DECRYPTED_RESULT=
            __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Wrong key!" 
        fi
    else
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid format for data!"
    fi
}

function __encrypt_file_with_key_file()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}
    
    local EXT_OPT=
    (( $LIB_CRYPT_OPTION_VERBOSE )) && EXT_OPT='-f -q'

    local BIN=ccencrypt
    (( $LIB_CRYPT_OPTION_FAKE_DEBUG )) && BIN="echo $__FAKE_PREFIX $BIN"

    __echo_check_silency ">> $BIN ${EXT_OPT} -k ${KEY_FILE} -S .$__ENCRYPTED_EXT_SYMBOL ${DATA_FILE}"

    $BIN ${EXT_OPT} -k ${KEY_FILE} -S .$__ENCRYPTED_EXT_SYMBOL ${DATA_FILE}
}

function __decrypt_file_with_key_file()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}
    declare -n DECRYPTION_ERROR=$3
    local EXT_OPT=
    (( $LIB_CRYPT_OPTION_VERBOSE )) && EXT_OPT='-f -q'

    local BIN=ccdecrypt
    (( $LIB_CRYPT_OPTION_FAKE_DEBUG )) && BIN="echo $__FAKE_PREFIX $BIN"

    __echo_check_silency ">> $BIN ${EXT_OPT} -k ${KEY_FILE} -S .$__ENCRYPTED_EXT_SYMBOL ${DATA_FILE}"

    $BIN ${EXT_OPT} -k ${KEY_FILE} -S .$__ENCRYPTED_EXT_SYMBOL ${DATA_FILE} 2>/dev/null
    if [ $? -ne 0 ]; then
        DECRYPTION_ERROR=1
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Wrong key!" 
    fi
}

function __encrypt_data_with_key_file()
{
    local DATA_TXT=${1}
    local KEY_FILE=${2}
    declare -n ENCRYPTED_RESULT=$3
    
    local EXT_OPT=
    (( $LIB_CRYPT_OPTION_VERBOSE )) && EXT_OPT='-q'
    
    local BIN=ccencrypt
    local CMD="$BIN ${EXT_OPT} -k ${KEY_FILE}"

    __echo_check_silency ">> $__FAKE_PREFIX | $CMD"

    local BASE64=$(echo -n ${DATA_TXT}|${CMD}|base64 -w0)
    ENCRYPTED_RESULT=$(__encode_base64 $BASE64)
}

function __decrypt_data_with_key_file()
{
    local DATA_EBASE64=${1}
    local KEY_FILE=${2}
    declare -n DECRYPTED_RESULT=$3

    local EXT_OPT=
    (( $LIB_CRYPT_OPTION_VERBOSE )) && EXT_OPT='-q'

    local BIN=ccdecrypt
    local CMD="$BIN ${EXT_OPT} -k ${KEY_FILE}"

    __echo_check_silency ">> $__FAKE_PREFIX | $CMD"

    local BASE64=$(__decode_base64 $DATA_EBASE64)
    DECRYPTED_RESULT=$(echo -n ${BASE64}|base64 -d|${CMD} 2>/dev/null)
    if [ $? -ne 0 ]; then
        DECRYPTED_RESULT=
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Wrong key!" 
    fi
}

function __decrypt_file_with_passphrase_and_singleline_compliance()
{
    if [ $# -ne 3 ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"     
        exit $__LIB_CRYPT_ERROR
    fi

    local SECRET_FILE=${1}
    local KEY_PASSPHRASE=${2}
    declare -n DECRYPTED_RESULT=$3

    local EXT_OPT=
    (( $LIB_CRYPT_OPTION_VERBOSE )) && EXT_OPT='-q'

    local BIN=ccdecrypt
    local CMD="$BIN ${EXT_OPT} -K "

    __echo_check_silency ">> ${CMD} $__FAKE_PASSPHRASE < ${SECRET_FILE}"

    DECRYPTED_RESULT=$(${CMD} "${KEY_PASSPHRASE}" < ${SECRET_FILE} 2>/dev/null|sha256sum -b|cut -d ' ' -f 1)
    if [ $DECRYPTED_RESULT == $(echo -n|sha256sum -b|cut -d ' ' -f 1) ]; then
        DECRYPTED_RESULT=
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Wrong key!" 
    fi
}

function __decrypt_master_key_with_passphrase()
{
    if [ -z $SH_TOOLS_MASTER_KEY_PATH ]; then
        print_error "Uninitialized environment!"
        exit $__LIB_CRYPT_ERROR
    fi

    local SECRET_FILE=${SH_TOOLS_MASTER_KEY_PATH}.$__ENCRYPTED_EXT_SYMBOL

    __decrypt_file_with_passphrase_and_singleline_compliance "${SECRET_FILE}" $@
}

function get_decryption_with_singleline_compliance()
{
    if [ $# -ne 2 ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO})  Invalid arguments!"     
        exit $__LIB_CRYPT_ERROR
    fi

    local SECRET_FILE=${1}
    declare -n DECRYPTED_RESULT=$2

    DECRYPTED_RESULT=$(cat < ${SECRET_FILE} 2>/dev/null|sha256sum -b|cut -d ' ' -f 1)
    if [ $DECRYPTED_RESULT == $(echo -n|sha256sum -b|cut -d ' ' -f 1) ]; then
        DECRYPTED_RESULT=
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Wrong key!" 
    fi
}

function prob_encrypted_file_name()
{
    local DATA_FILE=${1}
    declare -n ENCRYPTED_NAME_=$2
    if [ $# -ge 3 ]; then
        declare -n FILE_NAME_REST_=$3
    else
        local FILE_NAME_REST_=
    fi 

    local EXT=$(get_file_extention ${DATA_FILE})
    if [ ${EXT} == $__ENCRYPTED_EXT_SYMBOL ]; then
        local DATA_FILENAME=$(basename ${DATA_FILE})
        ENCRYPTED_NAME_=${DATA_FILENAME:0:-$((${#__ENCRYPTED_EXT_SYMBOL}+1))}
        FILE_NAME_REST_=".$__ENCRYPTED_EXT_SYMBOL"
    fi
}

function check_file_totally_encrypted()
{
    local DATA_FILE=${1}
    declare -n ENCRYPTED_NAME_=$2
    if [ $# -ge 3 ]; then
        declare -n FILE_CONTENT_ENCRYPTED=$3
    else
        local FILE_CONTENT_ENCRYPTED=
    fi
    local DATA_TO_DECRYPT=
    local NEXT=1

    [ -z $DATA_FILE ] && NEXT=

    if (( $NEXT )); then 
        [ -f $DATA_FILE ] || NEXT=
    fi
    if (( $NEXT )); then
        prob_encrypted_file_name ${DATA_FILE} ENCRYPTED_NAME__
        if [ -n "$ENCRYPTED_NAME__" ]; then
            DATA_TO_DECRYPT=${ENCRYPTED_NAME__}
            ENCRYPTED_NAME__=
            FILE_CONTENT_ENCRYPTED=1
        else
            NEXT=
        fi
    fi
    if (( $NEXT )); then 
        local BASE64=$(__decode_encrypted_data ${DATA_TO_DECRYPT})
        if [ -n "${BASE64}" ]; then
            ENCRYPTED_NAME_=${DATA_TO_DECRYPT}
        fi
    fi
}

function __encrypt_file()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}
    local KEY_PASSPHRASE=
    local NEXT=1

    if [[ -n "${KEY_FILE}" && ${KEY_FILE} == $__KEY_DUMP ]]; then
        KEY_FILE=
        KEY_PASSPHRASE=${3}

        if [ ! -n "${KEY_PASSPHRASE}" ]; then
            __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid passphrase!"
            NEXT=
        fi
    elif [[ -z ${KEY_FILE} || ! -f "${KEY_FILE}" ]]; then
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid key file!"
        NEXT=
    fi
    if [[ ! -f ${DATA_FILE} ]]; then
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid data file!"
        NEXT=
    fi

    if (( $NEXT )); then
        if (( $__PROTECT_MASTER_KEY )); then
            if [ -z $SH_TOOLS_MASTER_KEY_PATH ]; then
                print_error "Uninitialized environment!"
                exit $__LIB_CRYPT_ERROR
            fi
            if [ $(get_realpath ${DATA_FILE}) == $SH_TOOLS_MASTER_KEY_PATH ]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Can't operate with master key!"
                NEXT=
            fi
        fi
    fi
    if (( $NEXT )); then
        if [ -n "${KEY_FILE}"  ]; then
            if [ $(get_realpath ${DATA_FILE}) != $(get_realpath ${KEY_FILE}) ]; then
                __encrypt_file_with_key_file ${DATA_FILE} ${KEY_FILE}
            fi
        elif [ -n "${KEY_PASSPHRASE}" ]; then
            __encrypt_file_with_passphrase ${DATA_FILE} "${KEY_PASSPHRASE}"
        fi
    fi
}

# Encrypt file with passphrase
function encrypt_file()
{
    local DATA_FILE=${1}
    local KEY_PASSPHRASE=${2}

    local EXT=$(get_file_extention ${DATA_FILE})
    if [ ${EXT} != $__ENCRYPTED_EXT_SYMBOL ]; then
        __encrypt_file ${DATA_FILE} $__KEY_DUMP ${KEY_PASSPHRASE}
    fi
}

# Encrypt file with key file
function encrypt_file_with_key_file()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}

    if [[ -z ${KEY_FILE} ||  ${KEY_FILE} == $__KEY_DUMP ]]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"
        exit $__LIB_CRYPT_ERROR
    fi

    local EXT=$(get_file_extention ${DATA_FILE})
    if [ ${EXT} != $__ENCRYPTED_EXT_SYMBOL ]; then
        __encrypt_file ${DATA_FILE} ${KEY_FILE}
    fi
}

function __decrypt_file()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}
    local KEY_PASSPHRASE=
    local NEXT=1

    if [[ -n "${KEY_FILE}" && ${KEY_FILE} == $__KEY_DUMP ]]; then
        KEY_FILE=
        KEY_PASSPHRASE=${3}
        shift
        if [ ! -n "${KEY_PASSPHRASE}" ]; then
            __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid passphrase!"
            NEXT=
        fi
    elif [[ -z ${KEY_FILE} || ! -f "${KEY_FILE}" ]]; then
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid key file!"
        NEXT=
    fi

    if [ $# -ge 3 ]; then
        declare -n DECRYPTION_ERROR=$3
    else
        local DECRYPTION_ERROR=
    fi

    if [[ ! -f ${DATA_FILE} ]]; then
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid data file!"
        NEXT=
    fi

    if (( $NEXT )); then
        if (( $__PROTECT_MASTER_KEY )); then
            if [ -z $SH_TOOLS_MASTER_KEY_PATH ]; then
                print_error "Uninitialized environment!"
                exit $__LIB_CRYPT_ERROR
            fi
            if [ $(get_realpath ${DATA_FILE}) == $SH_TOOLS_MASTER_KEY_PATH ]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Can't operate with master key!"
                NEXT=
            fi
        fi
    fi
    if (( $NEXT )); then
        if [ -n "${KEY_FILE}"  ]; then
            if [ $(get_realpath ${DATA_FILE}) != $(get_realpath ${KEY_FILE}) ]; then
                __decrypt_file_with_key_file ${DATA_FILE} ${KEY_FILE} _DECRYPTION_ERROR
                DECRYPTION_ERROR=$_DECRYPTION_ERROR
                _DECRYPTION_ERROR=
            fi
        elif [ -n "${KEY_PASSPHRASE}" ]; then
            __decrypt_file_with_passphrase ${DATA_FILE} "${KEY_PASSPHRASE}" _DECRYPTION_ERROR
            DECRYPTION_ERROR=$_DECRYPTION_ERROR
            _DECRYPTION_ERROR=
        fi
    fi

    if (( NEXT == 0 )); then
        DECRYPTION_ERROR=1
    fi    
}

# Decrypt file with passphrase
function decrypt_file()
{
    local DATA_FILE=${1}
    local KEY_PASSPHRASE=${2}

    if [ $# -lt 2 ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"     
        exit $__LIB_CRYPT_ERROR
    fi
    shift
    shift

    local EXT=$(get_file_extention ${DATA_FILE})
    if [ ${EXT} == $__ENCRYPTED_EXT_SYMBOL ]; then
        __decrypt_file ${DATA_FILE} $__KEY_DUMP ${KEY_PASSPHRASE} $@
    fi
}

# Encrypt file with key file
function decrypt_file_with_key_file()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}

    if [ $# -lt 2 ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"     
        exit $__LIB_CRYPT_ERROR
    fi
    shift
    shift
    
    if [[ -z ${KEY_FILE} ||  ${KEY_FILE} == $__KEY_DUMP ]]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"
        exit $__LIB_CRYPT_ERROR
    fi

    local EXT=$(get_file_extention ${DATA_FILE})
    if [ ${EXT} == $__ENCRYPTED_EXT_SYMBOL ]; then
        __decrypt_file ${DATA_FILE} ${KEY_FILE} $@
    fi
}

function encrypt_folder()
{
    local DATA_FOLDER=$1
    if [[ -n "${DATA_FOLDER}" && -d ${DATA_FOLDER} ]]; then
        shift

        local KEY_FILE=${1}
        local KEY_PASSPHRASE=${2}

        for f in ${DATA_FOLDER}/*; do
            if [ -f $f ]; then
                local EXT=$(get_file_extention ${DATA_FILE})
                if [ ${EXT} != $__ENCRYPTED_EXT_SYMBOL ]; then
                    __encrypt_file $f ${KEY_FILE} "${KEY_PASSPHRASE}"
                fi
            fi
        done 
    else
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid data folder!"
    fi
}

function decrypt_folder()
{
    local DATA_FOLDER=$1
    if [[ -n "${DATA_FOLDER}" && -d ${DATA_FOLDER} ]]; then
        shift

        local KEY_FILE=${1}
        local KEY_PASSPHRASE=${2}

        for f in ${DATA_FOLDER}/*.$__ENCRYPTED_EXT_SYMBOL; do
            if [ -f $f ]; then
                __decrypt_file $f ${KEY_FILE} "${KEY_PASSPHRASE}"
            fi        
        done 
    else
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid data folder!"
    fi
}

function encrypt_folder_recursively()
{
    local DATA_FOLDER=$1
    if [[ -n "${DATA_FOLDER}" && -d ${DATA_FOLDER} ]]; then
        shift
        local DATA_FILES=()
        pushd ${DATA_FOLDER} > /dev/null
        while IFS=  read -r -d $'\0'; do
            DATA_FILES+=("$REPLY")
        done < <(find . -type f ! -name '*.'$__ENCRYPTED_EXT_SYMBOL -print0 2>/dev/null)

        local KEY_FILE=${1}
        local KEY_PASSPHRASE=${2}

        for f in "${DATA_FILES[@]}"; do
            __encrypt_file $f ${KEY_FILE} "${KEY_PASSPHRASE}"
        done
        popd > /dev/null
    else
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid data folder!"
    fi
}

function decrypt_folder_recursively()
{
    local DATA_FOLDER=$1
    if [[ -n "${DATA_FOLDER}" && -d ${DATA_FOLDER} ]]; then
        shift
        local DATA_FILES=()
        pushd ${DATA_FOLDER} > /dev/null
        while IFS=  read -r -d $'\0'; do
            DATA_FILES+=("$REPLY")
        done < <(find . -type f -iname '*.'$__ENCRYPTED_EXT_SYMBOL -print0 2>/dev/null)

        local KEY_FILE=${1}
        local KEY_PASSPHRASE=${2}

        for f in "${DATA_FILES[@]}"; do
            __decrypt_file $f ${KEY_FILE} "${KEY_PASSPHRASE}"
        done
        popd > /dev/null
    else
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid data folder!"
    fi
}

function __encrypt_name()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}
    local KEY_PASSPHRASE=
    local NEXT=1

    if [[ -n "${KEY_FILE}" && ${KEY_FILE} == $__KEY_DUMP ]]; then
        KEY_FILE=
        KEY_PASSPHRASE=${3}
        shift
        if [ ! -n "${KEY_PASSPHRASE}" ]; then
            __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid passphrase!"
            NEXT=
        fi
    elif [[ -z ${KEY_FILE} || ! -f "${KEY_FILE}" ]]; then
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid key file!"
        NEXT=
    fi

    if (( $NEXT )); then
        local IS_DIR=$3
        if [ $# -ge 4 ]; then
            declare -n ENCRYPTED_FILE_OBJECT_REFF=$4
        else
            local ENCRYPTED_FILE_OBJECT_REFF=
        fi

        if (( $IS_DIR )); then
            if [[ ! -d ${DATA_FILE} ]]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid folder!"
                NEXT=
            fi
        else
            if [[ ! -f ${DATA_FILE} ]]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid file!"
                NEXT=
            fi
        fi
    fi

    DATA_FILE=$(get_realpath ${DATA_FILE})

    if (( $NEXT )); then
        if (( $__PROTECT_MASTER_KEY )); then
            if [ -z $SH_TOOLS_MASTER_KEY_PATH ]; then
                print_error "Uninitialized environment!"
                exit $__LIB_CRYPT_ERROR
            fi        
            if [ ${DATA_FILE} == $SH_TOOLS_MASTER_KEY_PATH ]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Can't operate with master key!"
                NEXT=
            fi
        fi
    fi
    if (( $NEXT )); then
        local DATA_FILENAME=$(basename ${DATA_FILE})

        if (( ${#DATA_FILENAME} > $__MAX_ENCRYPTED_FILENAME )); then
            if (( $__CUT_MAX_ENCRYPTED_FILENAME )); then
                DATA_FILENAME=${DATA_FILENAME:0:$__MAX_ENCRYPTED_FILENAME}
                if (( $IS_DIR )); then
                    if [ -d $(dirname ${DATA_FILE})/${DATA_FILENAME} ]; then
                        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Folder already exists!"
                        NEXT=
                    fi
                else
                    if [ -f $(dirname ${DATA_FILE})/${DATA_FILENAME} ]; then
                        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) File already exists!"
                        NEXT=
                    fi
                fi
            else
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Too long filename!"
                NEXT= 
            fi
        fi

        if (( $NEXT )); then
            local DATA_TO_ENCRYPT=
            local DATA_REST=

            prob_encrypted_file_name ${DATA_FILENAME} DATA_TO_ENCRYPT_ DATA_REST_
            if [[ -n "${DATA_TO_ENCRYPT_}" && -n "${DATA_REST_}" ]]; then
                DATA_TO_ENCRYPT=${DATA_TO_ENCRYPT_}
                DATA_REST=${DATA_REST_}
            else
                DATA_TO_ENCRYPT=${DATA_FILENAME}
            fi
            DATA_TO_ENCRYPT_=
            DATA_REST_=

            local ENCRYPTED_DATA=

            if [ -n "${KEY_FILE}"  ]; then
                if [ ${DATA_FILE} != $(get_realpath ${KEY_FILE}) ]; then
                    __encrypt_data_with_key_file ${DATA_TO_ENCRYPT} ${KEY_FILE} __ENCRYPTED_RESULT
                    ENCRYPTED_DATA=${__ENCRYPTED_RESULT}
                    __ENCRYPTED_RESULT=
                fi
            elif [ -n "${KEY_PASSPHRASE}" ]; then
                encrypt_data_with_passphrase ${DATA_TO_ENCRYPT} "${KEY_PASSPHRASE}" __ENCRYPTED_RESULT
                ENCRYPTED_DATA=${__ENCRYPTED_RESULT}
                __ENCRYPTED_RESULT=
            fi
            if [ -n "$ENCRYPTED_DATA" ]; then
                ENCRYPTED_FILE_OBJECT_REFF=$(dirname ${DATA_FILE})/${ENCRYPTED_DATA}${DATA_REST}
                local BIN=mv
                (( $LIB_CRYPT_OPTION_FAKE_DEBUG )) && BIN="echo $__FAKE_PREFIX $BIN"
                $BIN -f ${DATA_FILE} ${ENCRYPTED_FILE_OBJECT_REFF}
                if [ ! -e ${ENCRYPTED_FILE_OBJECT_REFF} ]; then
                    __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Can't rename to encrypted!"
                    ENCRYPTED_FILE_OBJECT_REFF=  
                fi
            fi
        fi
    fi
}

# Encrypt file name with passphrase
function encrypt_name()
{
    local DATA_FILE=${1}
    local KEY_PASSPHRASE=${2}

    if [ $# -lt 2 ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"     
        exit $__LIB_CRYPT_ERROR
    fi

    shift; shift

    __encrypt_name ${DATA_FILE} $__KEY_DUMP "${KEY_PASSPHRASE}" $@
}

# Encrypt file name with key file
function encrypt_name_with_key_file()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}

    if [ $# -lt 2 ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"     
        exit $__LIB_CRYPT_ERROR
    fi

    shift; shift

    if [[ -z ${KEY_FILE} ||  ${KEY_FILE} == $__KEY_DUMP ]]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"
        exit $__LIB_CRYPT_ERROR
    fi

    __encrypt_name ${DATA_FILE} ${KEY_FILE} $@
}

function __decrypt_name()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}
    local KEY_PASSPHRASE=
    local NEXT=1

    if [[ -n "${KEY_FILE}" && ${KEY_FILE} == $__KEY_DUMP ]]; then
        KEY_FILE=
        KEY_PASSPHRASE=${3}
        shift
        if [ ! -n "${KEY_PASSPHRASE}" ]; then
            __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid passphrase!"
            NEXT=
        fi
    elif [[ -z ${KEY_FILE} || ! -f "${KEY_FILE}" ]]; then
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid key file!"
        NEXT=
    fi

    local IS_DIR=$3
    if [ $# -ge 4 ]; then
        declare -n DECRYPTION_ERROR=$4
    else
        local DECRYPTION_ERROR=
    fi

    if (( $NEXT )); then
        if (( $IS_DIR )); then
            if [[ ! -d ${DATA_FILE} ]]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid folder!"
                NEXT=
            fi
        else
            if [[ ! -f ${DATA_FILE} ]]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid file!"
                NEXT=
            fi
        fi
    fi

    DATA_FILE=$(get_realpath ${DATA_FILE})

    if (( $NEXT )); then
        if (( $__PROTECT_MASTER_KEY )); then
            if [ -z $SH_TOOLS_MASTER_KEY_PATH ]; then
                print_error "Uninitialized environment!"
                exit $__LIB_CRYPT_ERROR
            fi        
            if [ ${DATA_FILE} == $SH_TOOLS_MASTER_KEY_PATH ]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Can't operate with master key!"
                NEXT=
            fi
        fi
    fi

    if (( $NEXT )); then
        local DATA_FILENAME=$(basename ${DATA_FILE})
        
        local DATA_TO_DECRYPT=
        local DATA_REST=

        prob_encrypted_file_name ${DATA_FILENAME} DATA_TO_DECRYPT_ DATA_REST_
        if [[ -n "${DATA_TO_DECRYPT_}" && -n "${DATA_REST_}" ]]; then
            DATA_TO_DECRYPT=${DATA_TO_DECRYPT_}
            DATA_REST=${DATA_REST_}
        else
            DATA_TO_DECRYPT=${DATA_FILENAME}
        fi
        DATA_TO_DECRYPT_=
        DATA_REST_=

        local DECRYPTED_DATA=

        if [ -n "${KEY_FILE}"  ]; then
            if [ ${DATA_FILE} != $(get_realpath ${KEY_FILE}) ]; then
                __decrypt_data_with_key_file ${DATA_TO_DECRYPT} ${KEY_FILE} __DECRYPTED_RESULT
                DECRYPTED_DATA=${__DECRYPTED_RESULT}
                __DECRYPTED_RESULT=
            fi
        elif [ -n "${KEY_PASSPHRASE}" ]; then
            decrypt_data_with_passphrase ${DATA_TO_DECRYPT} "${KEY_PASSPHRASE}" __DECRYPTED_RESULT
            DECRYPTED_DATA=${__DECRYPTED_RESULT}
            __DECRYPTED_RESULT=
        fi
        if [ -n "$DECRYPTED_DATA" ]; then
            local DECRYPTED_FILE_OBJECT=$(dirname ${DATA_FILE})/${DECRYPTED_DATA}${DATA_REST}
            local BIN=mv
            (( $LIB_CRYPT_OPTION_FAKE_DEBUG )) && BIN="echo $__FAKE_PREFIX $BIN"
            $BIN -f ${DATA_FILE} ${DECRYPTED_FILE_OBJECT}
            if [ ! -e ${DECRYPTED_FILE_OBJECT_REFF} ]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Can't rename to decrypted!"
                NEXT=
            fi            
        else
            __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Can' decrypt data!"
            NEXT=
        fi
    fi

    if (( NEXT == 0 )); then
        DECRYPTION_ERROR=1
    fi
}

# Decrypt file name with passphrase
function decrypt_name()
{
    local DATA_FILE=${1}
    local KEY_PASSPHRASE=${2}

    if [ $# -lt 2 ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"     
        exit $__LIB_CRYPT_ERROR
    fi

    shift; shift

    __decrypt_name ${DATA_FILE} $__KEY_DUMP "${KEY_PASSPHRASE}" $@
}

# Decrypt file name with key file
function decrypt_name_with_key_file()
{
    local DATA_FILE=${1}
    local KEY_FILE=${2}

    if [ $# -lt 2 ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"     
        exit $__LIB_CRYPT_ERROR
    fi

    shift; shift
    
    if [[ -z ${KEY_FILE} ||  ${KEY_FILE} == $__KEY_DUMP ]]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments!"
        exit $__LIB_CRYPT_ERROR
    fi

    __decrypt_name ${DATA_FILE} ${KEY_FILE} $@
}

function cleanup_secret_file()
{
    local SECRET_FILE=$1
    local STRICT=$2
    if [[ -n "${SECRET_FILE}" && -f ${SECRET_FILE} ]]; then
        local FILE_SZ=$(du -b ${SECRET_FILE}| cut -f 1)
        dd if=/dev/urandom bs=${FILE_SZ} count=1 of=${SECRET_FILE} 2>/dev/null
        rm -f ${SECRET_FILE}
    else
        if ((STRICT)); then
            print_error "($(basename ${BASH_SOURCE}):${LINENO}) Secret file is not found!"
            exit $__LIB_CRYPT_ERROR
        fi
    fi
}

function cleanup_secret_folder()
{
    local SECRET_FOLDER=$1
    local STRICT=$2
    if [[ -n "${SECRET_FOLDER}" && -d ${SECRET_FOLDER} ]]; then
        pushd ${SECRET_FOLDER} > /dev/null
        SECRET_FILES=()
        local OLD_IFS=${IFS}
        while IFS=  read -r -d $'\0'; do
            SECRET_FILES+=("$REPLY")
        done < <(find . -type f -print0)
        IFS=${OLD_IFS}
        local SECRET_FILES_IDX=0
        local SECRET_FILES_SZ=${#SECRET_FILES[@]}
        for (( ;SECRET_FILES_IDX<${SECRET_FILES_SZ}; SECRET_FILES_IDX++ ));
        do
            local SECRET_FILE=${SECRET_FILES[$SECRET_FILES_IDX]}
            cleanup_secret_file ${SECRET_FILE}
        done
        popd > /dev/null
        rm -rf ${SECRET_FOLDER}
    else
        if ((STRICT)); then
            print_error "($(basename ${BASH_SOURCE}):${LINENO}) Secret folder is not found!"
            exit $__LIB_CRYPT_ERROR
        fi
    fi
}

function create_secret_file()
{
    local SECRET_FILE=$1
    if [ -z ${SECRET_FILE} ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Key file is required!"
        exit $__LIB_CRYPT_ERROR        
    fi
    if [ -e ${SECRET_FILE} ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Key file already exists!"
        exit $__LIB_CRYPT_ERROR 
    fi

    dd if=/dev/urandom bs=512 count=4 of=${SECRET_FILE} 2>/dev/null

    shift
    get_decryption_with_singleline_compliance ${SECRET_FILE} $@
}

function create_passphrase()
{
    local NEXT=1
    declare -n PASSPHRASE=$1

    echo -n "> Enter passphrase: "
    read_secret _PASSPHRASE_ATTEMPT1

    [[ ( ! -n "${_PASSPHRASE_ATTEMPT1}" ) ]] || (( ${#_PASSPHRASE_ATTEMPT1} < $__KEY_MINSIZE )) && NEXT=

    if (( $NEXT )); then
        echo -n "> Enter same passphrase again: "
        read_secret _PASSPHRASE_ATTEMPT2

        [[ ( ! -n "${_PASSPHRASE_ATTEMPT2}" ) ]] || (( ${#_PASSPHRASE_ATTEMPT2} < $__KEY_MINSIZE )) && NEXT=
    fi

    if (( $NEXT )); then
        [[ ${_PASSPHRASE_ATTEMPT2} == ${_PASSPHRASE_ATTEMPT1} ]] || NEXT=
    fi

    if (( $NEXT )); then
        _PASSPHRASE_ATTEMPT1=
        PASSPHRASE=${_PASSPHRASE_ATTEMPT2}
        _PASSPHRASE_ATTEMPT2=
    else
        _PASSPHRASE_ATTEMPT1=
        _PASSPHRASE_ATTEMPT2=
        print_error "Invalid passphrase!"
    fi
}

function get_passphrase()
{
    local NEXT=1
    declare -n PASSPHRASE=$1

    echo -n "> Enter passphrase: "
    read_secret _PASSPHRASE
    
    [[ ( ! -n "${_PASSPHRASE}" ) ]] || (( ${#_PASSPHRASE} < $__KEY_MINSIZE )) && NEXT=

    if (( $NEXT )); then
        PASSPHRASE=${_PASSPHRASE}
    else
        print_error "Invalid passphrase!"
    fi
}

function print_passphrase_requirements()
{
    echo "Passphrase should has at least $__KEY_MINSIZE symbols length and"
    echo "doesn't start/end with spaces (it will be trimmed)"
}

function __open_master_key()
{
    if [ -z $SH_TOOLS_MASTER_KEY_PATH ]; then
        print_error "Uninitialized environment!"
        exit $__LIB_CRYPT_ERROR
    fi

    local CLI_PASSPHRASE="${1}"
    if [ $CLI_PASSPHRASE == $__KEY_DUMP ]; then
        CLI_PASSPHRASE=
    fi

    shift
    declare -n DECRYPTED_RESULT=$1
    local DONOT_SHOW_PROMPT=$2

    local NEXT=1

    local KEY_PATH=${SH_TOOLS_MASTER_KEY_PATH}.$__ENCRYPTED_EXT_SYMBOL
    if [ ! -f "${KEY_PATH}" ]; then
        __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid key file!"
        NEXT=
    fi

    if (( $NEXT )); then
        if [ -z ${CLI_PASSPHRASE} ]; then        
            if [ -z $DONOT_SHOW_PROMPT ]; then
                echo -n "$(emoji $EMOJI_ID_16_GOLD_KEY) Enter passphrase for MASTER Key: "
            fi
            read_secret_n KEY_PASSPHRASE

            if [ ! -n "${KEY_PASSPHRASE}" ]; then
                __print_error_check_silency "($(basename ${BASH_SOURCE}):${LINENO}) Invalid passphrase!"
                NEXT=    
            fi
        else
            local KEY_PASSPHRASE=${CLI_PASSPHRASE}
        fi
    fi

    if (( $NEXT )); then
        __decrypt_master_key_with_passphrase "${KEY_PASSPHRASE}" DECRYPTED_RESULT_
        DECRYPTED_RESULT=${DECRYPTED_RESULT_}
        DECRYPTED_RESULT_=
        if [ -n "${DECRYPTED_RESULT}" ]; then
            echo OK
        fi
    fi
}

function create_master_key()
{
    if [ -z $SH_TOOLS_MASTER_KEY_PATH ]; then
        print_error "Uninitialized environment!"
        exit $__LIB_CRYPT_ERROR
    fi
        
    local CLI_PASSPHRASE=${1}
    if [ -n "${CLI_PASSPHRASE}" ]; then
        if [ "${CLI_PASSPHRASE}" == $__KEY_DUMP ]; then
            CLI_PASSPHRASE=
        fi
    fi

    local KEY_PATH=${SH_TOOLS_MASTER_KEY_PATH}
    local NEXT=1

    if [ -f ${KEY_PATH}.$__ENCRYPTED_EXT_SYMBOL ]; then
        print_error "Master key already exists!"
        NEXT=
    fi

    if [ $# -ge 2 ]; then
        declare -n DECRYPTED_RESULT=$2
    fi

    if (( $NEXT )); then

        __echo_check_silency "*****************************************************"
        __echo_check_silency "MASTER KEY CREATION"
        __echo_check_silency "*****************************************************"

        create_secret_file ${KEY_PATH} __CHECK_RESULT

        if [ -z ${CLI_PASSPHRASE} ]; then

            create_passphrase _PASSPHRASE

            if [ ! -n "${_PASSPHRASE}" ]; then
                NEXT=
            fi

            if (( $NEXT )); then
                __encrypt_file_with_passphrase ${KEY_PATH} "${_PASSPHRASE}"
                _PASSPHRASE=

                echo -n "> Test for master key: "

                __open_master_key $__KEY_DUMP __DECRYPTED_RESULT 1
                if [ -n "${__DECRYPTED_RESULT}" ]; then

                    [ ${__CHECK_RESULT} == ${__DECRYPTED_RESULT} ] || NEXT=
                    __DECRYPTED_RESULT=
                else
                    NEXT=
                fi
            fi
        else
            __encrypt_file_with_passphrase ${KEY_PATH} "${CLI_PASSPHRASE}"
            CLI_PASSPHRASE=
        fi

        if [ $# -ge 2 ]; then
            DECRYPTED_RESULT=${__CHECK_RESULT}
        fi
        __CHECK_RESULT=

        if (( $NEXT )); then
            __echo_check_silency "*****************************************************"
            __echo_check_silency "SUCCESSFULLY CREATED"
            __echo_check_silency "*****************************************************"
        else
            rm -rf ${KEY_PATH}
            rm -rf ${KEY_PATH}.$__ENCRYPTED_EXT_SYMBOL
            print_error "\n"
            print_error "Failed to create master key!"
        fi
    fi
}

function obtain_master_key()
{
    if [ -z $SH_TOOLS_MASTER_KEY_PATH ]; then
        print_error "Uninitialized environment!"
        exit $__LIB_CRYPT_ERROR
    fi
        
    declare -n DECRYPTED_RESULT=$1
    local CLI_PASSPHRASE=${2}

    local KEY_PATH=${SH_TOOLS_MASTER_KEY_PATH}.$__ENCRYPTED_EXT_SYMBOL

    if [ -z ${CLI_PASSPHRASE} ]; then
        CLI_PASSPHRASE=$__KEY_DUMP
    fi

    if [ -f ${KEY_PATH} ]; then
        __open_master_key "${CLI_PASSPHRASE}" __DECRYPTED_RESULT
    else
        create_master_key "${CLI_PASSPHRASE}" __DECRYPTED_RESULT
    fi
    DECRYPTED_RESULT=$__DECRYPTED_RESULT
    __DECRYPTED_RESULT=
}