#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_crypt.sh
set -o functrace

__KEYS_FOLDER=ssh/keys
__ALL_KEYS_PATTERN='--0--'
__SHADOWED_MASTER_PASSPHRASE=
__RND_FOR_SHADOW=
__PEM_EXT='pem'
__CLI_RELOAD_REQUIRED=

__show_help()
{
   echo "Usage" $(basename $0) "(options) [key pattern]"
   echo "_______________________________________________________________________"
   echo "Manage SSH private keys stored in database folder                      "
   echo "in encrypted manner for both files and file names.                     "
   echo "Use key pattern for particular keys (ex. aws, dig, git, etc.)          "
   echo "or '-A' for all evalable keys.                                         "
   echo "_______________________________________________________________________"
   echo " -x       Encrypt keys                                                 "
   echo " -X       Decrypt keys                                                 "
   echo " -l       Show decrypted key names                                     "
   echo " -r       Remove key from SSH-Agent registry                           "
   echo " -R       Remove key from disk                                         "
   echo " -A       Affect all evalable keys                                     "
   echo " -t [life]                                                             "
   echo "          Set a maximum lifetime when adding identities to an agent.   "
   echo "          The lifetime may be specified in seconds                     "
   echo " -d [dir path]                                                         "
   echo "          Path to key database directory                               "
   echo "          Default: ${SH_TOOLS_DATA_DIR_PATH}/$__KEYS_FOLDER            "
   echo
}

__create_key()
{
    read RND_FOR_SHADOW _ < <(dd if=/dev/urandom count=1 bs=32 2>/dev/null|xxd -c 32 -p -)
    echo $RND_FOR_SHADOW
    unset RND_FOR_SHADOW
}

