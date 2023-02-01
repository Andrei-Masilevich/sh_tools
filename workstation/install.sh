#!/bin/bash

THIS_DIR="$(cd $(dirname ${BASH_SOURCE}) && pwd)"
source $THIS_DIR/../scripts/lib_common.sh

function __install_package()
{
    local PACKAGE_NAME=$1

    if [ -z $PACKAGE_NAME ]; then
        exit 1
    fi

    if [[ -z $(which lsb_release) || -z $(which apt) ]]; then
        print_error $(echo -e "Unsupported platform to automate installation of required component!\n" \
                              "Install '$PACKAGE_NAME' manually.")
        exit 1
    else
        log "Install '$PACKAGE_NAME'"
        apt install -y $PACKAGE_NAME
    fi
}

__INSTALL_TMP_FILES=

function __cleanup_intall_tmp()
{
    if [ -n "${__INSTALL_TMP_FILES}" ]; then
        rm -f ${__INSTALL_TMP_FILES}
        __INSTALL_TMP_FILES=
    fi
}

trap "__cleanup_intall_tmp" EXIT

__INSTALL_SHARE_URL=

function __init_share_url()
{
    local SHARE_URL=$1
    if [ -z $SHARE_URL ]; then
        print_error "$(basename ${BASH_SOURCE}):${LINENO} URL is requited"
        exit 1 
    fi

    if [ -z $(which curl) ]; then
        print_error "$(basename ${BASH_SOURCE}):${LINENO} Curl is requited"
        exit 1     
    fi

    local SKIP_CERT_ERROR='-k'

    # Check URL for access
    local HTTP_CODE_RESPONSE=$(curl --write-out '%{http_code}' -sSL ${SKIP_CERT_ERROR} --head --output /dev/null ${SHARE_URL})
    if (( HTTP_CODE_RESPONSE != 200 )); then
        print_error "Invalid URL. Response code: ${HTTP_CODE_RESPONSE}. URL could have obsolete. Get the new one."
        exit 1     
    fi

    # Check URL for valid path (ex. /latest). ZIP type is expected
    local FILE_TYPE=$(curl -sSL ${SKIP_CERT_ERROR} --head ${SHARE_URL}|fgrep 'Content-Description'|cut -d ' ' -f 2)
    if [[ -z  ${FILE_TYPE} || ! "${FILE_TYPE}" =~ zip ]]; then
        print_error "Invalid URL. Bad path. URL could have obsolete. Get the new one."
        exit 1     
    fi

    # Store validated URL
    __INSTALL_SHARE_URL=${SHARE_URL}
}

function __download_from_share_url()
{
    local ENTITY=$1
    if [[ ! ${ENTITY} =~ key|encrypted ]]; then
        print_error "$(basename ${BASH_SOURCE}):${LINENO} Entity (key|encrypted) is requited"
        exit 1
    fi

    local EXT=$(echo -n $2)
    if [[ -z ${EXT} ]]; then
        print_error "$(basename ${BASH_SOURCE}):${LINENO} Extention is requited"
        exit 1
    fi

    if [ -z $__INSTALL_SHARE_URL ]; then
        print_error "$(basename ${BASH_SOURCE}):${LINENO} URL is requited"
        exit 1 
    fi

    local SHARE_URL=${__INSTALL_SHARE_URL}
    declare -n TMP_FILE=$3

    local TMP_FILE_+=$(mktemp /tmp/$(basename $0).XXXXXX.$EXT)
    __INSTALL_TMP_FILES="${__INSTALL_TMP_FILES} ${TMP_FILE_}"

    local HTTP_CODE_RESPONSE=$(curl --write-out '%{http_code}' -sSL ${SKIP_CERT_ERROR} ${SHARE_URL}/${ENTITY} -o ${TMP_FILE_})
    if (( HTTP_CODE_RESPONSE != 200 )); then
        print_error "Downloading error. Response code: ${HTTP_CODE_RESPONSE}. Bad path. URL could have obsolete. Get the new one."
        exit 1
    fi

    local DOWNLOADED_SZ=$(stat -c %s "${TMP_FILE_}")
    if (( DOWNLOADED_SZ < 1 )); then
        print_error "Empty file. Archive could be invalid."
        exit 1    
    fi

    TMP_FILE=${TMP_FILE_}
}

