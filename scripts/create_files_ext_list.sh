#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh
set -o functrace

main()
{
    set +o functrace
    local SOURCE_DIR=$1 
    if [[ -n "$SOURCE_DIR" && ! -d $1 ]]; then
        print_error "Source folder is required!"
        exit 1
    fi

    if [ -n "${SOURCE_DIR}" ]; then
        pushd ${SOURCE_DIR} > /dev/null
    fi
    find . -type f|grep -Ev '\/\.'|rev|cut -d '.' -f 1|rev|grep -E '^[a-zA-Z]+$'|sort|uniq
    if [ -n "${SOURCE_DIR}" ]; then
        popd > /dev/null
    fi
}

main $@