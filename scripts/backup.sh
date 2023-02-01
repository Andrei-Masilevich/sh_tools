#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_crypt.sh
source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_realpath.sh
set -o functrace

__show_help()
{
    echo "Usage                                                                          "
    echo "  "$(basename $0) "(options) (backup folder) (archive name)                    "
    echo "      or                                                                       "
    echo "  "$(basename $0) "(options) -r (backup archive path)                          "
    echo "      or                                                                       "
    echo "  "$(basename $0) "(options) -l (backup archive path)                          "
    echo "_______________________________________________________________________________"
    echo "Backup/restore data files by encrypted archive with passphrase or file.        "
    print_passphrase_requirements
    echo "For backup it recreates ciphertext therefore current master key is required.   "
    echo "To restore data the new master key (with master passphrase) will be requested. "
    echo "_______________________________________________________________________________"
    echo " -r  Restore mode (vs. making backup by default)                               "
    echo " -v  Verbose (show manifest and archive logs)                                  "
    echo " -f  Force (for existing data overwriting)                                     "
    echo " -l  Show manifest only (without backup/restore)                               "
    echo " -P  [passphrase]                                                              "
    echo "     Send master passphrase (for not interactive mode only!)                   "
    echo " -z  Use ZIP archive with Ansible encrypted key file                           "
    echo "     (ansible-vault,zip,unzip are required)                                    " 
    echo " -Z  [path to key file]                                                        "
    echo "     Use key file to encrypt/decrypt backup archive                            "
    echo
}

__MANIFEST_FILE_NAME='__'
__MANIFEST_INFO_FULL_ENCRYPTION='<!>'
__MANIFEST_INFO_CONTENT_ENCRYPTION='(!)'
__MANIFEST_INFO_OPEN='.'
__MANIFEST_INFO_UNKNOWN='(?)'
__TAR_EXT='tar.gz'
__KEY_EXT='key'
__ZIP_EXT='zip'

__show_legend()
{
    local LEGEND=${__MANIFEST_INFO_FULL_ENCRYPTION}': - Full encryption (content and file name)\n'
    LEGEND=${LEGEND}${__MANIFEST_INFO_CONTENT_ENCRYPTION}': - Content encryption\n'
    LEGEND=${LEGEND}${__MANIFEST_INFO_OPEN}': - Open (without encryption)\n'
    LEGEND=${LEGEND}${__MANIFEST_INFO_UNKNOWN}': - Looks like encrypted but not with master key\n'

    if [ -n "$(which column)" ]; then
        echo -e ${LEGEND} | column --table -s ':'  --table-columns TYPE
    else
        echo -e ${LEGEND}
    fi
}

__verbose_log()
{
    local OPT_VERBOSE=$1
    if ((OPT_VERBOSE)); then
        shift
        log $@
    fi
}

