#!/bin/bash

set -o functrace

__show_help()
{
   echo "Usage" $(basename $0) "(directory)                 "
   echo "___________________________________________________"
   echo "Watching the size for target directory             "
   echo "(updating in each 1 second)                        "
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

    if [[ ! -d $1 ]]; then
        if [ -z $1 ]; then
            __show_help
            exit 0
        else
            exit 1
        fi
    fi

    echo "Current size of \""$1"\":"
    local SIZE_LB=0
    while :
    do
        read __SIZE _ < <(du -h $@ 2>/dev/null | tail -1)
        read __SIZE_L _ < <(echo $__SIZE|wc -m)
        if ((SIZE_LB>0)); then
            local CLS_B=""
            for i in $(seq 1 $SIZE_LB)
            do
                CLS_B=$CLS_B"\b"
            done
            echo -en $CLS_B
        fi
        echo -n "$__SIZE "
        SIZE_LB=$((__SIZE_L))
        sleep 1
    done
}

main $@
