#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_ssh.sh
set -o functrace

function __show_help()
{
    echo "Usage" $(basename $0) "(options)|[connection str] [local fs] [remote fs] "
    echo "_________________________________________________________________________"
    echo "Start wrapped SCP with encrypted configuration file.                     "
    echo "Ex.:                                                                     "
    echo -e "\t$(basename $0) my.server script.sh .local/                          "
    echo -e "\t$(basename $0) my.server script.sh /tmp/my_script.sh                "
    echo "_________________________________________________________________________"
    show_ssh_args_help
}

main()
{ 
    if [ $# -lt 1 ]; then
        __show_help
        exit 0
    fi

    init_ssh "$1" PATH_TO_CONFIG CRYPTED_PATH_TO_CONFIG

    set -o functrace
    obtain_session_config "$1" ${PATH_TO_CONFIG} ${CRYPTED_PATH_TO_CONFIG} PATH_TO_SESSION_CONFIG
    if [ -n "${PATH_TO_SESSION_CONFIG}" ]; then
        local CONNECTION_STR=$1
        shift
        if [ $# -lt 2 ]; then
            __show_help
            exit 0
        fi
        local SANITIZE_ARGS=("$@")
        for ARG in "${SANITIZE_ARGS[@]}"; do
            if [ ${ARG:0:1} == '-' ]; then
                __show_help
                exit 0
            fi
        done

        local SRC_FS=$1
        local TARGET_FS=${CONNECTION_STR}:$2
        clear
        log '/' '/' '/'
        $(get_scp) -F ${PATH_TO_SESSION_CONFIG} ${SRC_FS} ${TARGET_FS}
    fi
}

main $@