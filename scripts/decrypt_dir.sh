#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_crypt.sh
set -o functrace

__show_help()
{
   echo "Usage" $(basename $0) "(options) (data dir) (key file|--) (passphrase)"
   echo "______________________________________________________________________"
   echo "Decrypt data directory with key file or passphrase.                   "
   print_passphrase_requirements
   echo "______________________________________________________________________"
   echo " -m       Decrypt with master key only ($SH_TOOLS_MASTER_KEY_PATH)    "
   echo " -r       Decrypt recursively                                         "
   echo " -v       Verbose                                                     "
   echo " -f       Fakemode (to see affected files only)                       "   
   echo
}

main()
{
    set +o functrace
    
    if [ -z $1 ]; then
        __show_help
        exit 0
    fi

    local OPT_MASTER_KEY=
    local OPT_RECURSIVELY=
    while getopts ':mrvfh' OPTION; do
    case "$OPTION" in
        m)
        OPT_MASTER_KEY=1
        ;;    
        r)
        OPT_RECURSIVELY=1
        ;;
        v)
        LIB_CRYPT_OPTION_VERBOSE=1
        ;;
        f)
        LIB_CRYPT_OPTION_FAKE_DEBUG=1
        ;;

        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    shift "$(($OPTIND -1))"

    local DATA_DIR=${1}
    if [ -z $DATA_DIR ]; then
        __show_help
        exit 0
    fi

    local KEY_FILE=${2}

    if [ -n "${DATA_DIR}" ]; then
        if [ ! -d $DATA_DIR ]; then
            print_error "Invalid data folder!"
            exit 1
        fi
    else
        print_error "Invalid data file!"
        exit 1
    fi

    if [[ -n "${KEY_FILE}" && ! -f ${KEY_FILE} ]]; then
        print_error "Invalid key file!"
        exit 1
    fi

    init_crypt

    local PASSPHRASE=
    local ARGS=
    if (( $OPT_MASTER_KEY )); then
        obtain_master_key __MASTER_PASSPHRASE
        if [ -n "${__MASTER_PASSPHRASE}" ]; then
            ARGS="${DATA_DIR} -- "
            PASSPHRASE=${__MASTER_PASSPHRASE}
            __MASTER_PASSPHRASE=
        else
            print_error "Failed to apply master key!"
            exit 1
        fi
    elif [ -z ${KEY_FILE} ]; then
        get_passphrase __PASSPHRASE
        if [ -n "${__PASSPHRASE}" ]; then
            ARGS="${DATA_DIR} -- "
            PASSPHRASE=${__PASSPHRASE}
            __PASSPHRASE=
        else
            print_error "Failed to apply passphrase!"
            exit 1
        fi
    else
        ARGS="${DATA_DIR} ${KEY_FILE}"
    fi

    if (( $OPT_RECURSIVELY )); then
        decrypt_folder_recursively ${ARGS} "${PASSPHRASE}"
    else
        decrypt_folder ${ARGS} "${PASSPHRASE}"
    fi
}

main $@