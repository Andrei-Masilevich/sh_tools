#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_ssh.sh
set -o functrace

__SCP_DOWNLOAD='-'
__SSH_UPLOAD='+'


function __show_help()
{
    echo "Usage" $(basename $0) "(options)|[connection str] [${__SSH_UPLOAD}|${__SCP_DOWNLOAD}] [local fs] [remote fs]"
    echo "_________________________________________________________________________________"
    echo "Upload or download files as SCP wrapper with encrypted configuration file.       "
    echo "Upload ($__SSH_UPLOAD) by default. Ex.:                                          "
    echo
    echo "Upload script.sh to ~ folder at the my.server host                               "
    echo -e "\t$(basename $0) my.server script.sh                                          "
    echo "or                                                                               "
    echo -e "\t$(basename $0) my.server $__SSH_UPLOAD script.sh                            "
    echo
    echo "Upload script.sh to ~/.local folder at the my.server host                        "
    echo -e "\t$(basename $0) my.server script.sh .local/                                  "
    echo "or                                                                               "
    echo -e "\t$(basename $0) my.server $__SSH_UPLOAD script.sh .local/                    "
    echo
    echo "Upload script.sh to /tmp/my_script.sh file at the my.server host                 "
    echo -e "\t$(basename $0) my.server script.sh /tmp/my_script.sh                        "
    echo "or                                                                               "
    echo -e "\t$(basename $0) my.server $__SSH_UPLOAD script.sh /tmp/my_script.sh          "
    echo
    echo "Download script.sh from ~ folder of my.server host to the current folder         "
    echo -e "\t$(basename $0) my.server $__SCP_DOWNLOAD script.sh                          "
    echo
    echo "Download script.sh from ~/.local folder at the my.server host to                 "
    echo "~/Download folder at the local host                                              "
    echo -e "\t$(basename $0) my.server $__SCP_DOWNLOAD ~/Download/ .local/script.sh       "
    echo
    echo "Download script.sh from ~/.local folder at the my.server host to                 "
    echo "/tmp/my_script.sh file at the local host                                         "
    echo -e "\t$(basename $0) my.server $__SCP_DOWNLOAD /tmp/my_script.sh .local/script.sh "
    echo "_________________________________________________________________________________"
    show_ssh_args_help
    echo " --help|-h                                                                       "
    echo "      Show this help.                                                            "
}

main()
{ 
    if [ $# -lt 1 ]; then
        __show_help
        exit 1
    fi

    case "$1" in
    '--help'|'-h') 
        __show_help
        exit 0
        ;;
    *)    
        ;;
    esac

    init_ssh "$1" PATH_TO_CONFIG CRYPTED_PATH_TO_CONFIG

    set -o functrace
    obtain_session_config "$1" ${PATH_TO_CONFIG} ${CRYPTED_PATH_TO_CONFIG} PATH_TO_SESSION_CONFIG
    if [ -n "${PATH_TO_SESSION_CONFIG}" ]; then
        local CONNECTION_STR=$1
        shift
        if [ $# -lt 1 ]; then
            __show_help
            exit 1
        fi

        local CMD=$__SSH_UPLOAD
        case "$1" in
        $__SCP_DOWNLOAD) 
            CMD=$__SCP_DOWNLOAD
            shift
            ;;
        $__SSH_UPLOAD) 
            CMD=$__SSH_UPLOAD
            shift
            ;;
        *)    
            ;;
        esac

        local THS_ARG=$1
        if [ -z $THS_ARG ]; then
            __show_help
            exit 1
        fi

        local SCD_ARG=$2
        if [ -z ${SCD_ARG} ]; then
            SCD_ARG=${THS_ARG}
        fi 

        if [ $CMD == $__SSH_UPLOAD ]; then
            local SRC_FS=${THS_ARG}
            local TARGET_FS=${CONNECTION_STR}:${SCD_ARG}
        else
            local SRC_FS=${CONNECTION_STR}:${SCD_ARG}
            local TARGET_FS=${THS_ARG}
        fi
        clear
        log '/' '/' '/'
        $(get_scp) -F ${PATH_TO_SESSION_CONFIG} ${SRC_FS} ${TARGET_FS}
    fi
}

main $@