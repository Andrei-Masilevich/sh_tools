#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_ssh.sh
set -o functrace

function __show_help()
{
    echo "Usage" $(basename $0) "(options) [connection str] (remote command|SSH args) "
    echo "____________________________________________________________________________"
    echo "Start wrapped SSH client with encrypted configuration file.                 "
    echo "Ex.:                                                                        "
    echo
    echo -e "To open remote terminal:                                                 "
    echo -e "\t$(basename $0) my.server                                               "
    echo -e "To run remote command:                                                   "
    echo -e "\t$(basename $0) my.server uptime -p                                     " 
    echo -e "To run SOCKS proxy:                                                      "
    echo -e "\t$(basename $0) my.server -D 19999 -N                                   "  
    echo -e "To run tunnel from local 8443 server on lo:                              "
    echo -e "\t$(basename $0) my.server -R 8443:127.0.0.1:8443 -N                     "  
    echo -e "To run tunnel from remote 8443 server on lo:                             "
    echo -e "\t$(basename $0) my.server -L 127.0.0.1:8443:127.0.0.1:8443 -N           "  
    echo
    echo "With -N SSH option this script runs corresponding SSH tunnel or proxy       "
    echo "in background mode." 
    echo "____________________________________________________________________________"
    show_ssh_args_help
    echo " -p PIDFILE                                                                 "
    echo "      File to use as pid file.                                              "
    echo " --help|-h                                                                  "
    echo "      Show this help.                                                       "    
}

# Test SOCKS:
#
# [ssh.sh] my.server -D 19999 -N
#
# curl --socks5 127.0.0.1:19999 -H "Accept: application/json" ipinfo.io
#
main()
{
    if [ $# -lt 1 ]; then
        __show_help
        exit 1
    fi

    local PIDFILE=
    case "$1" in
    '-p') 
        PIDFILE=$2
        shift; shift 
        ;;
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
        local SEARCH_ARGS=("$@")
        local SSH_IN_BACKGROUND=
        for ARG in "${SEARCH_ARGS[@]}"; do
            if [ ${ARG} == '-N' ]; then
                SSH_IN_BACKGROUND=1
                break
            fi
        done
        if ((SSH_IN_BACKGROUND)); then
            local NOHUP_TMP=$(mktemp /tmp/nohup.out.XXXXXX)
            nohup $(get_ssh) -F ${PATH_TO_SESSION_CONFIG} $@ ${CONNECTION_STR} >${NOHUP_TMP} 2>&1 &
            local JOB_PID=$!
            disown
            # Let detached SSH process start before PATH_TO_SESSION_CONFIG file will be removed
            sleep 1
            echo "SSH task has been run and detached from terminal."
            if [ -n "$PIDFILE" ]; then
                echo ${JOB_PID} > $PIDFILE
                if [[ $? -ne 0 || ! -f $PIDFILE ]]; then
                    PIDFILE=
                fi
            fi
            if [[ -n "$PIDFILE" && -f $PIDFILE ]]; then
                echo "Use \"pkill -F $PIDFILE\" to stop it."
            else
                echo "Use \"kill ${JOB_PID}\" to stop it."
            fi
        else 
            clear
            log '/' '/' '/'
            $(get_ssh) -F ${PATH_TO_SESSION_CONFIG} ${CONNECTION_STR} $@
            if  [ $# -eq 0 ]; then
                clear
            fi
        fi
    fi
}

main $@