function get_converted_path()
{
    # Input string could include a part of the welcome message 
    # (because of the -i flag of sudo)
    cat <<% |python3
in_path="${1}"
home_path="${2}"
if any(in_path):
    in_path=''.join(c for c in in_path if c.isprintable())
    # Anyway printable part can be invalid.
    if any(home_path):
        # It's supposed that path includes home folder.
        pos = in_path.find(home_path)
        if pos >= 0:
            in_path=in_path[pos:]
            print(in_path)
%
}

function main()
{
    local BASE_INPUT=${1}
    local KEY_FILE=${2}
    local DATA_ARGS=
    local SHARE_URL=

    if [ -n "${BASE_INPUT}" ]; then
        if [[ ${BASE_INPUT:0:8} == 'https://' || ${BASE_INPUT:0:7} == 'http://' ]]; then
            SHARE_URL=${BASE_INPUT}
        else
            local DATA_FILE=${BASE_INPUT}
            if [ ! -f ${DATA_FILE} ]; then
                print_error "Data file is not found"
                exit 1
            fi
            DATA_ARGS="install_data_file=\"${DATA_FILE}\""
        fi
    fi 

    if [ -z ${SHARE_URL} ]; then
        if [ -n "${KEY_FILE}" ]; then
            if [ ! -f ${KEY_FILE} ]; then
                print_error "Key file is not found"
                exit 1
            fi
            DATA_ARGS="${DATA_ARGS} install_key_file=\"${KEY_FILE}\""
        fi
    fi

    if [ $EUID -ne 0 ]; then
        print_error "Super user required!"
        exit 1
    else
        local LOGIN=$(who | awk '{print $1; exit}')
        local UNSUDO="sudo -u ${LOGIN}"
        local LOGIN_HOME=$(getent passwd "${LOGIN}"|cut -d: -f6)
    fi

    if [ -z $(which python3) ]; then
        __install_package python3
    fi

    if [ -z $(which pip) ]; then
        __install_package python3-pip
    fi

    local ANSIBLE=$($UNSUDO -i which ansible-playbook|tail -n 1)
    ANSIBLE=$(get_converted_path ${ANSIBLE} ${LOGIN_HOME})
    if [ -z $ANSIBLE ]; then
        $UNSUDO python3 -m pip install --user ansible
        ANSIBLE=$($UNSUDO -i which ansible-playbook|tail -n 1)
        ANSIBLE=$(get_converted_path ${ANSIBLE} ${LOGIN_HOME})
    fi

    if [ -z $ANSIBLE ]; then
        print_error "Ansible is required!"
        exit 1
    fi

    if [ -n "${SHARE_URL}" ]; then
        local ANSIBLE_VAULT=$(dirname ${ANSIBLE})/ansible-vault
        if [ ! -f ${ANSIBLE_VAULT} ]; then
            print_error "Ansible vault is required!"
            exit 1
        fi

        __init_share_url ${SHARE_URL}
        __download_from_share_url key key TMP_ENCRYPTED_KEY_FILE

        local TMP_KEY_FILE=${TMP_ENCRYPTED_KEY_FILE}

        PYTHONUSERBASE=/home/${LOGIN}/.local ${ANSIBLE_VAULT} decrypt ${TMP_KEY_FILE}
        if [ $? -ne 0 ]; then
            exit 1
        fi

        __download_from_share_url encrypted tar.gz.~ TMP_ENCRYPTED_FILE

        chown ${LOGIN}:${LOGIN} ${TMP_ENCRYPTED_FILE}
        chown ${LOGIN}:${LOGIN} ${TMP_KEY_FILE}
        
        DATA_ARGS="install_data_file=\"${TMP_ENCRYPTED_FILE}\""
        DATA_ARGS="${DATA_ARGS} install_key_file=\"${TMP_KEY_FILE}\""
    fi

    local THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)

    log "Start Ansible"
    # This trick (with running by root with PYTHONUSERBASE) 
    # only to prevent entering sudo password again (--ask-become-pass)
    PYTHONUSERBASE=/home/${LOGIN}/.local ${ANSIBLE} \
    --extra-vars "install_regular_user=${LOGIN} ${DATA_ARGS}" ${THIS_DIR}/install.yaml
}

main $@
