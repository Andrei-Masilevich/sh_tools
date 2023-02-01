#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh
set -o functrace

__show_help()
{
    echo "Usage" $(basename $0) "(options)"
    echo "___________________________________________________"
    echo "Create random hexadecimal string from /dev/urandom"
    echo "___________________________________________________"
    echo " -s [size]                                         "
    echo "      Set size for result in bytes                 "
    echo "      (must be in range [1, 1024])                 "
    echo "      Default: 16.                                 "
    echo " -x   Add 0x for result.                           "
    echo
}

main()
{
    set +o functrace
    local OPT_SZ=16
    local OPT_X=
    while getopts "s:xh" OPTION
    do
    case $OPTION in
        s)
        OPT_SZ=$OPTARG
        ;;
        x)
        OPT_X=1
        ;;

        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    if ((OPT_SZ < 1 || OPT_SZ > 1024)); then
        print_error "Invalid size. Size must be in range [1, 1024]."
        exit 1
    fi

    local BS=1
    if ((OPT_SZ/4*4 == OPT_SZ)); then
        BS=4
    elif ((OPT_SZ/2*2 == OPT_SZ)); then
        BS=2
    fi

    read hex _ < <(dd if=/dev/urandom count=$((OPT_SZ/BS)) bs=$BS 2>/dev/null|xxd -c $OPT_SZ -p -)

    if (( $OPT_X )); then
        echo 0x$hex
    else
        echo $hex
    fi

    unset hex
}

main $@

