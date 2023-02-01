#!/bin/bash

main()
{
    local THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)

    . ${THIS_DIR}/workstation/install.sh $@
}

main $@
