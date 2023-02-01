#!/bin/bash

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/lib_common.sh
set -o functrace

if [ -z ${SH_TOOLS_DATA_DIR_PATH} ]; then
    print_error "Environment has not been set!"
    exit 1
fi

__DEFAULT_IP_LOG=${SH_TOOLS_DATA_DIR_PATH}/ip_stat.log

__show_help()
{
   echo "Usage $(basename $0) (options) [IP log]                                "
   echo "_______________________________________________________________________"
   echo "Save new public IP to log file. Default:                               "
   echo " $__DEFAULT_IP_LOG                                                     "
   echo "_______________________________________________________________________"
   echo " -l       Print all log                                                "
   echo
}

__get_public_ip()
{
    declare -n RESULT_IP=$1
    if [ -f ${THIS_DIR}/public_ip.sh ]; then
        RESULT_IP=$(. ${THIS_DIR}/public_ip.sh)
    fi
}

main()
{
    set +o functrace

    local OPT_PRINT_LOG=
    while getopts ":lh" OPTION
    do
    case $OPTION in
        l)
        OPT_PRINT_LOG=1
        ;;

        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    shift "$(($OPTIND -1))"

    local DATABASE=$1
    if [ -z "${DATABASE}" ]; then
        DATABASE=${__DEFAULT_IP_LOG}
    fi

    touch ${DATABASE}
    if [ ! -f ${DATABASE} ]; then
        print_error "Database file is required!"
        exit 1
    fi

    if (( $OPT_PRINT_LOG )); then
        cat ${DATABASE}
    fi

    __get_public_ip CURRENT_IP
    if [ -n "$CURRENT_IP" ]; then
        local LAST_IP=$(tail -n 1 ${DATABASE}|cut -d ' ' -f 2)
        if [[ -z ${LAST_IP} || ${LAST_IP} != ${CURRENT_IP} ]]; then
            echo "$(date '+%Y-%m-%d-%H:%M:%S') $CURRENT_IP" >> ${DATABASE}
            if [ ! -z ${LAST_IP} ]; then
                echo "Your public IP is changed. Was ${LAST_IP}, but now is ${CURRENT_IP}"
            fi
        fi
    else
        print_error "Can't get public IP!"
        exit 1
    fi
}

main $@