__get_default_archive_name()
{
    local RESULT_NAME=
    if [ -n "${SH_TOOLS_ID}" ]; then
        RESULT_NAME=${SH_TOOLS_ID}
    else
        RESULT_NAME=${USER}
        if [ ! -n "${USER}" ]; then
            RESULT_NAME=my
        fi

        if (( ${#USER} > 5 )); then
            RESULT_NAME=${USER:0:5}
        fi
    fi
    RESULT_NAME=${RESULT_NAME}.$(date '+%Y-%m-%d_%H-%M')
    echo ${RESULT_NAME}
}

__decrypt_secret_file()
{
    set +o functrace

    local SECRET_FILE=$1
    local MASTER_PASSPHRASE=$2
    declare -n SECRET_FILE_INFO=$3

    local FILE_DIR=$(dirname ${SECRET_FILE})
    local SECRET_FILE_NAME=$(basename ${SECRET_FILE})
    local FILE_NAME=${SECRET_FILE_NAME}
    local MANIFEST_INFO_MARK=$__MANIFEST_INFO_OPEN
    local ENCRYPTED_NAME=
    local ENCRYPTED_CONTENT=
    local DECRYPTION_ERROR=

    check_file_totally_encrypted ${SECRET_FILE} __ENCRYPTED_NAME __ENCRYPTED_CONTENT
    ENCRYPTED_NAME=${__ENCRYPTED_NAME}
    __ENCRYPTED_NAME=
    ENCRYPTED_CONTENT=$__ENCRYPTED_CONTENT
    __ENCRYPTED_CONTENT=
    if (( ENCRYPTED_CONTENT )); then
        MANIFEST_INFO_MARK=$__MANIFEST_INFO_CONTENT_ENCRYPTION
        if [ -n "$ENCRYPTED_NAME" ]; then
            decrypt_data_with_passphrase ${ENCRYPTED_NAME} "${MASTER_PASSPHRASE}" __DECRYPTED_RESULT
            FILE_NAME=${__DECRYPTED_RESULT}
            __DECRYPTED_RESULT=
            if [ -n "${FILE_NAME}" ]; then
                decrypt_name ${SECRET_FILE} ${MASTER_PASSPHRASE} 0 __DECRYPTION_ERROR
                DECRYPTION_ERROR=$__DECRYPTION_ERROR
                __DECRYPTION_ERROR=
                if [ -z $DECRYPTION_ERROR ]; then
                    MANIFEST_INFO_MARK=$__MANIFEST_INFO_FULL_ENCRYPTION
                fi
            else
                DECRYPTION_ERROR=1
            fi
        fi

        if [[ -z $ENCRYPTED_NAME || -n "${DECRYPTION_ERROR}" ]]; then
            FILE_NAME=$(restore_name ${FILE_NAME})
        fi

        if [ -z $DECRYPTION_ERROR ]; then
            SECRET_FILE=$(crypted_name ${FILE_DIR}/${FILE_NAME})
            decrypt_file ${SECRET_FILE} ${MASTER_PASSPHRASE} __DECRYPTION_ERROR
            DECRYPTION_ERROR=$__DECRYPTION_ERROR
            __DECRYPTION_ERROR=
        fi

        if (( DECRYPTION_ERROR )); then
            MANIFEST_INFO_MARK=$__MANIFEST_INFO_UNKNOWN
            FILE_NAME=$(crypted_name ${FILE_NAME})
        fi
    fi
    
    SECRET_FILE_INFO=$(echo -ne "${FILE_DIR}\t${FILE_NAME}\t$MANIFEST_INFO_MARK")
}

__backup()
{
    set +o functrace

    local ARCHIVE_FILE=
    local BACKUP_FOLDER=${1}
    local ARCHIVE_NAME=${2}

    if [ ! -d ${BACKUP_FOLDER} ]; then
        print_error "Invalid backup folder \"${BACKUP_FOLDER}\"!"
        exit 1
    fi

    if [ -z ${ARCHIVE_NAME} ]; then
        ARCHIVE_NAME=$(__get_default_archive_name)
    fi

    if [ ! -d ${SH_TOOLS_DATA_DIR_PATH} ]; then
        print_error "Invalid source folder!"
        exit 1
    fi

    BACKUP_FOLDER=$(get_realpath ${BACKUP_FOLDER})
    local TMP_FOLDER=${BACKUP_FOLDER}/${ARCHIVE_NAME}
    local OVEWRITE_ARCHIVE=
    if (( ZIP_VAULT )); then
        OVEWRITE_ARCHIVE=${TMP_FOLDER}.${__ZIP_EXT}
    else
        OVEWRITE_ARCHIVE=$(crypted_name ${TMP_FOLDER}.${__TAR_EXT})
    fi
    if [[ -n "${OVEWRITE_ARCHIVE}" && -f ${OVEWRITE_ARCHIVE} ]]; then
        local OPT_OVERWRITE=$OPT_FORCE
        if [ -z $OPT_OVERWRITE ]; then
            if ((NOT_INTERACTIVE)); then
                OPT_OVERWRITE=1
            fi
        fi
        if [ -z $OPT_OVERWRITE ]; then
            answer_no "$(emoji $EMOJI_ID_16_DANGEROUS) Target archive name already exists. Do you want to overwrite this file?" __YES_RESULT
            OPT_OVERWRITE=$__YES_RESULT
            __YES_RESULT=
            if [ -z ${OPT_OVERWRITE} ]; then
                exit 1
            fi
        fi
        rm -f ${OVEWRITE_ARCHIVE}   
    fi

    rm -rf ${TMP_FOLDER}

    __verbose_log $OPT_VERBOSE "Copy data files as is"

    # The main restriction for this implementation 
    # to prevent any changing in source data folder 
    # but only in target backup folder

    local CP_OPS=
    if ((OPT_VERBOSE)); then
        CP_OPS="-v"
    fi
    cp ${CP_OPS} -r ${SH_TOOLS_DATA_DIR_PATH} ${TMP_FOLDER}

    __verbose_log $OPT_VERBOSE "Decrypt data files"

    # Just in case to protect from 'obtain master key' implementation influence, 
    # but not necessary to change
    local SAVE_MASTER_KEY=${SH_TOOLS_MASTER_KEY_PATH}
    local TMP_MASTER_KEY=${TMP_FOLDER}/.master
    SH_TOOLS_MASTER_KEY_PATH=${TMP_MASTER_KEY}
    obtain_master_key __MASTER_PASSPHRASE "${CLI_PASSPHRASE}"
    SH_TOOLS_MASTER_KEY_PATH=${SAVE_MASTER_KEY}
    if [ -z ${__MASTER_PASSPHRASE} ]; then
        print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid master key!"
        rm -rf ${TMP_FOLDER}
        exit 1
    fi
    local MASTER_PASSPHRASE=$__MASTER_PASSPHRASE
    __MASTER_PASSPHRASE=

    pushd ${TMP_FOLDER} > /dev/null
    DATA_FILES=()
    local OLD_IFS=${IFS}
    while IFS=  read -r -d $'\0'; do
        DATA_FILES+=("$REPLY")
    done < <(find . -type f -print0)
    IFS=${OLD_IFS}
    local MANIFEST_FILE=${__MANIFEST_FILE_NAME}
    if [ -e ${MANIFEST_FILE} ]; then
        print_error "Manifest file conflict!"
        popd > /dev/null
        rm -rf ${TMP_FOLDER}
        exit 1
    fi
    local DATA_FILES_IDX=0
    local DATA_FILES_SZ=${#DATA_FILES[@]}
    for (( ;DATA_FILES_IDX<${DATA_FILES_SZ}; DATA_FILES_IDX++ ));
    do
        local DATA_FILE=${DATA_FILES[$DATA_FILES_IDX]}
        if [ $(crypted_name ${TMP_MASTER_KEY}) != $(get_realpath ${DATA_FILE}) ]; then
            set -o functrace
            __decrypt_secret_file "${DATA_FILE}" ${MASTER_PASSPHRASE} DATA_FILE_INFO
            if (( OPT_VERBOSE )); then
                echo $DATA_FILE_INFO |tee -a $MANIFEST_FILE
            else
                echo $DATA_FILE_INFO >> $MANIFEST_FILE
            fi
            DATA_FILE_INFO=
        else
            rm -f ${DATA_FILE}
        fi
    done

    cd ..
    
    __verbose_log $OPT_VERBOSE "Create data archive"

    if [ ! -d ${ARCHIVE_NAME} ]; then
        print_error "Invalid archive folder!"
        rm -rf ${ARCHIVE_NAME}
        exit 1
    fi

    ARCHIVE_FILE=${ARCHIVE_NAME}.${__TAR_EXT}
    rm -rf ${ARCHIVE_FILE}

    local TAR_OPS=
    if ((OPT_VERBOSE)); then
        TAR_OPS="v"
    fi
    tar czf${TAR_OPS} ${ARCHIVE_FILE} ${ARCHIVE_NAME}

    cleanup_secret_folder ${ARCHIVE_NAME} 1

    if [ ! -f ${ARCHIVE_FILE} ]; then
        print_error "Can't create archive!"
        exit 1
    fi

    __verbose_log $OPT_VERBOSE "Encrypt archive"

    echo "$(emoji $EMOJI_ID_16_GOLD_KEY) Encrypt ${ARCHIVE_NAME}:"

    if (( ZIP_VAULT )); then
        local SECRET_FILE=${ARCHIVE_NAME}.${__KEY_EXT}
        create_secret_file ${SECRET_FILE} __PASSPHRASE
        if [ -z ${__PASSPHRASE} ]; then
            rm -f ${SECRET_FILE}
        fi
    else
        if [ -n "${KEY_FILE_PATH}" ]; then
            get_decryption_with_singleline_compliance ${KEY_FILE_PATH} __PASSPHRASE
        else    
            create_passphrase __PASSPHRASE
        fi
    fi

    if [ -n "${__PASSPHRASE}" ]; then
        encrypt_file ${ARCHIVE_FILE} "${__PASSPHRASE}"
        __PASSPHRASE=
    else
        cleanup_secret_file ${ARCHIVE_FILE}
        exit 1
    fi

    if (( ZIP_VAULT )); then
        __verbose_log $OPT_VERBOSE "Create vault archive"

        ansible-vault encrypt ${SECRET_FILE} 2>/dev/null
        if [ $? -ne 0 ]; then
            print_error "Can't encrypt vault key!"
            cleanup_secret_file ${SECRET_FILE}
            rm -rf ${ARCHIVE_NAME}.*
            exit 1
        fi

        local ZIP_ARCHIVE_FILE=${ARCHIVE_NAME}.${__ZIP_EXT}

        local ZIP_OPS=
        if ((!OPT_VERBOSE)); then
            ZIP_OPS="-qq"
        fi
        zip ${ZIP_OPS} -m ${ZIP_ARCHIVE_FILE} ${ARCHIVE_NAME}.*
        if [ $? -ne 0 ]; then
            print_error "Can't create ZIP archive!"
            cleanup_secret_file ${SECRET_FILE}
            rm -rf ${ARCHIVE_NAME}.*
            exit 1
        fi
    fi

    popd > /dev/null    
}

__restore()
{
    set +o functrace

    local ARCHIVE_FILE=${1}

    if [ ! -f ${ARCHIVE_FILE} ]; then
        ARCHIVE_FILE=$(crypted_name ${ARCHIVE_FILE})
    fi

    if [ ! -f ${ARCHIVE_FILE} ]; then
        print_error "Invalid archive path!"
        exit 1
    fi

    if (( MODE_RESTORE )); then
        if [[ -f ${SH_TOOLS_MASTER_KEY_PATH} || -f $(crypted_name ${SH_TOOLS_MASTER_KEY_PATH}) ]]; then
            local OPT_OVERWRITE=$OPT_FORCE
            if [ -z $OPT_OVERWRITE ]; then
                if ((NOT_INTERACTIVE)); then
                    OPT_OVERWRITE=1
                fi
            fi
            if [ -z $OPT_OVERWRITE ]; then
                answer_no "$(emoji $EMOJI_ID_16_DANGEROUS) Encrypted data files already exist. Do you want to overwrite this data?" __YES_RESULT
                OPT_OVERWRITE=$__YES_RESULT
                __YES_RESULT=
                if [ -z ${OPT_OVERWRITE} ]; then
                    exit 1
                fi
            fi
        fi
    fi

    local BACKUP_FOLDER=$(dirname ${ARCHIVE_FILE})
    ARCHIVE_FILE=$(basename ${ARCHIVE_FILE})

    pushd ${BACKUP_FOLDER} > /dev/null

    local TMP_FOLDER=
    if ((ZIP_VAULT)); then
        __verbose_log $OPT_VERBOSE "Extract vault files"

        local EXT=$(get_file_extention ${ARCHIVE_FILE})
        if [ ${EXT} != $__ZIP_EXT ]; then
            print_error "ZIP archive is required!"
            exit 1
        fi
        local ARCHIVE_NAME=${ARCHIVE_FILE:0:-$((${#__ZIP_EXT}+1))}
        TMP_FOLDER=${ARCHIVE_NAME}
        mkdir ${TMP_FOLDER}
        local ZIP_OPS=
        if ((!OPT_VERBOSE)); then
            ZIP_OPS="-qq"
        fi
        unzip ${ZIP_OPS} -d ${TMP_FOLDER} ${ARCHIVE_FILE}
        if [ $? -ne 0 ]; then
            print_error "Can't unpack ZIP archive!"
            rm -rf ${TMP_FOLDER}
            exit 1
        fi
        popd > /dev/null
        pushd ${BACKUP_FOLDER}/${TMP_FOLDER} > /dev/null

        ARCHIVE_FILE=$(crypted_name ${ARCHIVE_NAME}.${__TAR_EXT})
        if [ ! -f ${ARCHIVE_FILE} ]; then
            print_error "Invalid ZIP archive!"
            rm -rf ${BACKUP_FOLDER}/${TMP_FOLDER}
            exit 1
        fi
    fi

    local ENCRYPTED_NAME=
    local ENCRYPTED_CONTENT=
    local DECRYPTION_ERROR=

    check_file_totally_encrypted ${ARCHIVE_FILE} __ENCRYPTED_NAME __ENCRYPTED_CONTENT
    ENCRYPTED_NAME=${__ENCRYPTED_NAME}
    __ENCRYPTED_NAME=
    ENCRYPTED_CONTENT=${__ENCRYPTED_CONTENT}
    __ENCRYPTED_CONTENT=
    if (( ENCRYPTED_CONTENT )); then
        __verbose_log $OPT_VERBOSE "Decrypt archive"
        if (( ZIP_VAULT )); then
            local SECRET_FILE=${ARCHIVE_NAME}.${__KEY_EXT}
            if [ ! -f ${SECRET_FILE} ]; then
                print_error "Invalid ZIP archive!"
                rm -rf ${BACKUP_FOLDER}/${TMP_FOLDER}
                exit 1
            fi

            ansible-vault decrypt ${SECRET_FILE}
            if [ $? -ne 0 ]; then
                print_error "Can't decrypt vault key!"
                # Files could become secret here 
                cleanup_secret_folder ${BACKUP_FOLDER}/${TMP_FOLDER}
                exit 1
            fi

            get_decryption_with_singleline_compliance ${SECRET_FILE} __PASSPHRASE
            cleanup_secret_file ${SECRET_FILE} 1
            if [ -z ${__PASSPHRASE} ]; then
                print_error "Can't decrypt key!"
                cleanup_secret_folder ${BACKUP_FOLDER}/${TMP_FOLDER}
                exit 1
            fi
        else
            if [ -n "${KEY_FILE_PATH}" ]; then
                get_decryption_with_singleline_compliance ${KEY_FILE_PATH} __PASSPHRASE
            else
                get_passphrase __PASSPHRASE
            fi
        fi

        if [ -n "${__PASSPHRASE}" ]; then
            decrypt_file ${ARCHIVE_FILE} "${__PASSPHRASE}" __DECRYPTION_ERROR
            DECRYPTION_ERROR=$__DECRYPTION_ERROR
            __DECRYPTION_ERROR=
        else
            exit 1            
        fi

        if [ -z $DECRYPTION_ERROR ]; then
            ARCHIVE_FILE=$(restore_name ${ARCHIVE_FILE})
        else
            print_error "Invalid passphrase!"
            exit 1            
        fi
    fi

    local TAR_OPS=
    if ((OPT_VERBOSE)); then
        TAR_OPS="v"
    fi
    __verbose_log $OPT_VERBOSE "Extract data files"
    TMP_FOLDER=${ARCHIVE_FILE:0:-$((${#__TAR_EXT}+1))}
    mkdir ${TMP_FOLDER}
    tar xf${TAR_OPS} ${ARCHIVE_FILE} -C ${TMP_FOLDER} 
    if (( ENCRYPTED_CONTENT )); then
        if ((ZIP_VAULT)); then
            cleanup_secret_file ${ARCHIVE_FILE} 1
        else
            encrypt_file ${ARCHIVE_FILE} "${__PASSPHRASE}"
        fi
        __PASSPHRASE=
    fi

    local UNPACKED_ARCHIVE_DIR=$(find ${TMP_FOLDER} -maxdepth 1 -type d|tail -n 1)
    if [ ! -d ${UNPACKED_ARCHIVE_DIR} ]; then
        cleanup_secret_folder ${BACKUP_FOLDER}/${TMP_FOLDER}
        print_error "Archive folder not found!"
        exit 1
    fi

    __verbose_log $OPT_VERBOSE "Parse manifest"

    local MANIFEST_FILE=${UNPACKED_ARCHIVE_DIR}/${__MANIFEST_FILE_NAME}
    if [ ! -f ${MANIFEST_FILE} ]; then
        cleanup_secret_folder ${BACKUP_FOLDER}/${TMP_FOLDER}
        print_error "Manifest file not found!"
        exit 1
    fi

    if (( MODE_RESTORE )); then
        local SAVE_MASTER_KEY=${SH_TOOLS_MASTER_KEY_PATH}
        local TMP_MASTER_KEY=${UNPACKED_ARCHIVE_DIR}/.master
        SH_TOOLS_MASTER_KEY_PATH=${TMP_MASTER_KEY}
        if [ -z ${CLI_PASSPHRASE} ]; then
            obtain_master_key __MASTER_PASSPHRASE
        else
            create_master_key "${CLI_PASSPHRASE}" __MASTER_PASSPHRASE
        fi
        SH_TOOLS_MASTER_KEY_PATH=${SAVE_MASTER_KEY}
        if [ -z ${__MASTER_PASSPHRASE} ]; then
            cleanup_secret_folder ${BACKUP_FOLDER}/${TMP_FOLDER}
            print_error "($(basename ${BASH_SOURCE}):${LINENO}) Invalid master key!"
            exit 1
        fi
        local MASTER_PASSPHRASE=$__MASTER_PASSPHRASE
        __MASTER_PASSPHRASE=

        local MANIFEST_LN=
        while read -r MANIFEST_LN; do
            local MANIFEST=(${MANIFEST_LN})
            local MANIFEST_LEN=${#MANIFEST[@]}
            if ((MANIFEST_LEN < 3)); then continue; fi

            local MANIFEST_DIR=${MANIFEST[0]}
            local MANIFEST_F=${MANIFEST[1]}
            local MANIFEST_CMD=${MANIFEST[2]}
            local MANIFEST_F_PATH=$(get_realpath ${UNPACKED_ARCHIVE_DIR}/${MANIFEST_DIR}/${MANIFEST_F})

            if (( OPT_VERBOSE )); then
                echo -n "${MANIFEST_LN}"
            fi

            if [ ! -f ${MANIFEST_F_PATH} ]; then
                if (( OPT_VERBOSE )); then
                    echo " - FAILED"
                fi   
                continue         
            fi

            if [[ ${MANIFEST_CMD} == ${__MANIFEST_INFO_CONTENT_ENCRYPTION} || ${MANIFEST_CMD} == ${__MANIFEST_INFO_FULL_ENCRYPTION} ]]; then
                encrypt_file ${MANIFEST_F_PATH} ${MASTER_PASSPHRASE}
            fi
            if [ ${MANIFEST_CMD} == ${__MANIFEST_INFO_FULL_ENCRYPTION} ]; then
                encrypt_name $(crypted_name ${MANIFEST_F_PATH}) ${MASTER_PASSPHRASE}
            fi

            if (( OPT_VERBOSE )); then
                echo " - OK"      
            fi
        done <${MANIFEST_FILE}

        cleanup_secret_file ${MANIFEST_FILE} 1

        __verbose_log $OPT_VERBOSE "Install data files"

        # Dangerous two commands here!
        rm -rf ${SH_TOOLS_DATA_DIR_PATH}
        mv ${UNPACKED_ARCHIVE_DIR} ${SH_TOOLS_DATA_DIR_PATH}
        # Remove empty folder
        rm -rf ${TMP_FOLDER}

    elif (( MODE_MANIFEST )); then # MODE_RESTORE
        echo
        __show_legend
        echo
        if [ -n "$(which column)" ]; then
            cat ${MANIFEST_FILE} | column --table --table-columns DIR,FILE,TYPE
        else
            cat ${MANIFEST_FILE}
        fi

        cleanup_secret_folder ${BACKUP_FOLDER}/${TMP_FOLDER} 1 
    fi # MODE_MANIFEST

    popd > /dev/null    
}

main()
{
    set +o functrace
    
    if [ -z $1 ]; then
        __show_help
        exit 0
    fi

    # Public options here
    MODE_RESTORE=
    MODE_MANIFEST=
    OPT_FORCE=
    OPT_VERBOSE=0
    CLI_PASSPHRASE=
    NOT_INTERACTIVE=
    ZIP_VAULT=
    KEY_FILE_PATH=
    while getopts ':P:rlvfzZ:h' OPTION; do
    case "$OPTION" in
        P) 
        CLI_PASSPHRASE=$OPTARG
        NOT_INTERACTIVE=1
        ;;
        r)
        MODE_RESTORE=1
        ;;
        l)
        MODE_MANIFEST=1
        ;;
        v)
        OPT_VERBOSE=1
        LIB_CRYPT_OPTION_VERBOSE=1
        ;;
        f)
        OPT_FORCE=1
        ;;
        z) 
        ZIP_VAULT=1
        ;;
        Z) 
        KEY_FILE_PATH=$OPTARG
        ;;
        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    shift "$(($OPTIND - 1))"

    if [ -z ${1} ]; then
        __show_help
        exit 0
    fi

    if (( ZIP_VAULT )); then
        if [ -z $(which ansible-vault) ]; then
            print_error "ansible-vault is required for ZIP mode!"
            exit 1
        fi
        if [ -z $(which unzip) ]; then
            print_error "zip/unzip are required for ZIP mode!"
            exit 1
        fi
    else
        if [[ -n "${KEY_FILE_PATH}" && ! -f ${KEY_FILE_PATH} ]]; then
            print_error "Invalid key file"
            exit 1
        fi
    fi

    init_crypt

    set -o functrace
    if (( MODE_RESTORE || MODE_MANIFEST )); then
        __restore $@
    else
        __backup $@
    fi
}

main $@