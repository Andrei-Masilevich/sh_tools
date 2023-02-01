#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_ssh.sh
set -o functrace

__show_help()
{
    echo "Usage" $(basename $0) "(options)|[connection str] (--) (SSH args)      "
    echo "_______________________________________________________________________"
    echo "Start wrapped SSH client with encrypted configuration file.            "
    echo "_______________________________________________________________________"
    echo " {connection str}                                                      "
    echo "      Alias from encrypted config file.                                "
    echo " $SSH_CONFIG_CMD_SHOW                                                  "
    echo "      Show decrypted config file content instead of SSH launching.     "
    echo " $SSH_CONFIG_CMD_EDIT                                                  "
    echo "      Edit decrypted config file content.                              "
    echo
}

if [ -z $1 ]; then
    __show_help
    exit 0
fi

init_ssh "$1" PATH_TO_CONFIG CRYPTED_PATH_TO_CONFIG

set -o functrace
obtain_session_config "$1" ${PATH_TO_CONFIG} ${CRYPTED_PATH_TO_CONFIG} PATH_TO_SESSION_CONFIG
if [ -n "${PATH_TO_SESSION_CONFIG}" ]; then
    CONNECTION_STR=$1
    shift
    clear
    if [ "$1" == '--' ]; then
        shift
        $(get_ssh) -F ${PATH_TO_SESSION_CONFIG} $@
    else
        $(get_ssh) -F ${PATH_TO_SESSION_CONFIG} ${CONNECTION_STR}
    fi
    clear
fi
