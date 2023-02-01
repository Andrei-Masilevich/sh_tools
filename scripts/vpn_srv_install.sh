#!/bin/bash
#
# To manage OpenVPN server via SSH
#

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_vpn.sh

USAGE_HELP="Usage $(basename ${BASH_SOURCE}) SSH_HOST [SSH_USER] [SSH_PORT]"
if [ $# -eq 0 ]; then
    echo "${USAGE_HELP}"
    exit 1
fi

init_sudo

if [ -z $2 ]; then
    CONNECTION_STR=$1
elif [ -z $3 ]; then
    CONNECTION_STR=$2@$1
elif [[ "$3" =~ ^[0-9]+$ && "$3" -le 65535 ]]; then
    CONNECTION_STR=$2@$1:$3
else
    echo "Invalid port value. ${USAGE_HELP}"
    exit 1
fi

client_setup_menu client VPN_IMPL_FUNC CLIENT_CONFIG_NAME CLIENT_CONFIG_PATH

if [[ -n "$CLIENT_CONFIG_NAME" && -n "$CLIENT_CONFIG_PATH" ]]; then

    echo

    answer_yes "Create new VPN configuration for ${CLIENT_CONFIG_PATH}?" __YES_RESULT
    if (( $__YES_RESULT )); then

        rm -f ${CLIENT_CONFIG_PATH}
        CRYPTED_CLIENT_CONFIG_PATH=$(crypted_name ${CLIENT_CONFIG_PATH})
        rm -f ${CRYPTED_CLIENT_CONFIG_PATH}

        REMOTE_TMP_PATH="/tmp/.$(random_str).XXXXXX"
        REMOTE_TMP_PATH=$(ssh ${CONNECTION_STR} "echo $(mktemp $REMOTE_TMP_PATH)")

        REMOTE_CMD="\$(declare -f $VPN_IMPL_FUNC); \
                    $VPN_IMPL_FUNC $CLIENT_CONFIG_NAME $REMOTE_TMP_PATH"

        ssh -t ssh://${CONNECTION_STR} "$(declare -f $VPN_IMPL_FUNC); sudo bash -c \"${REMOTE_CMD}\""

        RES_=$?  
        clear

        if [ $RES_ -eq 0 ]; then
            scp scp://${CONNECTION_STR}/${REMOTE_TMP_PATH} ${CLIENT_CONFIG_PATH} 2>/dev/null
            RES_=$?
            clear
        fi

        if [[ $RES_ -eq 0 && -f ${CLIENT_CONFIG_PATH} ]]; then

            REMOTE_CMD="[ \$(which shred) = '' ] || shred -fuzn 2 $REMOTE_TMP_PATH 2>/dev/null; \
                        rm -f $REMOTE_TMP_PATH 2>/dev/null "

            ssh -t ssh://${CONNECTION_STR} "sudo bash -c \"${REMOTE_CMD}\""

            if [ ! ${HOME} == ${USER_HOME} ]; then
                chown $LOGIN:$LOGIN ${CLIENT_CONFIG_PATH}
            fi

            clear
            
            echo
            echo "Done. Configuration file saved to:"
            echo ${CLIENT_CONFIG_PATH}
            echo "Use vpn-cli scripts to manage vpn client"
            echo
        fi
    fi

else

    REMOTE_CMD="\$(declare -f $VPN_IMPL_FUNC); \
                $VPN_IMPL_FUNC"

    ssh -t ssh://${CONNECTION_STR} "$(declare -f $VPN_IMPL_FUNC); sudo bash -c \"${REMOTE_CMD}\""

fi