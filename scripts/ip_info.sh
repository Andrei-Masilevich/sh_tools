#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh

# https://ipinfo.io/developers

main()
{
    if [ -z $1 ]; then
        curl -H "Accept: application/json" ipinfo.io
    else
        curl -H "Accept: application/json" ipinfo.io/$1
    fi
    if [ $? -eq 0 ]; then echo; fi
}

main $@