__shadow_secret()
{
    if [ -z $__RND_FOR_SHADOW ]; then
        __RND_FOR_SHADOW=$(__create_key)
    fi
    local KEY=${__RND_FOR_SHADOW}
    local SECRET=$1
    local ENCRYPT=$2
    local I_KEY=0
    local SHADOW=

    if [ -z $ENCRYPT ]; then
        SECRET=$(echo -n ${SECRET}|rev)
    fi
    for (( I_DATA=0; I_DATA<${#SECRET}; I_DATA++ )); do
        local DATA_C=${SECRET:$I_DATA:1}
        if (( $ENCRYPT )); then
            local KEY_C=${KEY:$I_KEY:1}

            SHADOW=${SHADOW}${DATA_C}${KEY_C}

            I_KEY=$((I_KEY + 1))
            (( $I_KEY == ${#KEY} )) && I_KEY=0
        elif (( I_DATA/2*2 == I_DATA )); then
            SHADOW=${SHADOW}${DATA_C}
        fi
    done
    
    if (( $ENCRYPT )); then
        echo -n ${SHADOW}|rev
    else
        echo ${SHADOW}
    fi
}

__obtain_master_key()
{
    declare -n SECRET_PASSPHRASE=$1
    if [ -n "${__SHADOWED_MASTER_PASSPHRASE}" ]; then
        local SHADOW=$(__shadow_secret ${__SHADOWED_MASTER_PASSPHRASE})
        SECRET_PASSPHRASE=${SHADOW}
    else
        obtain_master_key __MASTER_PASSPHRASE_
        if [ -n "${__MASTER_PASSPHRASE_}" ]; then
            SECRET_PASSPHRASE=${__MASTER_PASSPHRASE_}
            local SHADOW=$(__shadow_secret ${__MASTER_PASSPHRASE_} 1)
            __MASTER_PASSPHRASE_=
            __SHADOWED_MASTER_PASSPHRASE=${SHADOW}
        fi
    fi
}

__exit_bad_passphrase()
{
    print_error_ "______________________________________________"
    print_error_ "$(emoji $EMOJI_ID_16_STOP) Bad passphrase"
    print_error_ "______________________________________________"
    exit 1
}

__encrypt_key()
{
    set +o functrace

    local KEY_FILE=$1
    local KEY_PATTERN=$2
    declare -n KEY_INFO=$3

    local FILE_ENCRYPTED=
    local KEY_FILE_NAME=$(basename ${KEY_FILE})

    if [[ ${KEY_PATTERN} == $__ALL_KEYS_PATTERN || ${KEY_FILE_NAME} =~ ^${KEY_PATTERN}.* ]]; then
        check_file_totally_encrypted ${KEY_FILE} __ENCRYPTED_NAME
        FILE_ENCRYPTED=$__ENCRYPTED_NAME
        __ENCRYPTED_NAME=
        if [[ -z $FILE_ENCRYPTED && ${KEY_FILE: -$((${#__PEM_EXT}+1))} == '.'$__PEM_EXT ]]; then
            __obtain_master_key __MASTER_PASSPHRASE
            if [ -z ${__MASTER_PASSPHRASE} ]; then
                __exit_bad_passphrase
            fi
            encrypt_file ${KEY_FILE} ${__MASTER_PASSPHRASE}
            encrypt_name $(crypted_name ${KEY_FILE}) ${__MASTER_PASSPHRASE}
            __MASTER_PASSPHRASE=
            KEY_INFO="$(emoji $EMOJI_ID_16_LOCK_CLOSED) $(basename ${KEY_FILE}) - encrypted $(emoji $EMOJI_ID_16_OK)"
        fi
    fi
}

__decrypt_key()
{
    set +o functrace

    local KEY_FILE=$1
    local KEY_PATTERN=$2
    declare -n KEY_INFO=$3

    local FILE_ENCRYPTED=
    local KEY_FILE_NAME=$(basename ${KEY_FILE})

    check_file_totally_encrypted ${KEY_FILE} __ENCRYPTED_NAME
    FILE_ENCRYPTED=$__ENCRYPTED_NAME
    __ENCRYPTED_NAME=
    if [ -n "$FILE_ENCRYPTED" ]; then

        __obtain_master_key __MASTER_PASSPHRASE
        if [ -z ${__MASTER_PASSPHRASE} ]; then
            __exit_bad_passphrase
        fi
        decrypt_data_with_passphrase ${FILE_ENCRYPTED} "${__MASTER_PASSPHRASE}" __DECRYPTED_RESULT
        KEY_FILE_NAME=${__DECRYPTED_RESULT}
        __DECRYPTED_RESULT=

        if [[ ${KEY_PATTERN} == $__ALL_KEYS_PATTERN || ${KEY_FILE_NAME} =~ ^${KEY_PATTERN}.* ]]; then
            if [ ${KEY_FILE_NAME: -$((${#__PEM_EXT}+1))} == '.'$__PEM_EXT ]; then
                local KEY_FILE_DIR=$(dirname ${KEY_FILE})
                decrypt_name ${KEY_FILE} ${__MASTER_PASSPHRASE}
                KEY_FILE=$(crypted_name ${KEY_FILE_DIR}/${KEY_FILE_NAME})
                decrypt_file ${KEY_FILE} ${__MASTER_PASSPHRASE}
                KEY_INFO="$(emoji $EMOJI_ID_16_LOCK_OPENED) ${KEY_FILE_NAME} - decrypted"
            fi
        fi
        __MASTER_PASSPHRASE=
    fi
}

__show_key()
{
    set +o functrace

    local KEY_FILE=$1
    local KEY_PATTERN=$2
    declare -n KEY_INFO=$3

    local KEY_FILE_NAME=
    local FILE_ENCRYPTED=

    check_file_totally_encrypted ${KEY_FILE} __ENCRYPTED_NAME
    FILE_ENCRYPTED=$__ENCRYPTED_NAME
    __ENCRYPTED_NAME=
    if [ -n "$FILE_ENCRYPTED" ]; then
        __obtain_master_key __MASTER_PASSPHRASE
        if [ -z ${__MASTER_PASSPHRASE} ]; then
            __exit_bad_passphrase
        fi
        decrypt_data_with_passphrase ${FILE_ENCRYPTED} "${__MASTER_PASSPHRASE}" __DECRYPTED_RESULT
        __MASTER_PASSPHRASE=
        KEY_FILE_NAME=${__DECRYPTED_RESULT}
        __DECRYPTED_RESULT=
    else
        KEY_FILE_NAME=$(basename ${KEY_FILE})
    fi

    if [ -n "${KEY_FILE_NAME}" ]; then
        if [[ ${KEY_PATTERN} == $__ALL_KEYS_PATTERN || ${KEY_FILE_NAME} =~ ^${KEY_PATTERN}.* ]]; then
            if [ ${KEY_FILE_NAME: -$((${#__PEM_EXT}+1))} == '.'$__PEM_EXT ]; then
                if [ -n "$FILE_ENCRYPTED" ]; then
                    KEY_INFO="$(emoji $EMOJI_ID_16_LOCK_CLOSED) ${KEY_FILE_NAME} - encrypted $(emoji $EMOJI_ID_16_OK)"
                else
                    KEY_INFO="$(emoji $EMOJI_ID_16_LOCK_OPENED) ${KEY_FILE_NAME} - !OPEN!"
                fi
            fi
        fi
    fi
}

__remove_key()
{
    set +o functrace

    local KEY_FILE=$1
    local KEY_PATTERN=$2
    local REMOVE_MODE=$3
    declare -n KEY_INFO=$4

    local KEY_FILE_NAME=
    local FILE_ENCRYPTED=
    local MASTER_PASSPHRASE_

    check_file_totally_encrypted ${KEY_FILE} __ENCRYPTED_NAME
    FILE_ENCRYPTED=$__ENCRYPTED_NAME
    __ENCRYPTED_NAME=
    if [ -n "$FILE_ENCRYPTED" ]; then
        __obtain_master_key __MASTER_PASSPHRASE
        if [ -z ${__MASTER_PASSPHRASE} ]; then
            __exit_bad_passphrase
        fi
        decrypt_data_with_passphrase ${FILE_ENCRYPTED} "${__MASTER_PASSPHRASE}" __DECRYPTED_RESULT
        MASTER_PASSPHRASE_=${__MASTER_PASSPHRASE}
        __MASTER_PASSPHRASE=
        KEY_FILE_NAME=${__DECRYPTED_RESULT}
        __DECRYPTED_RESULT=
    else
        KEY_FILE_NAME=$(basename ${KEY_FILE})
    fi

    local SSH_RESULT=
    if [ -n "${KEY_FILE_NAME}" ]; then
        if [[ ${KEY_PATTERN} == $__ALL_KEYS_PATTERN || ${KEY_FILE_NAME} =~ ^${KEY_PATTERN}.* ]]; then
            if [ ${KEY_FILE_NAME: -$((${#__PEM_EXT}+1))} == '.'$__PEM_EXT ]; then
                if [ -n "$FILE_ENCRYPTED" ]; then
                    decrypt_file ${KEY_FILE} ${MASTER_PASSPHRASE_}
                    KEY_FILE=$(dirname ${KEY_FILE})/${FILE_ENCRYPTED}
                    if [ -f ${KEY_FILE} ]; then
                        trap "encrypt_file ${KEY_FILE} ${MASTER_PASSPHRASE_}" EXIT
                        __ssh_remove_key ${KEY_FILE} ${KEY_FILE_NAME} __SSH_RESULT
                        SSH_RESULT=$__SSH_RESULT
                        __SSH_RESULT=
                    else
                        KEY_FILE=$(crypted_name ${KEY_FILE})
                    fi
                else
                    __ssh_remove_key ${KEY_FILE} ${KEY_FILE_NAME} __SSH_RESULT
                    SSH_RESULT=$__SSH_RESULT
                    __SSH_RESULT=
                fi
                if (( $REMOVE_MODE > 222 )); then
                    if (( $SSH_RESULT )); then
                        cleanup_secret_file ${KEY_FILE}
                        trap "" EXIT
                        KEY_INFO="$(emoji $EMOJI_ID_16_DEATH) ${KEY_FILE_NAME} - !TOTALLY REMOVED!"
                    fi
                else
                    local IS_DECRYPTED=
                    prob_encrypted_file_name ${KEY_FILE} DATA_TO_DECRYPT_ DATA_REST_
                    if [ -z ${DATA_TO_DECRYPT_} ]; then
                        IS_DECRYPTED=1
                    fi
                    if (( $IS_DECRYPTED )); then
                        if (( $SSH_RESULT )); then
                            if [ -n "$FILE_ENCRYPTED" ]; then
                                encrypt_file ${KEY_FILE} ${MASTER_PASSPHRASE_}
                                trap "" EXIT
                            fi
                            KEY_INFO="$(emoji $EMOJI_ID_16_FORBIDDEN) ${KEY_FILE_NAME} - removed"
                        fi
                    fi
                fi
            fi
        fi
    fi
}

__activate_key()
{
    set +o functrace

    local KEY_FILE=$1
    local KEY_PATTERN=$2
    local SSH_ADD_KEY_LIFETIME=$3
    declare -n KEY_INFO=$4

    local KEY_FILE_NAME=
    local FILE_ENCRYPTED=
    local MASTER_PASSPHRASE_

    check_file_totally_encrypted ${KEY_FILE} __ENCRYPTED_NAME
    FILE_ENCRYPTED=$__ENCRYPTED_NAME
    __ENCRYPTED_NAME=
    if [ -n "$FILE_ENCRYPTED" ]; then
        __obtain_master_key __MASTER_PASSPHRASE
        if [ -z ${__MASTER_PASSPHRASE} ]; then
            __exit_bad_passphrase
        fi
        decrypt_data_with_passphrase ${FILE_ENCRYPTED} "${__MASTER_PASSPHRASE}" __DECRYPTED_RESULT
        MASTER_PASSPHRASE_=${__MASTER_PASSPHRASE}
        __MASTER_PASSPHRASE=
        KEY_FILE_NAME=${__DECRYPTED_RESULT}
        __DECRYPTED_RESULT=
    else
        KEY_FILE_NAME=$(basename ${KEY_FILE})
    fi

    local SSH_RESULT=
    if [ -n "${KEY_FILE_NAME}" ]; then
        if [[ ${KEY_PATTERN} == $__ALL_KEYS_PATTERN || ${KEY_FILE_NAME} =~ ^${KEY_PATTERN}.* ]]; then
            if [ ${KEY_FILE_NAME: -$((${#__PEM_EXT}+1))} == '.'$__PEM_EXT ]; then
                if [ -n "$FILE_ENCRYPTED" ]; then
                    decrypt_file ${KEY_FILE} ${MASTER_PASSPHRASE_}
                    KEY_FILE=$(dirname ${KEY_FILE})/${FILE_ENCRYPTED}
                    if [ -f ${KEY_FILE} ]; then
                        trap "encrypt_file ${KEY_FILE} ${MASTER_PASSPHRASE_}" EXIT
                        __ssh_add_key ${KEY_FILE} ${KEY_FILE_NAME} $SSH_ADD_KEY_LIFETIME __SSH_RESULT
                        SSH_RESULT=$__SSH_RESULT
                        __SSH_RESULT=
                        encrypt_file ${KEY_FILE} ${MASTER_PASSPHRASE_}
                        trap "" EXIT
                        if (( $SSH_RESULT )); then
                            KEY_INFO="$(emoji $EMOJI_ID_16_ALLOW_WALKING) ${KEY_FILE_NAME} - added"
                        fi
                    fi
                else
                    __ssh_add_key ${KEY_FILE} ${KEY_FILE_NAME} $SSH_ADD_KEY_LIFETIME __SSH_RESULT
                    SSH_RESULT=$__SSH_RESULT
                    __SSH_RESULT=
                    if (( $SSH_RESULT )); then
                        KEY_INFO="$(emoji $EMOJI_ID_16_ALLOW_WALKING) ${KEY_FILE_NAME} - added"
                    fi
                fi
            fi
        fi
    fi
}

__obtain_ssh_agent()
{
    local SSH_AGENT_FOUND=
    if [ -n "$SSH_AGENT_PID" ]; then
        local SSH_AGENT_PID_=$(pidof ssh-agent)
        if [ -n "$SSH_AGENT_PID_" ]; then
            read -a SSH_AGENT_PIDS_ <<< $SSH_AGENT_PID_
            SSH_AGENT_PID_=
            for SSH_AGENT_PID_ in "${SSH_AGENT_PIDS_[@]}"; do 
                if [ $SSH_AGENT_PID_ == $SSH_AGENT_PID ]; then
                    SSH_AGENT_FOUND=1
                    break
                fi
            done
        fi
    fi
    if [ -z $SSH_AGENT_FOUND ]; then
        rm -f $HOME/.ssh/ssh-agent.env
        __run_ssh_agent
    fi
}

__run_ssh_agent()
{
    ssh-agent > $HOME/.ssh/ssh-agent.env
    sed -i 's/echo/#echo/g' $HOME/.ssh/ssh-agent.env
    . $HOME/.ssh/ssh-agent.env
    __CLI_RELOAD_REQUIRED=1
}

__ssh_add_key()
{
    local DECRYPTED_KEY_FILE=$1
    local DECRYPTED_KEY_NAME=$2
    local SSH_ADD_KEY_LIFETIME=$3
    declare -n SSH_RESULT=$4
    local DIR=$(dirname ${DECRYPTED_KEY_FILE})

    __obtain_ssh_agent

    pushd ${DIR} > /dev/null
    echo "${DECRYPTED_KEY_NAME} - SSH key loading $(emoji $EMOJI_ID_8_OLD_KEY)"
    echo "__________________________________________________________________"
    echo -n "$(emoji $EMOJI_ID_16_LOCK_WITH_KEY) "
    local TIME_OPT=
    if (( $SSH_ADD_KEY_LIFETIME > 0 )); then
        TIME_OPT=" -t $SSH_ADD_KEY_LIFETIME "
    fi
    ssh-add $TIME_OPT $(basename ${DECRYPTED_KEY_FILE}) 2>/dev/null
    [ $? -eq 0 ] && SSH_RESULT=1

    echo
    popd > /dev/null
}

__ssh_remove_key()
{
    __obtain_ssh_agent

    local DECRYPTED_KEY_FILE=$1
    local DECRYPTED_KEY_NAME=$2
    declare -n SSH_RESULT=$3
    local DIR=$(dirname ${DECRYPTED_KEY_FILE})

    pushd ${DIR} > /dev/null    
    echo "${DECRYPTED_KEY_NAME} - SSH key unloading $(emoji $EMOJI_ID_8_OLD_KEY)"
    echo "__________________________________________________________________"
    echo -n "$(emoji $EMOJI_ID_16_LOCK_WITH_KEY) "
    local PUB=$(ssh-keygen -y -f ${DECRYPTED_KEY_FILE} 2>/dev/null)
    [ -n "$PUB" ] && SSH_RESULT=1
    
    echo -n $PUB|ssh-add -d - 2>/dev/null
    echo
    popd > /dev/null
}

main()
{
    set +o functrace
    init_crypt
    
    local OPT_ENCRYPT_KEYS=
    local OPT_DECRYPT_KEYS=
    local OPT_SHOW_DECRYPTED_KEY_NAMES=
    local OPT_ALL_KEYS=
    local OPT_REMOVE=0
    local OPT_SSH_ADD_KEY_LIFETIME=0
    local KEYS_DATABASE=${SH_TOOLS_DATA_DIR_PATH}/$__KEYS_FOLDER
    while getopts ":xXlAd:rRt:h" OPTION
    do
    case $OPTION in
        x)
        OPT_ENCRYPT_KEYS=1
        ;;
        X)
        OPT_DECRYPT_KEYS=1
        ;;
        l)
        OPT_SHOW_DECRYPTED_KEY_NAMES=1
        ;;
        A)
        OPT_ALL_KEYS=1
        ;;
        r)
        OPT_REMOVE=1
        ;;
        R)
        OPT_REMOVE=999
        ;;
        t)
        OPT_SSH_ADD_KEY_LIFETIME=$OPTARG
        ;;
        d)
        KEYS_DATABASE=$OPTARG
        ;;

        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    shift "$(($OPTIND -1))"

    local KEY_PATTERN=${1}
    if [[ -z $OPT_ALL_KEYS && -z $KEY_PATTERN ]]; then
        __show_help
        exit 0
    fi

    if [ ! -d ${KEYS_DATABASE} ]; then
        print_error "Keys database required!"
        exit 1
    fi

    if [[ ! $OPT_SSH_ADD_KEY_LIFETIME =~ ^[0-9]+$ ]]; then
        print_error "Invalid time format!"
        exit 1
    fi

    if (( $OPT_ALL_KEYS )); then
        KEY_PATTERN=$__ALL_KEYS_PATTERN
    fi

    local KEY_INFOS=()
    for f in ${KEYS_DATABASE}/*; do
        set -o functrace
        if [ -f $f ]; then
            if (( $OPT_REMOVE < 1 )); then
                if (( $OPT_ENCRYPT_KEYS )); then
                    __encrypt_key $f ${KEY_PATTERN} KEY_INFO__
                elif (( $OPT_DECRYPT_KEYS )); then
                    __decrypt_key $f ${KEY_PATTERN} KEY_INFO__
                elif (( $OPT_SHOW_DECRYPTED_KEY_NAMES )); then
                    __show_key $f ${KEY_PATTERN} KEY_INFO__
                else
                    __activate_key $f ${KEY_PATTERN} $OPT_SSH_ADD_KEY_LIFETIME KEY_INFO__
                fi
            else
                __remove_key $f ${KEY_PATTERN} $OPT_REMOVE KEY_INFO__
            fi
            if [ -n "$KEY_INFO__" ]; then
                KEY_INFOS+=("$KEY_INFO__")
                KEY_INFO__=
            fi
        fi
    done 
    set +o functrace

    for KEY_INFO in "${KEY_INFOS[@]}"; do
        echo "========================================"
        echo ${KEY_INFO}
    done
    
    if (( $__CLI_RELOAD_REQUIRED )); then
        restart_this_terminal
    fi
}

main $@
