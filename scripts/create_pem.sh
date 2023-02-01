#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_crypt.sh
set -o functrace

__PRIV_FOLDER=ssh/keys
__PUB_FOLDER=ssh/pubs
__SUPPORTED_KEY_TYPES='ecdsa|ed25519|rsa'
__DEFAUL_KEY_TYPE=ed25519
__PEM_EXT='pem'

__default_comment()
{
    echo "$(whoami)@$(hostname)"
}

__show_help()
{
    set +o functrace

    echo "Usage" $(basename $0) "(options) [key name]                            "
    echo "_______________________________________________________________________"
    echo "Create private SSH key file in PEM format.                             "
    print_passphrase_requirements
    echo "or use -N options to ignore passphrase.                                "
    echo "_______________________________________________________________________"
    echo " -d [directory path]                                                   "
    echo "              Path to directory to save PEM keys.                      "
    echo "              Default: ${SH_TOOLS_DATA_DIR_PATH}/${__PRIV_FOLDER}      "
    echo " -P [directory path]                                                   "
    echo "              Path to directory to save Public keys.                   "
    echo "              Default: ${SH_TOOLS_DATA_DIR_PATH}/${__PUB_FOLDER}       "
    echo " -s           Remove public key file.                                  "
    echo " -N           Create key without passphrase                            "
    echo " -C [comment]                                                          "
    echo "              Custom comment for key. Default: $(__default_comment)      "
    echo " -t [$__SUPPORTED_KEY_TYPES]                                           "
    echo "              Key type. Default: $__DEFAUL_KEY_TYPE                    "
    echo
}

main()
{
    set +o functrace
    init_crypt

    local KEYS_DATABASE=${SH_TOOLS_DATA_DIR_PATH}/${__PRIV_FOLDER}
    local KEYS_DATABASE_PUB=${SH_TOOLS_DATA_DIR_PATH}/${__PUB_FOLDER}
    local OPT_WITHOUT_PSW=
    local OPT_REMOVE_PUB=
    local KEY_COMMENT=$(__default_comment)
    local KEY_TYPE=${__DEFAUL_KEY_TYPE}
    while getopts ':d:P:sNC:t:h' OPTION; do
    case "$OPTION" in
        d)
        KEYS_DATABASE=${OPTARG}
        ;;
        P)
        KEYS_DATABASE_PUB=${OPTARG}
        ;;
        s)
        OPT_REMOVE_PUB=1
        ;;
        N)
        OPT_WITHOUT_PSW=1
        ;;
        C)
        KEY_COMMENT=${OPTARG}
        ;;
        t)
        KEY_TYPE=${OPTARG}
        ;;

        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    shift "$(($OPTIND -1))"

    if [ -z $1 ]; then
        __show_help
        exit 0
    fi

    local KEY_NAME=$1
    local WITH_PSW=1
    local FILE_POSTFIX=_psw
    if (( $OPT_WITHOUT_PSW )); then
        WITH_PSW=
        FILE_POSTFIX=
    fi

    if [[ ! ${KEY_TYPE} =~ ^(${__SUPPORTED_KEY_TYPES})$ ]]; then
        print_error "Invalid key type!"
        exit 1
    fi

    KEYS_DATABASE=$(realpath ${KEYS_DATABASE})

    mkdir -p ${KEYS_DATABASE} 2>/dev/null

    if [ ! -d ${KEYS_DATABASE} ]; then
        print_error "Invalid folder for private key!"
        exit 1
    fi

    KEYS_DATABASE_PUB=$(realpath ${KEYS_DATABASE_PUB})

    if [ ${KEYS_DATABASE_PUB} != ${KEYS_DATABASE} ]; then
        mkdir -p ${KEYS_DATABASE_PUB} 2>/dev/null

        if [ ! -d ${KEYS_DATABASE_PUB} ]; then
            print_error "Invalid folder for public key!"
            exit 1
        fi
    fi

    pushd ${KEYS_DATABASE} > /dev/null

    if [[ -f ${KEY_NAME}${FILE_POSTFIX}.$__PEM_EXT || -f ${KEY_NAME}.pub ]]; then
        print_error "${KEY_NAME}${FILE_POSTFIX}.$__PEM_EXT or ${KEY_NAME}.pub are already exists."
        print_error "Check it before and prevent overriding!"
        exit 1
    fi

    if (( $WITH_PSW )); then
        create_passphrase __PASSPHRASE
        if [ ! -n "${__PASSPHRASE}" ]; then
            print_error "Failed to apply passphrase!"
            exit 1
        fi 
    fi

    local SSH_KEYGEN='ssh-keygen'
    local KEY_TYPE_OPTS=

    if [ ${KEY_TYPE} == 'rsa' ]; then
        KEY_TYPE_OPTS=" -b 4096 "
    fi

    local NEXT=1
    $SSH_KEYGEN -t ${KEY_TYPE} ${KEY_TYPE_OPTS} -C ${KEY_COMMENT} -m PEM -f ${KEY_NAME} -N "${__PASSPHRASE}"
    __PASSPHRASE=

    [ $? -eq 0 ] || NEXT=

    if (( $NEXT )); then
        mv ${KEY_NAME} ${KEY_NAME}${FILE_POSTFIX}.$__PEM_EXT
        chmod 600 ${KEY_NAME}${FILE_POSTFIX}.$__PEM_EXT
        if (( $OPT_REMOVE_PUB )); then
            rm -f ${KEY_NAME}.pub
        elif [ ${KEYS_DATABASE_PUB} != ${KEYS_DATABASE} ]; then
            mv -f ${KEY_NAME}.pub ${KEYS_DATABASE_PUB}/ 
        fi
    else
        rm -f ${KEY_NAME}
        rm -f ${KEY_NAME}.pub

        print_error "Failed to create PEM key!"
        exit 1 
    fi

    popd > /dev/null
}

main $@
