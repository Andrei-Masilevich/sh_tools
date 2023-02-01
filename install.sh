#!/bin/bash

THIS_DIR="$(cd $(dirname ${BASH_SOURCE}) && pwd)"
source $THIS_DIR/scripts/lib_common.sh
source $THIS_DIR/scripts/lib_crypt.sh
set -o functrace # Instruction for debugger only. To trace top level functions

if [ -z ${SH_TOOLS_INSTALL_HOME} ]; then
    SH_TOOLS_INSTALL_HOME=$HOME
fi 
__SCRIPTS_TARGET_DIR=${SH_TOOLS_INSTALL_HOME}/.local/sh_tools
__CLI_RELOAD_REQUIRED=

__show_help()
{
   echo "Usage $(basename $0) (target directory)                                   "
   echo "__________________________________________________________________________"
   echo "Install these scripts to target directory. Default: $__SCRIPTS_TARGET_DIR "
   echo "__________________________________________________________________________"
   echo " -x [prefix]                                                              "
   echo "     Custom prefix for scripts.                                           "
   echo "     Default: $(__get_short_personal_prefix)                              "
   echo " -d  Cleanup target dir before install                                    "
   echo " -i  [path]                                                               "
   echo "     Import data files (and master key) from encrypted backup archive.    "
   echo "     -Z - with key path is reqired                                        "
   echo " -Z  [path to key file]                                                   "
   echo "     Use key file to decrypt backup archive                               "
   echo " -m  Try to rewrite previous master key                                   "
   echo " -P  [passphrase]                                                         "
   echo "     Send master passphrase (for not interactive mode only!)              "
   echo " -v  Verbose                                                              "
   echo
}

