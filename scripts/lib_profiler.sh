#!/bin/bash

function cpu_check_time()
{
    if [ $# -ge 2 ]; then
        declare -n __MS_LEFT=$2
    fi
    if [ -z $__CURRENT_TIME_MARK ]; then
        __CURRENT_TIME_MARK=$(($(date +%s%N)/1000000))
    else
        local NOW=$(($(date +%s%N)/1000000))
        local DELTA_MS=$((NOW - __CURRENT_TIME_MARK))
        __CURRENT_TIME_MARK=$NOW
        if [ $# -ge 1 ]; then
            __MS_LEFT=$DELTA_MS
        fi
        local DELTA_INT=$((DELTA_MS / 1000))
        local DELTA_REST=$((DELTA_MS % 1000))
        if (( DELTA_REST < 10 )); then
            DELTA_REST=00$DELTA_REST
        elif (( DELTA_REST < 100 )); then
            DELTA_REST=0$DELTA_REST
        fi

        if [ -n "$1" ]; then
            printf '>>> [%s] %d.%s seconds left\n' "${1}" $DELTA_INT $DELTA_REST >&2
        else
            printf '>>> %d.%s seconds left\n' $DELTA_INT $DELTA_REST >&2
        fi
    fi    
}

# initialize timer
cpu_check_time

function pause()
{
    local PROMPT=$@
    if [ -z ${PROMPT} ]; then
        PROMPT="Press Any Key..."
    fi
    read -p "${PROMPT}" __    
    __=
}
