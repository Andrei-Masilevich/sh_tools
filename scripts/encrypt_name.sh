#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_crypt.sh
set -o functrace

__show_help()
{
   echo "Usage" $(basename $0) "(options) (data file) (key file)                "
   echo "_______________________________________________________________________"
   echo "Encrypt filename with key file or passphrase.                          "
   print_passphrase_requirements
   echo "_______________________________________________________________________"
   echo " -d       Encrypt directory name                                       "
   echo " -m       Encrypt with master key only ($SH_TOOLS_MASTER_KEY_PATH)     "
   echo " -v       Verbose                                                      "
   echo " -f       Fakemode (to see affected files only)                        "
   echo
}

main()
{
    set +o functrace
    
    if [ -z $1 ]; then
        __show_help
        exit 0
    fi

    local OPT_IS_DIR=
    local OPT_MASTER_KEY=
    local OPT_RECURSIVELY=
    while getopts ':dmvfh' OPTION; do
    case "$OPTION" in
        d)
        OPT_IS_DIR=1
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
        if (( $OPT_IS_DIR )); then
            if [ ! -d $DATA_FILE ]; then
                print_error "Invalid data folder!"
                exit 1
            fi
        else
            if [ ! -f $DATA_FILE ]; then
                DATA_FILE=$(crypted_name ${DATA_FILE})
            fi
            if [ ! -f $DATA_FILE ]; then
                print_error "Invalid data file!"
                exit 1
            fi
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
            encrypt_name ${DATA_FILE} ${__MASTER_PASSPHRASE} $OPT_IS_DIR
            __MASTER_PASSPHRASE=
        else
            print_error "Failed to apply master key!"
            exit 1
        fi
    elif [ -z ${KEY_FILE} ]; then
        create_passphrase __PASSPHRASE
        if [ -n "${__PASSPHRASE}" ]; then
            encrypt_name ${DATA_FILE} "${__PASSPHRASE}" $OPT_IS_DIR
            __PASSPHRASE=
        else
            print_error "Failed to apply passphrase!"
            exit 1            
        fi
    else
        encrypt_name_with_key_file ${DATA_FILE} ${KEY_FILE} $OPT_IS_DIR
    fi
}

main $@