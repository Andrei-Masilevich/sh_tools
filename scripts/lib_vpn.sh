#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_crypt.sh

__VPN_SUB_DIR=vpn

function client_setup_menu()
{
    if [ $# -le 2 ]; then
        print_error "Invalid arguments"
        exit 1
    fi

    if [ -z ${SH_TOOLS_DATA_DIR_PATH} ]; then
        print_error "Environment has not been set!"
        exit 1
    fi

    local DEFAULT_CONFIG_NAME=$1
    declare -n RESULT_VPN_IMPL_FUNC=$2
    declare -n RESULT_CONFIG_NAME=$3
    declare -n RESULT_CLIENT_CONFIG_PATH=$4

    local VPN_CONFIG_DIR=${SH_TOOLS_DATA_DIR_PATH}/${__VPN_SUB_DIR}

    echo
    echo "Select VPN type:"
    echo "   1) OpenVPN"
    read -p "Option [1]: " option
    until [[ -z "$option" || "$option" =~ ^[1-2]$ ]]; do
        echo "$option: invalid selection."
        read -p "Option [1]: " option
    done

    [ -z $option ] && option=1

    case "$option" in
        1)
        # OpenVPN specific
        local VPN_IMPL_CONFIG_EXT=ovpn
        RESULT_VPN_IMPL_FUNC=openvpn_install_impl
    ;;
        2)

        # TODO (Other types)
        print_error "Not implemented"
        exit 1
    ;;
    esac

    echo
    echo "Select an action:"
    echo "   1) Create new client"
    echo "   2) Manage server"
    read -p "Option [1]: " option
    until [[ -z "$option" || "$option" =~ ^[1-2]$ ]]; do
        echo "$option: invalid selection."
        read -p "Option [1]: " option
    done

    [ -z $option ] && option=1

    case "$option" in
        1)

    local ACTUAL_HOME=$(normalize_home_path ${HOME})
    local ACTUAL_SECRET_DIR=${VPN_CONFIG_DIR}

    mkdir -p ${ACTUAL_SECRET_DIR}

    local ALL_S=1
    local DFLT_S=1
    echo
    echo "Select protected folder to save client config file:"
    echo "   1) current folder: $(pwd)"
    local CURRENT_FOLDER_S=$ALL_S
    if [ ! "$(pwd)" == ${ACTUAL_SECRET_DIR} ]; then
        ALL_S=$[$ALL_S + 1]
        echo "   $ALL_S) vpn-client hidden folder: ${ACTUAL_SECRET_DIR}"
        if [ -d ${ACTUAL_SECRET_DIR} ]; then
            DFLT_S=2
        fi
        local HIDDEN_FOLDER_S=$ALL_S
    fi
    if [ ! "$(pwd)" == "/tmp" ]; then
        ALL_S=$[$ALL_S + 1]
        echo "   $ALL_S) temporary folder: /tmp"
        local TEMPORARY_FOLDER_S=$ALL_S
    fi
    if [ ! "$(pwd)" == ${ACTUAL_HOME} ]; then
        ALL_S=$[$ALL_S + 1]
        echo "   $ALL_S) home folder: ${ACTUAL_HOME}"
        local HOME_FOLDER_S=$ALL_S
    fi

    read -p "Protected folder [$DFLT_S]: " F_SELECTION
    until [[ -z "$F_SELECTION" || "$F_SELECTION" =~ ^[1-$ALL_S]$ ]]; do
        echo "$F_SELECTION: invalid selection."
        read -p "Protected folder [$DFLT_S]: " F_SELECTION
    done

    [ -z "$F_SELECTION" ] && F_SELECTION=$DFLT_S 

    local CLIENT_CONFIG_DIR=$(pwd)
    case "$F_SELECTION" in
        $CURRENT_FOLDER_S)
        ;;
        $HIDDEN_FOLDER_S)
            CLIENT_CONFIG_DIR=${ACTUAL_SECRET_DIR}
            mkdir -p ${CLIENT_CONFIG_DIR} 
        ;;
        $TEMPORARY_FOLDER_S)
            CLIENT_CONFIG_DIR="/tmp"
        ;;
        $HOME_FOLDER_S)
            CLIENT_CONFIG_DIR=${ACTUAL_HOME}
        ;;
    esac

    if [ ! -d ${CLIENT_CONFIG_DIR} ]; then
        print_error "Invalid protected folder. Try to select other"
        exit 1
    fi

    echo
    read -p "Enter client config name [$DEFAULT_CONFIG_NAME]: " CONFIG_NAME
    until [[ -z "$CONFIG_NAME" || "$CONFIG_NAME" =~ ^[A-Za-z0-9_-]+$ ]]; do
        echo "$CONFIG_NAME: invalid name."
        read -p "Enter client config name [$DEFAULT_CONFIG_NAME]: " CONFIG_NAME
    done

    [ -z "$CONFIG_NAME" ] && CONFIG_NAME=$DEFAULT_CONFIG_NAME 

    RESULT_CONFIG_NAME=$CONFIG_NAME
    
    if [ -n "$VPN_IMPL_CONFIG_EXT" ]; then
        if [[ ! "${CONFIG_NAME: -5}" == '.'$VPN_IMPL_CONFIG_EXT ]]; then
            CONFIG_NAME="${CONFIG_NAME}."$VPN_IMPL_CONFIG_EXT
        fi
    fi

    RESULT_CLIENT_CONFIG_PATH=${CLIENT_CONFIG_DIR}/$CONFIG_NAME
    
    ;;
        2)
    ;;
    esac
}

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_vpn_openvpn.sh

