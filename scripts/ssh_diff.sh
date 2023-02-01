#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_common.sh
set -o functrace

__REMOTE_REPO_DIR=.
__DIFF_TOOL='code --wait --diff'
__DOWNLOAD_DIR=$HOME/Downloads

__show_help()
{
   echo "Usage" $(basename $0) "(options) [remote SSH address] {list of files} "
   echo "______________________________________________________________________"
   echo "Compare repo files with remote enviroment.                            "
   echo "______________________________________________________________________"
   echo " -d [remote repo directory path]                                      "
   echo "              Root directory for remote repo.                         "
   echo "              Default: $__REMOTE_REPO_DIR                             "
   echo " -m  [app]                                                            "
   echo "              Application to investigate difference.                  "
   echo "              Default: $__DIFF_TOOL                                   "
   echo " -l [download directory path]                                         "
   echo "              Directory for downloading files.                        "
   echo "              Default: $__DOWNLOAD_DIR                                "
   echo
}

__check_ssh_connection()
{
    set +o functrace
    local REMOTE_REPO_ADDRESS=${1}
    ssh -T ${REMOTE_REPO_ADDRESS} exit 2>/dev/null
    echo $?
}

__diff()
{
    set +o functrace
    local DIFF_TOOL="$1"
    local LOCAL_FILE=$2
    local REMOTE_FILE=$3

    ${DIFF_TOOL} ${LOCAL_FILE} ${REMOTE_FILE} > $(mktemp /tmp/nohup.out.XXXXXX) 2>&1 & disown

    sleep 1
}

main()
{
    set +o functrace
    local REMOTE_REPO_DIR=${__REMOTE_REPO_DIR}
    local DIFF_TOOL=${__DIFF_TOOL}
    local DOWNLOAD_DIR=${__DOWNLOAD_DIR}
    while getopts ':d:m:hl:' OPTION; do
    case "$OPTION" in
        d)
        REMOTE_REPO_DIR=${OPTARG}
        ;;
        m)
        DIFF_TOOL="${OPTARG}"
        ;;
        l)
        DOWNLOAD_DIR=${OPTARG}
        ;;

        h|?)
        __show_help
        exit 1
        ;;
    esac
    done

    shift "$(($OPTIND - 1))"

    if [ -z $1 ]; then
        __show_help
        exit 0
    fi

    local DIFF_TOOL_APP=$(echo -n ${DIFF_TOOL}|cut -d ' ' -f 1)
    if [ -z $(which $DIFF_TOOL_APP) ]; then
        print_error "Diff tool '$DIFF_TOOL_APP' is not found!"
        exit 1
    fi
    if [ $DIFF_TOOL_APP == 'diff' ]; then
        print_error "Diff tool should have GUI interface because stdout will be muted"
        exit 1
    fi

    local LOCAL_REPO_DIR=$(pwd)
    local REMOTE_REPO_ADDRESS=$1

    if [ -z ${REMOTE_REPO_ADDRESS} ]; then
        print_error "Remote repo address is required!"
        exit 1
    fi

    if [ ! -d ${DOWNLOAD_DIR} ]; then
        print_error "Download directory is invalid!"
        exit 1
    fi

    shift;

    if [ $(__check_ssh_connection ${REMOTE_REPO_ADDRESS}) -ne 0 ]; then
        print_error "Invalid SSH connection (check ${REMOTE_REPO_ADDRESS})!"
        exit 1
    fi

    local INPUT_FILES=()
    local INPUT_FILE=

    while [ -n "$1" ]; do
        INPUT_FILE=$1
        shift
        INPUT_FILE=$(realpath ${INPUT_FILE})
        if [ -f ${INPUT_FILE} ]; then
            if [[ ! $INPUT_FILE =~ ^${LOCAL_REPO_DIR}.+ ]]; then
                print_error "Invalid file ${INPUT_FILE}!"
                exit 1
            fi
            INPUT_FILE=${INPUT_FILE:${#LOCAL_REPO_DIR}+1}
            INPUT_FILES+=(${INPUT_FILE})
        fi
    done

    if [ -z $INPUT_FILE ]; then
        print_error "Any input file is required!"
        exit 1
    fi

    local REMOTE_POSTFIX=$(echo ${REMOTE_REPO_ADDRESS}|sed -r 's/@/-/g')
    DOWNLOAD_DIR="${DOWNLOAD_DIR}/${REMOTE_REPO_DIR}/$(basename $0).${REMOTE_POSTFIX}"

    for INPUT_FILE in "${INPUT_FILES[@]}"
    do
        echo "================================================"
        echo "${INPUT_FILE}:"
        local DIR_=$(dirname ${INPUT_FILE})
        local FILE_=$(basename ${INPUT_FILE})
        local EXISTS=$(ssh ${REMOTE_REPO_ADDRESS} find ${REMOTE_REPO_DIR}/${DIR_} -maxdepth 1 -type f -name ${FILE_} 2>/dev/null)
        if [ -n "${EXISTS}" ]; then
            local REMORE_H=$(ssh ${REMOTE_REPO_ADDRESS} sha256sum ${REMOTE_REPO_DIR}/${INPUT_FILE}|cut -d ' ' -f 1)
            local LOCAL_H=$(sha256sum ${LOCAL_REPO_DIR}/${INPUT_FILE}|cut -d ' ' -f 1)
            if [ $REMORE_H == $LOCAL_H ]; then
                echo "OK: ${INPUT_FILE} for both local and remote repo are the same"
            else
                echo "WARNING $(emoji $EMOJI_ID_8_LOOK): ${INPUT_FILE} for local and remote repo have a difference"

                local DOWNLOADED_FILE=${DOWNLOAD_DIR}/${INPUT_FILE}
                mkdir -p $(dirname ${DOWNLOADED_FILE})
                rm -f ${DOWNLOADED_FILE}.${REMOTE_POSTFIX}
                scp ${REMOTE_REPO_ADDRESS}:${REMOTE_REPO_DIR}/${INPUT_FILE} ${DOWNLOADED_FILE}.${REMOTE_POSTFIX}
                __diff "${DIFF_TOOL}" ${LOCAL_REPO_DIR}/${INPUT_FILE} ${DOWNLOADED_FILE}.${REMOTE_POSTFIX}
            fi
        else
            echo "WARNING $(emoji $EMOJI_ID_8_DEATH): THERE IS NO ${INPUT_FILE} ON REMOTE REPO!"
        fi
    done
}

main $@

