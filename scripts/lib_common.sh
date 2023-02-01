#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_externals.sh

function log_var()
{
    if [[ ! -z $DEBUG && $DEBUG > 0 && ! -z $1 && ! -z $2 ]]
    then
        echo $1 = $2 
    fi
}

function init_sudo()
{
    if [[ $EUID -ne 0 ]]; then
        SUDO="sudo"
        LOGIN=${USER}
        UNSUDO=""
    else
        SUDO=""
        LOGIN=$(who | awk '{print $1; exit}')
        UNSUDO="sudo -u ${LOGIN}"
    fi
    USER_HOME=$( getent passwd "$LOGIN" | cut -d: -f6 )
}

function normalize_home_path()
{
    if [ $# -ge 1 ]; then
        local EHOME_=${USER_HOME}
        if [ -z ${EHOME_} ]; then
            EHOME_=${HOME}
        fi
        if [ ! ${HOME} == ${EHOME_} ]; then
            echo $(echo ${1} | sed s+${HOME}+${EHOME_}+)
        else
            echo ${1}
        fi
    else
        echo
    fi 
}

# Validate input IPv4
function valid_ip4()
{
    local IPv4=$1
    local RESULT=

    if [[ $IPv4 =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local OIFS=$IFS
        IFS='.'
        IPv4=($IPv4)
        IFS=$OIFS
        [[ ${IPv4[0]} -le 255 && ${IPv4[1]} -le 255 \
            && ${IPv4[2]} -le 255 && ${IPv4[3]} -le 255 ]]
        [ $? -eq 0 ] && RESULT=1
    fi
    echo $RESULT
}

# Check if input directory is empty
function empty_dir()
{
    local DIR=$1
    local RESULT=
    local DIR_ABS=$(find ${DIR} -maxdepth 0 -type d -empty 2>/dev/null)

    if [[ -n "$DIR_ABS" && -d ${DIR_ABS} ]]; then
        RESULT=1
    fi
    echo $RESULT
}

function random_str()
{
    if [ -n "$(which xxd)" ]; then
        local prob=$(dd if=/dev/urandom count=16 bs=1 2>/dev/null \
                        | xxd -c 16 -p)
        echo $(echo $prob)
    elif [ -n "$(which md5sum)" ]; then
        echo $(date -u|md5sum|cut -d ' ' -f 1)
    else
        echo "000000"
    fi
}

function print_error_()
{
    echo "$@" >&2
}

function print_error()
{
    print_error_ "$(emoji $EMOJI_ID_16_STOP) $@"
}

function save_alias()
{
    if [[ $# -le 1 ]]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid arguments"
        exit 1
    fi

    local _alias=$1
    shift
    if [[ -z $USER_HOME ]]; then
        USER_HOME=$HOME
    fi
    local ALIASES_PATH=$USER_HOME/.bash_aliases
    if [[ ! -f $ALIASES_PATH ]]; then
        ${UNSUDO} touch $ALIASES_PATH
        cat <<EOMMM >>$ALIASES_PATH
#!/bin/bash

EOMMM
        echo "alias ${_alias}=${@}" >> $ALIASES_PATH
    else
        local _alias_text="alias ${_alias}=${@}"
        IFS='=' read -ra SEARCH_ <<< "${_alias_text}"
        IFS=' ' read -ra SEARCH_ <<< "${SEARCH_[0]}"
        SEARCH_=${SEARCH_[1]}
        if [[ -z `cat $ALIASES_PATH|awk -F"=" '{ print $1 }'|awk -F"\ " '{ print $2 }'|awk /$SEARCH_/` ]]; then
            echo "alias ${_alias}=${@}" >> $ALIASES_PATH
            # alias "${_alias}=${@}"
            # shopt -s expand_aliases
        fi
    fi
}

function read_secret_n()
{
    # Disable echo.
    stty -echo

    # Set up trap to ensure echo is enabled before exiting if the script
    # is terminated while echo is disabled.
    trap 'stty echo' EXIT

    # Read secret.
    read "$@"

    # Enable echo.
    stty echo
    trap - EXIT
}

function read_secret()
{
    read_secret_n "$@"
    
    # Print a newline because the newline entered by the user after
    # entering the passcode is not echoed. This ensures that the
    # next line of output begins at a new line.
    echo
}

function __answer()
{
    local ANSW=$1
    local DEFAULT_YES=$2
    declare -n _YES_RESULT=$3
    local SELECTION_PROMPT=$4

    if [[ ! -n "${SELECTION_PROMPT}" ]]; then
        SELECTION_PROMPT='[Y/n]';
        if (( $DEFAULT_YES < 1 )); then
            SELECTION_PROMPT='[N/y]'
        fi
    fi

    local ANSW_="${ANSW} ${SELECTION_PROMPT}: "
    read -p "${ANSW_}" ANSW_RESULT_
    until [[ -z "$ANSW_RESULT_" || "$ANSW_RESULT_" =~ ^([YyNn]+|[Yy]+[Ee]+[Ss]+|[Nn]+[Oo]+)$ ]]; do
        read -p "${ANSW_}" ANSW_RESULT_
    done

    if [ -z ${ANSW_RESULT_} ]; then
        if (( $DEFAULT_YES > 0 )); then
            _YES_RESULT=1
        fi
    elif [[ ! "$ANSW_RESULT_" =~ ^([Nn]+|[Nn]+[Oo]+)$ ]]; then
        _YES_RESULT=1
    fi
    ANSW_RESULT_=
}

function answer_yes()
{
    local ANSW=$1
    declare -n YES_RESULT=$2

    __answer "${1}" 1 YES_RESULT_ "$3"
    YES_RESULT=$YES_RESULT_
    YES_RESULT_=
}

function answer_no()
{
    local ANSW=$1
    declare -n YES_RESULT=$2

    __answer "${1}" 0 YES_RESULT_ "$3"
    YES_RESULT=$YES_RESULT_
    YES_RESULT_=
}

function any_key()
{
    read -p "(Press Enter to continue)" I_
}

function input()
{
    local TITLE=$1
    declare -n INPUT_RESULT=$2

    local TITLE_="${TITLE}: "
    read -p "${TITLE_}" INPUT_RESULT_
    if [ $# -ge 3 ]; then # if input required!
        until [[ -n "$INPUT_RESULT_" ]]; do
            read -p "${TITLE_}" INPUT_RESULT_
        done
    fi

    INPUT_RESULT=${INPUT_RESULT_}
}

function __show_restart_warning()
{
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Requires reloading for current terminal to apply changes!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
}

function restart_this_terminal()
{
    __show_restart_warning
    
    # TODO: Check for SSH terminal
    if [ -n "$(which gnome-terminal)" ]; then
        echo | ${UNSUDO} nohup gnome-terminal >$(mktemp /tmp/nohup.out.XXXXXX) 2>&1; kill -9 ${PPID} & 
        disown
    else
        kill -9 ${PPID}
    fi
    exit 0
}

function get_file_extention()
{
    local FILE_PATH=${1}
    if [ -n "${FILE_PATH}" ]; then
        echo $(basename "${FILE_PATH}"|rev|cut -d '.' -f 1|rev)
    fi
}

EMOJI_ID_8_LOOK=0
EMOJI_ID_8_OLD_KEY=1
EMOJI_ID_8_DEATH=99

EMOJI_ID_16_LOOK=$EMOJI_ID_8_LOOK
EMOJI_ID_16_GOLD_KEY=100
EMOJI_ID_16_LOCK_CLOSED=101
EMOJI_ID_16_LOCK_OPENED=102
EMOJI_ID_16_LOCK_WITH_KEY=103
EMOJI_ID_16_ALLOW_WALKING=104
EMOJI_ID_16_STOP=105
EMOJI_ID_16_FORBIDDEN=106
EMOJI_ID_16_OK=107
EMOJI_ID_16_DANGEROUS=108
EMOJI_ID_16_DEATH=999

function emoji()
{
    local EMOJI_ID=$1
    local EMOJI_CODE=

    [ -z $EMOJI_ID ] && EMOJI_ID=0

    [ $EMOJI_ID == $EMOJI_ID_8_LOOK ] && EMOJI_CODE='\U0001F440'
    [ $EMOJI_ID == $EMOJI_ID_8_OLD_KEY ] && EMOJI_CODE='\U0001F5DD'
    [ $EMOJI_ID == $EMOJI_ID_8_DEATH ] && EMOJI_CODE='\U00002620'

    [ $EMOJI_ID == $EMOJI_ID_16_GOLD_KEY ] && EMOJI_CODE='\U0001F511'
    [ $EMOJI_ID == $EMOJI_ID_16_LOCK_CLOSED ] && EMOJI_CODE='\U0001F512'
    [ $EMOJI_ID == $EMOJI_ID_16_LOCK_OPENED ] && EMOJI_CODE='\U0001F513'
    [ $EMOJI_ID == $EMOJI_ID_16_LOCK_WITH_KEY ] && EMOJI_CODE='\U0001F510'
    [ $EMOJI_ID == $EMOJI_ID_16_ALLOW_WALKING ] && EMOJI_CODE='\U0001F6B8'
    [ $EMOJI_ID == $EMOJI_ID_16_STOP ] && EMOJI_CODE='\U000026D4'
    [ $EMOJI_ID == $EMOJI_ID_16_FORBIDDEN ] && EMOJI_CODE='\U0001F6A7'
    [ $EMOJI_ID == $EMOJI_ID_16_OK ] && EMOJI_CODE='\U00002705'
    [ $EMOJI_ID == $EMOJI_ID_16_DANGEROUS ] && EMOJI_CODE='\U0001F525'
    [ $EMOJI_ID == $EMOJI_ID_16_DEATH ] && EMOJI_CODE='\U0001F480'

    if [ -n "$EMOJI_CODE" ]; then
        echo -ne $EMOJI_CODE
    fi
}

function get_screen_width()
{
    echo $(/usr/bin/tput cols)
}

__LOG_SEPARATOR_CHAR='='

function log()
{
    local PREFIX=$1
    local POSTFIX=$2
    local SYMBOL=$3

    if [ -z $SYMBOL ]; then
        SYMBOL=$__LOG_SEPARATOR_CHAR
    else
        SYMBOL=${SYMBOL::1}
    fi

    local LIMIT_L=$(get_screen_width)
    local INPUT_L=$((LIMIT_L - ${#PREFIX} - ${#POSTFIX}))

    if [ -n "$PREFIX" ]; then
        echo -n $PREFIX
    fi
    local SYMB_I=0
    for ((;SYMB_I<$INPUT_L; SYMB_I=SYMB_I+1)) do
        printf $SYMBOL
    done
    if [ -n "$POSTFIX" ]; then
        echo -n $POSTFIX
    fi    
    echo
}
