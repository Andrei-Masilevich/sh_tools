#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_realpath.sh
set -o functrace

get_realpath $@