__get_short_personal_prefix()
{
    local USR=${USER}
    if [ ! -n "${USER}" ]; then
        USER=my
    fi

    if (( ${#USER} > 5 )); then
        USER=${USER:0:5}
    fi

    echo $USER
}

__ENV_SOURCE_LIST_SPLITTER='#%>'
__ENV_SOURCE_LIST_PREFIX='-'

__OPT_VERBOSE=

__verbose()
{
    if (( $__OPT_VERBOSE )); then
        echo "$@"
    fi
}

main()
{
    set +o functrace # Instruction for debugger only. Don't go to the deeper functions
    local PREFIX=$(__get_short_personal_prefix)
    local CLEANUP=
    local REWRITE_MASTER_KEY=
    local IMPORT_ARCHIVE_FILE=
    local IMPORT_ARCHIVE_FILE_KEY_PATH=
    local CLI_PASSPHRASE=
    local NOT_INTERACTIVE=
    while getopts ":P:x:di:Z:vmh" OPTION
    do
    case $OPTION in
        P) 
        CLI_PASSPHRASE=$OPTARG
        NOT_INTERACTIVE=1
        ;;
        x)
        PREFIX=$OPTARG
        ;;
        d)
        CLEANUP=1
        ;;
        i)
        IMPORT_ARCHIVE_FILE=$OPTARG
        ;;
        Z) 
        IMPORT_ARCHIVE_FILE_KEY_PATH=$OPTARG
        ;;
        m)
        REWRITE_MASTER_KEY=1
        ;;
        v) 
        __OPT_VERBOSE=1
        ;;
        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
        *     );;
    esac
    done

    shift "$(($OPTIND -1))"

    OPTIND=0

    local INF_FILE=${THIS_DIR}/env.inf

    if [ ! -f $INF_FILE ]; then
        print_error "ENV pattern is broken!"
        exit 1
    fi

    local IMPORT_ARCHIVE=
    if [ -n "${IMPORT_ARCHIVE_FILE}" ]; then
        if [ ! -f ${IMPORT_ARCHIVE_FILE} ]; then
            print_error "Backup archive is not found!"
            exit 1
        fi

        if [[ ! -n "${IMPORT_ARCHIVE_FILE_KEY_PATH}" || ! -f "${IMPORT_ARCHIVE_FILE_KEY_PATH}" ]]; then
            print_error "Key file is required to decrypt backup archive!"
            exit 1
        fi
        IMPORT_ARCHIVE=1

        if (( __OPT_VERBOSE )); then
            echo "IMPORT_ARCHIVE_FILE=${IMPORT_ARCHIVE_FILE}"
            echo "IMPORT_ARCHIVE_FILE_KEY_PATH=${IMPORT_ARCHIVE_FILE_KEY_PATH}"
            echo "PWD=$(pwd)"
        fi
    elif [ -n "${IMPORT_ARCHIVE_FILE_KEY_PATH}" ]; then
        print_error "Backup archive path is required!"
        exit 1
    fi

    local TARGET_DIR=${1}
    if [ ! -n "${TARGET_DIR}" ]; then
        TARGET_DIR=${__SCRIPTS_TARGET_DIR}/${PREFIX}
    fi

    local TARGET_DIR_FOR_SCRIPTS=${TARGET_DIR}/bin
    local DATA_DIR=.data
    local TARGET_DIR_FOR_DATA=${TARGET_DIR}/${DATA_DIR}
    local TARGET_ENV=${TARGET_DIR}/env

    mkdir -p ${TARGET_DIR_FOR_SCRIPTS} 2>/dev/null
    if [ ! -d ${TARGET_DIR_FOR_SCRIPTS} ]; then
        print_error "Invalid target dir!"
        exit 1
    fi

    touch ${TARGET_DIR}/test 2>/dev/null
    touch ${TARGET_DIR_FOR_SCRIPTS}/test 2>/dev/null
    if [[ ! -f ${TARGET_DIR}/test || ! -f ${TARGET_DIR_FOR_SCRIPTS}/test ]]; then
        print_error "Invalid target dir!"
        exit 1
    fi
    rm -f ${TARGET_DIR}/test
    rm -f ${TARGET_DIR_FOR_SCRIPTS}/test
    
    if (( CLEANUP || IMPORT_ARCHIVE )); then
        rm -rf ${TARGET_DIR_FOR_SCRIPTS}
        if (( NOT_INTERACTIVE )); then
            rm -rf ${TARGET_DIR_FOR_DATA}
        else
            mkdir -p ${TARGET_DIR_FOR_DATA}
            if [ -n "$(ls -A ${TARGET_DIR_FOR_DATA})" ]; then
                answer_no "$(emoji $EMOJI_ID_16_DANGEROUS) Configuration for previous installation is not empty. Do you want to erase it anyway?" __YES_RESULT
                if (( $__YES_RESULT )); then
                    rm -rf ${TARGET_DIR_FOR_DATA}
                fi
            fi
        fi
        rm -f ${TARGET_ENV}
    fi
    mkdir -p ${TARGET_DIR_FOR_SCRIPTS}
    mkdir -p ${TARGET_DIR_FOR_DATA}

    # Create ENV
    local LN_=
    local IN_SOURCE_LIST=
    local SOURCE_LIST=()
    local N_ENV_SOURCE_LIST_PREFIX=${#__ENV_SOURCE_LIST_PREFIX}
    local LN_N=0
    local SOURCE_SCRIPT=

    while read -r LN_; do
        if [[ "${LN_}" =~ ^${__ENV_SOURCE_LIST_SPLITTER}.* ]]; then
            IN_SOURCE_LIST=1
        elif (( $IN_SOURCE_LIST )); then
            if [[ -n "${LN_}" && ${LN_:0:1} != '#' &&  ${LN_:0:$N_ENV_SOURCE_LIST_PREFIX} == $__ENV_SOURCE_LIST_PREFIX ]]; then
                SOURCE_SCRIPT="${THIS_DIR}/${LN_: $N_ENV_SOURCE_LIST_PREFIX}"
                if [ -f ${SOURCE_SCRIPT} ]; then
                    SOURCE_LIST+=("${SOURCE_SCRIPT}")
                fi
            fi
        elif [ -z $IN_SOURCE_LIST ]; then
            LN_N=$((LN_N + 1))
        fi
    done <$INF_FILE

    if (( ${#SOURCE_LIST[@]} < 1 )); then
        print_error "There is no any file to install!"
        exit 1    
    fi 

    head -n $LN_N $INF_FILE > $TARGET_ENV
    sed s+'%INSTALL_DIR%'+${TARGET_DIR_FOR_SCRIPTS}+g -i $TARGET_ENV
    sed s+'%DATA_DIR%'+${TARGET_DIR_FOR_DATA}+g -i $TARGET_ENV
    sed s+'%ID%'+${PREFIX}+g -i $TARGET_ENV

    . $TARGET_ENV

    init_crypt

    # Fill up executives
    for SOURCE_SCRIPT in "${SOURCE_LIST[@]}"; do
        __verbose "Copy ${SOURCE_SCRIPT} to ${TARGET_DIR_FOR_SCRIPTS}"

        local SCRIPT_NAME=$(basename $SOURCE_SCRIPT)
        if [ ${SCRIPT_NAME:0:4} != 'lib_' ]; then
            SCRIPT_NAME=$(echo $SCRIPT_NAME|cut -f 1 -d '.')
            SCRIPT_NAME=${PREFIX}_${SCRIPT_NAME}

            cp -f ${SOURCE_SCRIPT} ${TARGET_DIR_FOR_SCRIPTS}/
            chmod +x ${TARGET_DIR_FOR_SCRIPTS}/$(basename ${SOURCE_SCRIPT})
            ln -f -s ${TARGET_DIR_FOR_SCRIPTS}/$(basename ${SOURCE_SCRIPT}) ${TARGET_DIR_FOR_SCRIPTS}/${SCRIPT_NAME}
        else
            cp -f ${SOURCE_SCRIPT} ${TARGET_DIR_FOR_SCRIPTS}/
            chmod -x ${TARGET_DIR_FOR_SCRIPTS}/${SCRIPT_NAME}
        fi
    done

    __verbose "$(emoji $EMOJI_ID_16_OK) - Fill up executives - Done"

    # Finalize ENV to add some script support
    cat <<EOMMM >>${TARGET_ENV}
# Support for SSH-Agent
source ${TARGET_DIR_FOR_SCRIPTS}/lib_activate_keys.sh
obtain_ssh_environment
EOMMM

    __verbose "$(emoji $EMOJI_ID_16_OK) - Create ENV - Done"

    # Register ENV for user sessions
    local ENV_CMD=". ${TARGET_ENV}"
    
    local SYS_PROFILE='.profile'
    if [[ -f ${SH_TOOLS_INSTALL_HOME}/$SYS_PROFILE && -z $(grep "$ENV_CMD" ${SH_TOOLS_INSTALL_HOME}/$SYS_PROFILE) ]]; then
        echo            >> ${SH_TOOLS_INSTALL_HOME}/$SYS_PROFILE
        echo "$ENV_CMD" >> ${SH_TOOLS_INSTALL_HOME}/$SYS_PROFILE
        __CLI_RELOAD_REQUIRED=1
    fi
    local SYS_BASH='.bashrc'
    if [[ -f ${SH_TOOLS_INSTALL_HOME}/$SYS_BASH && -z $(grep "$ENV_CMD" ${SH_TOOLS_INSTALL_HOME}/$SYS_BASH) ]]; then
        echo            >> ${SH_TOOLS_INSTALL_HOME}/$SYS_BASH
        echo "$ENV_CMD" >> ${SH_TOOLS_INSTALL_HOME}/$SYS_BASH
        __CLI_RELOAD_REQUIRED=1
    fi

    __verbose "$(emoji $EMOJI_ID_16_OK) - Register ENV - Done"

    if [[ -n "${IMPORT_ARCHIVE_FILE}" && -n "${IMPORT_ARCHIVE_FILE_KEY_PATH}" ]]; then
        local ARGS='-rf'
        if (( __OPT_VERBOSE )); then
            ARGS="${ARGS} -v "
        fi
        if [ -n "${CLI_PASSPHRASE}" ]; then
            ARGS="${ARGS} -P "
        fi 
        . $THIS_DIR/scripts/backup.sh ${ARGS} "${CLI_PASSPHRASE}" -Z ${IMPORT_ARCHIVE_FILE_KEY_PATH} ${IMPORT_ARCHIVE_FILE}

        # Already re-written by backup script
        REWRITE_MASTER_KEY=0
    fi

    mkdir -p ${TARGET_DIR_FOR_DATA}/ssh/keys
    mkdir -p ${TARGET_DIR_FOR_DATA}/ssh/pubs
    mkdir -p ${TARGET_DIR_FOR_DATA}/ca
    mkdir -p ${TARGET_DIR_FOR_DATA}/vpn

    local CREATE_MASTER_KEY=
    local MASTER_KEY=$(crypted_name ${SH_TOOLS_MASTER_KEY_PATH})
    if [ -f ${MASTER_KEY} ]; then
        if (( $REWRITE_MASTER_KEY )); then
            if [ -z $NOT_INTERACTIVE ]; then
                answer_no "$(emoji $EMOJI_ID_16_DANGEROUS) Master key already exists. Do you want to erase this key?" __YES_RESULT
            else
                __YES_RESULT=1
            fi
            if (( $__YES_RESULT )); then
                CREATE_MASTER_KEY=1
            fi
            __YES_RESULT=
        fi
    else
        CREATE_MASTER_KEY=1
    fi

    if (( $CREATE_MASTER_KEY )); then
        if [ -n "$(find ${TARGET_DIR_FOR_DATA} -type f -name '*."${__ENCRYPTED_EXT_SYMBOL}"' 2>/dev/null)" ]; then
            if [ -z $NOT_INTERACTIVE ]; then
                answer_no "$(emoji $EMOJI_ID_16_DEATH) Some files will be lost (encrypted with existing master key)! Agree?" __YES_RESULT
            else
                __YES_RESULT=1
            fi
            if (( $__YES_RESULT )); then
                cleanup_secret_file ${MASTER_KEY}
                CREATE_MASTER_KEY=1
            else
                CREATE_MASTER_KEY=
            fi
            __YES_RESULT=
        fi
    fi

    if (( $CREATE_MASTER_KEY )); then
        create_master_key "${CLI_PASSPHRASE}" __MASTER_PASSPHRASE
        if [ -z $__MASTER_PASSPHRASE ]; then
            print_error "Invalid passphrase. Aborted"
            rm -rf ${TARGET_DIR}
            exit 1
        fi
        __MASTER_PASSPHRASE=
    fi

    __verbose "$(emoji $EMOJI_ID_16_OK) - Support for SSH related executives - Done"

    if (( $__CLI_RELOAD_REQUIRED )); then
        if [ -z $NOT_INTERACTIVE ]; then
            restart_this_terminal
        fi
    fi
}

main $@
