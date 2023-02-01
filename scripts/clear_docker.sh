#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh
set -o functrace

__show_help()
{
    echo "Usage                                                                          "
    echo "  "$(basename $0) "(options)                                                   "
    echo "Clear disk space from docker images. By default only for dangling ones.        "
    echo "_______________________________________________________________________________"
    echo " -a  All. Remove not only dangling images but all existent.                    "
    echo
}

main()
{
    set +o functrace

    # Public options here
    local FOR_ALL=
    while getopts 'ah' OPTION; do
    case "$OPTION" in
        a) 
        FOR_ALL=1
        ;;
        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    local DOCKER=$(find_docker)
    if [ -z ${DOCKER} ]; then
        print_error "Docker is required! There is no one or it was not properly installed."
        exit 1
    fi

    local PS_IMAGES=$(${DOCKER} ps -a -q)
    if [ -n "${PS_IMAGES}" ]; then
        ${DOCKER} stop ${PS_IMAGES}
        ${DOCKER} rm -f ${PS_IMAGES}
    fi

    if (( FOR_ALL )); then
        ${DOCKER} system prune -a -f
    else
        local CLEANUP_IMAGES=$($DOCKER images -q -f dangling=true)
        if [ -n "${CLEANUP_IMAGES}" ]; then
            $DOCKER rmi ${CLEANUP_IMAGES}
        fi
        ${DOCKER} system prune -f
    fi
}

main $@