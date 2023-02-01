#!/bin/bash

#################################################################
# DEBUGGER
#################################################################
# This script is used only in BASH_ENV=debug_env.sh context. Ex.:
#
#       BASH_ENV=debug_env.sh bash ./scripts/ip_stat.sh
#       BASH_ENV=debug_env.sh bash ./install.sh
#
trap 'echo ">> (!) ERR trap from ${FUNCNAME:-MAIN} context. $BASH_COMMAND failed with error code $?"' \
    ERR

__DEBUG_PREFIX='>>'
__DEBUG_SEPARATOR_CHAR='_'

get_screen_width()
{
    echo $(/usr/bin/tput cols)
}

print_debug_line()
{
    local PREFIX=$1
    local POSTFIX=$2
    local LIMIT_L=$(get_screen_width)
    local INPUT_L=$((LIMIT_L - ${#PREFIX} - ${#POSTFIX}))

    # echo -n "$__DEBUG_PREFIX "
    if [ -n "$PREFIX" ]; then
        echo -n $PREFIX
    fi
    local SYMB_I=0
    for ((;SYMB_I<$INPUT_L; SYMB_I=SYMB_I+1)) do
        printf $__DEBUG_SEPARATOR_CHAR
    done
    if [ -n "$POSTFIX" ]; then
        echo -n $POSTFIX
    fi
    echo
}

debug_locals()
{
    local _VAR_NOT_FOUND='debug_env.sh: line '

    local LOCALS_PROMPT="$__DEBUG_PREFIX Enter local var(s) (quit): "
    print_debug_line locals $__DEBUG_SEPARATOR_CHAR
    read -u 1 -ep "$LOCALS_PROMPT" _VAR_N
    while [ -n "$_VAR_N" ]; do
        local _VAR_N_ARR=($(echo ${_VAR_N} | tr "," "\n"))
        if (( ${#_VAR_N_ARR[@]} > 0 )); then
            for _VAR in "${_VAR_N_ARR[@]}"
            do
                echo -ne "$__DEBUG_PREFIX\t"
                local _VAR_INFO="$(declare -p $_VAR 2>&1)"
                if [[ ${_VAR_INFO} =~ ^${_VAR_NOT_FOUND}.* ]]; then
                    echo "${_VAR_INFO:31}"
                else
                    echo "${_VAR_INFO:10}"
                fi
            done
        fi
        echo $__DEBUG_PREFIX
        read -u 1 -ep "$LOCALS_PROMPT" _VAR_N
    done
    print_debug_line $__DEBUG_SEPARATOR_CHAR locals
    echo
}

__DEBUG_GOTO_LINE=

debug_goto()
{
    print_debug_line goto $__DEBUG_SEPARATOR_CHAR
    read -u 1 -ep "$__DEBUG_PREFIX Enter line number to go to (quit): " _LINE_GOTO
    if [[ "$_LINE_GOTO" =~ ^[0-9]+$ && "$_LINE_GOTO" -le 9999 ]]; then
        __DEBUG_GOTO_LINE=$_LINE_GOTO
    fi
    print_debug_line $__DEBUG_SEPARATOR_CHAR goto
    echo
}

debug_continue()
{
    echo -n
    __DEBUG_GOTO_LINE=999999
}

debug_next()
{
    echo -n
}

__DEBUG_WELCOM=

debug()
{
    if [ -z $__DEBUG_WELCOM ]; then
        echo -ne '\U0001F525'
        echo -e "\t BASH DEBUGGER"
        print_debug_line
        echo -e "\t press 'l' to check variables"
        echo -e "\t press 'g' to go to the line"
        echo -e "\t press 'c' to continue to the end of script"
        echo -e "\t press 'n' to continue to the next line"
        echo -e "\t press 'q' (^C) to abort"
        print_debug_line
        echo
        __DEBUG_WELCOM=1
    fi
    local SRC_LINENO=${1}
    local SRC_PREFIX="$__DEBUG_PREFIX $(basename $0):"
    local SRC_PREFIX_LEN=${#SRC_PREFIX}
    SRC_PREFIX_LEN=$((SRC_PREFIX_LEN + 5))
    printf "%-${SRC_PREFIX_LEN}s" "${SRC_PREFIX}${SRC_LINENO}"
    echo -n " => $BASH_COMMAND"
    if [ -n "$__DEBUG_GOTO_LINE" ]; then
        if (( $__DEBUG_GOTO_LINE <= $SRC_LINENO )); then
            __DEBUG_GOTO_LINE=
        fi
    fi
    if [ -z $__DEBUG_GOTO_LINE ]; then
        read -u 1 -ep " => l, g, c, (n): " _CMD
        [[ ! $_CMD =~ l|g|c|n|q ]] && _CMD=
        [ -z $_CMD ] && _CMD=n
        case "$_CMD" in
            l)
            debug_locals
            ;;
            g)
            debug_goto
            ;;
            c)
            debug_continue
            ;;
            n)
            debug_next
            ;;
            q)
            exit 1
            ;;
        esac
    else
        echo
    fi
}

trap "debug \${LINENO}" DEBUG
