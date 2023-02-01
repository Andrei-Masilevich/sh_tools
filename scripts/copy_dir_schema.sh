#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh
source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_realpath.sh
set -o functrace

__show_help()
{
   echo "Usage" $(basename $0) "(source dir) (target dir)"
   echo "________________________________________________"
   echo "Copy directory tree from source to target       "
   echo "without files (directories only)                "
   echo
}

main()
{
    set +o functrace
    while getopts ":h" OPTION
    do
    case $OPTION in

        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    shift "$(($OPTIND -1))"

    if [ $# -le 1 ]; then
        __show_help
        exit 0
    fi

    local SOURCE_DIR=$1 
    if [[ -n "$SOURCE_DIR" && ! -d ${SOURCE_DIR} ]]; then
        print_error "Source folder is required!"
        exit 1
    fi
    SOURCE_DIR=$(get_realpath ${SOURCE_DIR})

    local TARGET_DIR=$2
    if [[ -n "$TARGET_DIR" && ! -d ${TARGET_DIR} ]]; then
        mkdir -p ${TARGET_DIR}
        if [ $? -ne 0 ]; then
            print_error "Target folder is not accessible!"
            exit 1
        fi
    fi
    TARGET_DIR=$(get_realpath ${TARGET_DIR})

    if [ ${SOURCE_DIR} == ${TARGET_DIR} ]; then
        print_error "Can't copy into itself!"
        exit 1
    fi

    pushd ${SOURCE_DIR} >/dev/null
    find . -type d | xargs -I '{}' mkdir -p {} ${TARGET_DIR}/{}
    popd >/dev/null
}

main $@

