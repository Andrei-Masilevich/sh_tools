#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh
set -o functrace

__show_help()
{
    echo "Usage" $(basename $0) "(protocol)                                          "
    echo "___________________________________________________________________________"
    echo "Show local IP addresses corresponding to the connected network interfaces. "
    echo "___________________________________________________________________________"
    echo " 4/6      Protocol IPv4/IPv6 (4 - by default)                              "
    echo
}

main()
{
    set +o functrace

    # Return IPv4 by default
    local PROTO=4
    while getopts '46h' OPTION; do
    case "$OPTION" in
        4|6)
        PROTO=$((OPTION))
        ;;
        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    if [ ! -n "$(which ip)" ]; then
        print_error "'ip' utility is required"
        exit 1
    fi

    if [ -n "$(which column)" ]; then
        ip -${PROTO} -o -c a|cut -d '/' -f 1|column -t
    else
        ip -${PROTO} -o -c a|cut -d '/' -f 1    
    fi
}

main $1
