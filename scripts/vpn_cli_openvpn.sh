#!/bin/bash
#
# To manage OpenVPN client
#

THIS_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)
source $THIS_DIR/lib_vpn.sh
set -o functrace

__DEFAULT_VPN_CONF_NAME=client.ovpn

__show_help()
{
    echo "Usage" $(basename $0) "start|stop [config name]                        "
    echo "_______________________________________________________________________"
    echo "Start/stop connection for VPN client.                                  "
    echo "_______________________________________________________________________"
    echo " [config name]                                                         "
    echo "      VPN client configuration name. Default: $__DEFAULT_VPN_CONF_NAME "
    echo
}

__get_public_ip()
{
    local RESULT_IP=
    if [ -f ${THIS_DIR}/public_ip.sh ]; then
        RESULT_IP=$(. ${THIS_DIR}/public_ip.sh)
    fi
    echo $RESULT_IP
}

main()
{
    set +o functrace
    init_crypt
    
    if [ -z $1 ]; then
        __show_help
        exit 0
    fi

    while getopts ':h' OPTION; do
    case "$OPTION" in

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
        exit 1
    elif [[ ! $1 =~ start|stop ]]; then
        __show_help
        exit 1
    fi

    # local config:
    local VPN_CONF_NAME=$__DEFAULT_VPN_CONF_NAME

    if [ $# -gt 1 ]; then
        VPN_CONF_NAME=$2
        if [[ ! "${VPN_CONF_NAME: -5}" == '.ovpn' ]]; then
            VPN_CONF_NAME="${VPN_CONF_NAME}.ovpn"
        fi
    fi

    local VPN_CONFIG_DIR=${SH_TOOLS_DATA_DIR_PATH}/${__VPN_SUB_DIR}
    local VPN_CONFIG=${VPN_CONFIG_DIR}/${VPN_CONF_NAME}

    init_sudo
    # only to start sudoer's session
    ${SUDO} pwd 1>/dev/null

    if [ "`which openvpn`" = "" ]; then
        answer_yes "OpenVPN client is not found. Install OpenVPN?" __YES_RESULT
        if (( $__YES_RESULT )); then
            ${SUDO} apt install -y openvpn
            if [ $? -ne 0 ]; then
                print_error_ "Can't install OpenVPN automatically"
                print_error_ "You should manually install this to use OpenVPN client features"
                exit 1
            fi
        else
            exit 1
        fi
    fi

    local CRYPTED_VPN_CONFIG=$(crypted_name ${VPN_CONFIG})
    if [[ ! -f ${CRYPTED_VPN_CONFIG} && ! -f ${VPN_CONFIG} ]]; then
        print_error_ "There is no OpenVPN-client config file:"
        print_error_ ${VPN_CONFIG}
        print_error_ "Copy this one to protected folder"
        exit 2
    fi

    local PIDS=`pidof openvpn`
    if [ ! -z ${PIDS} ]; then
        if [ $1 == "start" ]; then
            answer_yes "Restart current OpenVPN session?" __YES_RESULT
            if [ -z $__YES_RESULT ]; then
                exit 0
            fi
        fi
        ${SUDO} kill -s INT ${PIDS}
        if [ $? -eq 0 ]; then
            clear
            echo "OpenVPN stopped"
            echo "Current IP is $(__get_public_ip)"
            if [ -n "$RESTART" ]; then
                echo "Starting new session"
            fi
        else
            print_error "Can't stop current OpenVPN session"
            exit 10
        fi
    fi

    if [ $1 == "start" ]; then
        obtain_master_key __MASTER_PASSPHRASE
        if [ -z ${__MASTER_PASSPHRASE} ]; then
            print_error "Failed to apply master key!"
            exit 1
        fi

        if [ ! -f ${CRYPTED_VPN_CONFIG} ]; then
            encrypt_file ${VPN_CONFIG} ${__MASTER_PASSPHRASE}
        fi

        if [ ! -f ${CRYPTED_VPN_CONFIG} ]; then
            __MASTER_PASSPHRASE=
            print_error "Failed to encript VPN configuration!"
            exit 1
        fi

        decrypt_file ${CRYPTED_VPN_CONFIG} ${__MASTER_PASSPHRASE}
        trap "encrypt_file ${VPN_CONFIG} ${__MASTER_PASSPHRASE}" EXIT
        __MASTER_PASSPHRASE=

        local NOHUP_TMP=$(mktemp /tmp/nohup.out.XXXXXX)
        ${SUDO} nohup openvpn ${VPN_CONFIG} >${NOHUP_TMP} 2>&1 &
        disown
        rm -f ${NOHUP_TMP}
        sleep 2
        local IS_WG_UP=$(ip addr show dev tun0 2>/dev/null)
        if [ -n "${IS_WG_UP}" ]; then
            clear
            echo "OpenVPN started."
            echo "Current IP is $(__get_public_ip)"
        else
            local PIDS=`pidof openvpn`
            if [ ! -z ${PIDS} ]; then
                ${SUDO} kill -9 ${PIDS}
            fi
            print_error "Can't start OpenVPN session for config ${VPN_CONF_NAME}"
            exit 2
        fi
    fi
}

main $@