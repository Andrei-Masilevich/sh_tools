#!/bin/bash

function find_python3()
{
    local PYTHON=$(which python3)
    if [ -n "${PYTHON}" ]; then
        echo ${PYTHON}
    fi
}

function find_python()
{
    local PYTHON=$(find_python3)
    if [ -n "${PYTHON}" ]; then
        echo ${PYTHON}
    else
        PYTHON=$(which python)
        if [ -n "${PYTHON}" ]; then
            echo ${PYTHON}
        fi
    fi
}

function find_perl()
{
    local PERL=$(which perl)
    if [ -n "${PERL}" ]; then
        echo ${PYTHON}
    fi
}

# Requires ccencrypt (for encryption) / ccdecrypt (for decryption)
# utilities.
# ccencrypt/ccdecrypt interface should be:
#
#   -K [key string]     give keyword on command line
#   -k [keyfile]        read keyword(s) as first line(s) from file
#   -S [extension]      use suffix for encrypted file
#   -f                  overwrite existing files without asking
#   -q                  silent mode
#
function find_ccrypt()
{
    local CCRYPT=$(which ccrypt)
    if [[ -n "${CCRYPT}" && -n "$(which ccencrypt)" && -n "$(which ccdecrypt)" ]]; then
        echo ${CCRYPT}
    fi
}

function find_docker()
{
    if [ -n "$(which docker)" ]; then
        local USER_GROUPS_=($(groups))
        local IS_VALID=
        for group in "${USER_GROUPS_[@]}"; do 
            if [ "${group}" == "docker" ]; then
                IS_VALID=1
                break
            fi
        done
        if (( IS_VALID )); then
            echo "docker"
        fi
    fi
}

function find_openssl()
{
    if [ -n "$(which openssl)" ]; then
        echo "openssl"
    fi
}