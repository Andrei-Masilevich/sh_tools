#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_ssh.sh
set -o functrace

__show_help()
{
    echo "Usage" $(basename $0) "(options)|[connection str] -- [SCP args]        "
    echo "_______________________________________________________________________"
    echo "Start wrapped SCP with encrypted configuration file.                   "
    echo "_______________________________________________________________________"
    echo " {connection str}                                                      "
    echo "      Alias from encrypted config file.                                "
    echo " $SSH_CONFIG_CMD_SHOW                                                  "
    echo "      Show decrypted config file content instead of SCP launching.     "
    echo " $SSH_CONFIG_CMD_EDIT                                                  "
    echo "      Edit decrypted config file content.                              "
    echo
}

if [ $# -le 3 ]; then
    __show_help
    exit 0
fi

init_ssh "$1" PATH_TO_CONFIG CRYPTED_PATH_TO_CONFIG

CONNECTION_STR_OR_CMD=$1
shift
if [ "$1" != '--' ]; then
    print_error "Invalid syntax! It requires '--' symbols before SCP args"
    exit 1
fi
shift
set -o functrace
obtain_session_config "${CONNECTION_STR_OR_CMD}" ${PATH_TO_CONFIG} ${CRYPTED_PATH_TO_CONFIG} PATH_TO_SESSION_CONFIG
if [ -n "${PATH_TO_SESSION_CONFIG}" ]; then
    $(get_scp) -F ${PATH_TO_SESSION_CONFIG} $@
    clear
fi
