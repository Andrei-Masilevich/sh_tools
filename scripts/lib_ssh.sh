#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_crypt.sh

__SSH_CONFIG_CMD_SHOW='S'
__SSH_CONFIG_CMD_EDIT='E'

function show_ssh_args_help()
{
    echo " {connection str}                                                      "
    echo "      Alias from encrypted config file.                                "
    echo " --show|-s                                                             "
    echo "      Show decrypted config file content instead of SSH launching.     "
    echo " --edit|-e                                                             "
    echo "      Edit decrypted config file content.                              "
    echo
}

function __get_arg_command()
{
    local ARG_CMD=$1
    if [ -z $ARG_CMD ]; then
        return 1
    fi
    case "$ARG_CMD" in
    '--show'|'-s')   
        ARG_CMD=${__SSH_CONFIG_CMD_SHOW}
        ;;
    '--edit'|'-e') 
        ARG_CMD=${__SSH_CONFIG_CMD_EDIT}
        ;;
    *)    
        if [ ${ARG_CMD:0:1} == '-' ]; then
            return 1
        fi     
        ;;
    esac
 
    echo $ARG_CMD
}

function __edit_config()
{
    set +o functrace

    local PATH_TO_CONFIG_=$1
    if [ -n "$(which vim)" ]; then
        vim ${PATH_TO_CONFIG_}
    elif [ -n "$(which vi)" ]; then
        vi ${PATH_TO_CONFIG_}
    elif [ -n "$(which nano)" ]; then
        nano ${PATH_TO_CONFIG_}
    else
        print_error "Can't find any CLI editor!"
        exit 1
    fi
}

function init_ssh()
{
    set +o functrace

    local ARG_CMD=$(__get_arg_command $1)
    if [ -z $ARG_CMD ]; then
        print_error "Invalid command!"
        exit 1
    fi

    shift

    declare -n __PATH_TO_CONFIG=$1
    declare -n __CRYPTED_PATH_TO_CONFIG=$2

    init_crypt

    __PATH_TO_CONFIG=${SH_TOOLS_DATA_DIR_PATH}/ssh/config

    __CRYPTED_PATH_TO_CONFIG=$(crypted_name ${PATH_TO_CONFIG})

    if [[ ! -f ${__CRYPTED_PATH_TO_CONFIG} && ! -f ${__PATH_TO_CONFIG} ]]; then
        if [ "$ARG_CMD" == $__SSH_CONFIG_CMD_EDIT ]; then
            __edit_config "${__PATH_TO_CONFIG}"
        elif [ "$ARG_CMD" != $__SSH_CONFIG_CMD_SHOW ]; then
            WARNING_MSG="There is no protected SSH-client config file. 
    Do you what to create protected one?"
            answer_no "$(emoji $EMOJI_ID_16_DANGEROUS) ${WARNING_MSG}" __YES_RESULT "[y (create file)/N]"
            if (( $__YES_RESULT )); then
                __edit_config "${__PATH_TO_CONFIG}"
            else
                exit 2
            fi
        fi
    fi

    if [[ ! -f ${__CRYPTED_PATH_TO_CONFIG} && ! -f ${__PATH_TO_CONFIG} ]]; then
        print_error "There is no protected SSH-client config file to continue"
        exit 1
    fi
}

function extract_session_config()
{
    set +o functrace

    if [ $# -le 2 ]; then
        print_error "Invalid command!"
        exit 1    
    fi

    local PATH_TO_CONFIG=$1
    declare -n __PATH_TO_SESSION_CONFIG=$2
    shift; shift
    local CONNECTION_STR=$1

    local PATH_TO_CONFIG_TMP=
    local LN_=
    local START_SESSION_CONFIG=
    while read -r LN_; do
        if [[  -z $PATH_TO_CONFIG_TMP && "${LN_}" =~ ^Host[[:space:]]+${CONNECTION_STR}$ ]]; then
            START_SESSION_CONFIG=1
            PATH_TO_CONFIG_TMP="/tmp/.$(random_str).XXXXXX"
            PATH_TO_CONFIG_TMP=$(mktemp $PATH_TO_CONFIG_TMP)
            trap "rm -f  ${PATH_TO_CONFIG_TMP}" EXIT
            echo "${LN_}" > $PATH_TO_CONFIG_TMP
        elif (( $START_SESSION_CONFIG )); then
            if [[  "${LN_}" =~ ^Host[[:space:]]+.+$ ]]; then
                break
            elif [[ -n "${LN_}" && ${LN_:0:1} != '#' ]]; then
                echo "${LN_}" >> $PATH_TO_CONFIG_TMP
            fi
        fi
    done <$PATH_TO_CONFIG

    if [ -n "$PATH_TO_CONFIG_TMP" ]; then
        __PATH_TO_SESSION_CONFIG=$PATH_TO_CONFIG_TMP
    else
        print_error "Connection string is not found in encrypted config!"
        exit 1      
    fi
}

function obtain_session_config()
{
    set +o functrace

    local ARG_CMD=$(__get_arg_command $1)
    if [ -z $ARG_CMD ]; then
        print_error "Invalid command!"
        exit 1
    fi

    shift

    local PATH_TO_CONFIG=$1
    local CRYPTED_PATH_TO_CONFIG=$2

    shift; shift
    
    if [[ -z $PATH_TO_CONFIG || -z $CRYPTED_PATH_TO_CONFIG ]]; then
        print_error "Invalid config path!"
        exit 1
    fi

    declare -n __PATH_TO_SESSION_CONFIG=$1

    shift

    obtain_master_key __MASTER_PASSPHRASE
    if [ -z ${__MASTER_PASSPHRASE} ]; then
        print_error "Failed to apply master key!"
        exit 1
    fi

    if [ ! -f ${CRYPTED_PATH_TO_CONFIG} ]; then
        encrypt_file ${PATH_TO_CONFIG} ${__MASTER_PASSPHRASE}
    fi

    if [ ! -f ${CRYPTED_PATH_TO_CONFIG} ]; then
        __MASTER_PASSPHRASE=
        print_error "Failed to encript SSH configuration!"
        exit 1
    fi

    decrypt_file ${CRYPTED_PATH_TO_CONFIG} ${__MASTER_PASSPHRASE}
    trap "encrypt_file ${PATH_TO_CONFIG} ${__MASTER_PASSPHRASE}" EXIT

    if [ "$ARG_CMD" == $__SSH_CONFIG_CMD_SHOW ]; then
        __MASTER_PASSPHRASE=
        echo
        cat ${PATH_TO_CONFIG}
    elif [ "$ARG_CMD" == $__SSH_CONFIG_CMD_EDIT ]; then
        __MASTER_PASSPHRASE=
        __edit_config "${PATH_TO_CONFIG}"
    else
        set -o functrace

        extract_session_config ${PATH_TO_CONFIG} PATH_TO_SESSION_CONFIG_ "${ARG_CMD}"
        encrypt_file ${PATH_TO_CONFIG} ${__MASTER_PASSPHRASE}
        __MASTER_PASSPHRASE=
        __PATH_TO_SESSION_CONFIG=${PATH_TO_SESSION_CONFIG_}
        echo
    fi
}

# Protection from recursive entering by alias
function get_ssh()
{
    set +o functrace

    echo $(which ssh)
}

# Protection from recursive entering by alias
function get_scp()
{
    set +o functrace

    echo $(which scp)
}
