#!/bin/bash

# TODO: Language patterns!

__C_PATTERN='cpp|hpp|c|h'
__WHERE=.
if [[ -n "$1" && -d $1 ]]; then
    __WHERE=${1}
    shift
    source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_realpath.sh
    __WHERE=$(get_realpath ${__WHERE})
fi
pushd ${__WHERE} > /dev/null
find . -regextype posix-egrep -type f -regex '.+\.('$__C_PATTERN')' $@
popd > /dev/null