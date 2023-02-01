#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_crypt.sh
set -o functrace

__show_help()
{
    echo "Usage" $(basename $0) "(options) (data file) (key file)                "
    echo "_______________________________________________________________________"
    echo "Encrypt data file with key file or passphrase.                         "
    print_passphrase_requirements
    echo "_______________________________________________________________________"
    echo " -m  Encrypt with master key only ($SH_TOOLS_MASTER_KEY_PATH)          "
    echo " -v  Verbose                                                           "
    echo " -P  [passphrase]                                                      "
    echo "     Send master passphrase (for not interactive mode only!)           "
    echo " -f  Fakemode (to see affected files only)                             "
    echo
}

main()
{
    set +o functrace
    
    if [ -z $1 ]; then
        __show_help
        exit 0
    fi

    local CLI_PASSPHRASE=
    local OPT_MASTER_KEY=
    while getopts ':P:mvfh' OPTION; do
    case "$OPTION" in
        P) 
        CLI_PASSPHRASE=$OPTARG
        ;;    
        m)
        OPT_MASTER_KEY=1
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

    local DATA_FILE=${1}
    if [ -z $DATA_FILE ]; then
        __show_help
        exit 0
    fi

    local KEY_FILE=${2}

    if [ -n "${DATA_FILE}" ]; then
        if [ ! -f $DATA_FILE ]; then
            print_error "Invalid data file!"
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

    if (( $OPT_MASTER_KEY )); then
        obtain_master_key __MASTER_PASSPHRASE
        if [ -n "${__MASTER_PASSPHRASE}" ]; then
            encrypt_file ${DATA_FILE} ${__MASTER_PASSPHRASE}
            __MASTER_PASSPHRASE=
        else
            print_error "Failed to apply master key!"
            exit 1
        fi
    elif [ -z ${KEY_FILE} ]; then
        if [ -n "${CLI_PASSPHRASE}" ]; then
            local __PASSPHRASE=${CLI_PASSPHRASE}
        else
            create_passphrase __PASSPHRASE
        fi
        if [ -n "${__PASSPHRASE}" ]; then
            encrypt_file ${DATA_FILE} "${__PASSPHRASE}"
            __PASSPHRASE=
        else
            print_error "Failed to apply passphrase!"
            exit 1            
        fi        
    else
        encrypt_file_with_key_file ${DATA_FILE} ${KEY_FILE}
    fi
}

main $@