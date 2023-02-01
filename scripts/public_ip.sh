#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh
set -o functrace

__show_help()
{
    echo "Usage" $(basename $0) "(protocol)                                      "
    echo "_______________________________________________________________________"
    echo "Show public IP address of the current node.                            "
    echo "_______________________________________________________________________"
    echo " 4/6      Protocol IPv4/IPv6 (4 - by default)                          "
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

    if [ ! -n "$(which dig)" ]; then
        print_error "'dig' utility is required"
        exit 1
    fi

    local IP=$(dig +short -${PROTO} myip.opendns.com @resolver1.opendns.com)
    if (( $PROTO == 4 )); then
        if ((  ! $(valid_ip4 $IP) )); then
            print_error "Can't detect"
        fi
    fi 
    echo $IP
}

main $1