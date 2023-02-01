#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh

# NOTE: exit is not working for function that returns value
function get_realpath()
{
    if [ -n "$(which realpath)" ]; then
        local RESULT=$(realpath "$@" 2>/dev/null)
        if [ -z ${RESULT} ]; then
            print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid path \"$@\""
        fi
        echo ${RESULT}
    else
        if [ -z $1 ]; then
            print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments"
        fi

        local PYTHON=$(find_python)
        if [ -z ${PYTHON} ]; then
            print_error "($(basename ${BASH_SOURCE}):${LINENO}) Python required!"
        fi
        local f=$1;
        local base=
        local dir=
        if [ -d "$f" ]; then
            base="";
            dir="$f";
        else
            base="/$(basename "$f")"
            dir=$(dirname "$f");
        fi;
        dir=$(cd "$dir" && pwd);
        if [ $? -ne 0 ]; then
            print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid path \"$dir\""
        fi
        f="$dir$base"
cat <<% |${PYTHON}        
import os
f="${f}"
if os.path.islink(f):
    f=os.readlink(f)
    f=os.path.abspath(f)
print(f)
%
        if [ $? -ne 0 ]; then
            print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid path \"$f\""
        fi
    fi
}
