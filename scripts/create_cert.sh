#!/bin/bash

source $(cd $(dirname ${BASH_SOURCE}) && pwd)/lib_crypt.sh
set -o functrace

__CA_DATABASE_FOLDER=ca
__DEFAULT_CA_LIFETIME=36500 # 100 years

# Thank you:
# https://www.golinuxcloud.com/generate-self-signed-certificate-openssl/

__show_help()
{
   echo "Usage $(basename $0) (options) [CA name] [CA host]                           "
   echo "_____________________________________________________________________________"
   echo "Create self-signed certificate                                               "
   echo "_____________________________________________________________________________"
   echo " -s       Show certificate info                                              "
   echo " -k [key path]                                                               "
   echo "          Path to private PEM key of RSA type                                "
   echo "          that is using for signing                                          "
   echo " -d [dir path]                                                               "
   echo "          Path to save new certificates                                      "
   echo "          Default: ${SH_TOOLS_DATA_DIR_PATH}/$__CA_DATABASE_FOLDER           "
   echo " -t [life]                                                                   "
   echo "          Set lifetime for certificate in days.                              "
   echo "          Default: $__DEFAULT_CA_LIFETIME                                    "
   echo " -v  Verbose                                                                 "   
   echo
}

__CA_CNF_SPLITTER='#%>'

__OPT_VERBOSE=

__verbose()
{
    if [ -z $__OPT_VERBOSE ]; then
        echo -n
    else
        echo "$@"
    fi
}

main()
{
    set +o functrace
    init_crypt

    local SIGNING_KEY=
    local CA_DATABASE=${SH_TOOLS_DATA_DIR_PATH}/$__CA_DATABASE_FOLDER
    local CA_LIFETIME=${__DEFAULT_CA_LIFETIME}
    local OPT_SHOW=
    while getopts ':sk:d:t:vh' OPTION; do
    case "$OPTION" in
        s) OPT_SHOW=1;;
        k) SIGNING_KEY=${OPTARG};;
        d) CA_DATABASE=${OPTARG};;
        t) CA_LIFETIME=${OPTARG};;
        v) __OPT_VERBOSE=1;;

        h|?)
        __show_help
        [ $OPTION = h ] && exit 0
        [ $OPTION = ? ] && exit 1
        ;;
    esac
    done

    local OPENSSL=$(find_openssl)
    if [ -z ${OPENSSL} ]; then
        print_error "OpenSSL (openssl) required or it was not properly installed!"
        exit 1
    fi

    if [[ -n "$SIGNING_KEY" && ! -f $SIGNING_KEY ]]; then
        print_error "Invalid signing key!"
        exit 1
    fi

    if [[ ! -d "$CA_DATABASE" ]]; then
        print_error "Invalid CA folder!"
        exit 1
    fi

    if [[ ! $CA_LIFETIME =~ ^[0-9]+$ ]]; then
        print_error "Invalid time format!"
        exit 1
    fi

    shift "$(($OPTIND -1))"

    if [ -z $1 ]; then
        __show_help
        exit 0
    fi
    local CA_NAME=$1
    local CA_HOST=

    local CA_CRT=$CA_DATABASE/${CA_NAME}.crt
    local CA_CRT_WITH_KEY=$CA_DATABASE/${CA_NAME}.crt.PEM

    if (( $OPT_SHOW )); then
        if [ -f $CA_CRT ]; then
            $OPENSSL x509 -subject_hash -noout -in $CA_CRT 2>/dev/null
            if [ $? -eq 0 ]; then
                $OPENSSL x509 -text -in $CA_CRT|head -n 20
                OPT_SHOW=
            fi
        fi
        if (( $OPT_SHOW )); then
            if [ -f $CA_CRT_WITH_KEY ]; then
                $OPENSSL x509 -subject_hash -noout -in $CA_CRT_WITH_KEY 2>/dev/null
                if [ $? -eq 0 ]; then
                    $OPENSSL x509 -text -in $CA_CRT_WITH_KEY|head -n 20
                    OPT_SHOW=
                fi
            fi        
        fi
        if (( $OPT_SHOW )); then
            print_error "Can't find valid certificate with name ${CA_NAME}"
            exit 1
        else
            exit 0
        fi
    else
        CA_HOST=$2

        if [ -z $CA_HOST ]; then
            __show_help
            exit 0
        fi

        if [[ -f $CA_CRT || -f $CA_CRT_WITH_KEY ]]; then
            print_error "Set different name for certificate. ${CA_NAME} - already exists"
            exit 1
        fi

        if [[ -f $(crypted_name $CA_CRT) || -f $(crypted_name $CA_CRT_WITH_KEY) ]]; then
            print_error "Set different name for certificate. Encrypted ${CA_NAME} - already exists"
            exit 1
        fi
    fi

    if [ -z $CA_HOST ]; then
        __show_help
        exit 0
    fi

    local CA_KEY=$CA_DATABASE/__${CA_NAME}.key

    trap "cleanup_secret_file ${CA_KEY}" EXIT

    if [ -z $SIGNING_KEY ]; then
        $OPENSSL genrsa -out "${CA_KEY}" 4096 2>/dev/null
        if [[ $? -eq 0 && -f ${CA_KEY} ]]; then
            SIGNING_KEY=${CA_KEY}
        fi
    else
        $OPENSSL rsa -in $SIGNING_KEY -out ${CA_KEY} 2>/dev/null
        if [[ $? -ne 0 || ! -f ${CA_KEY} ]]; then
            SIGNING_KEY=
        fi
    fi

    if [ -z $SIGNING_KEY ]; then
        print_error "Wrong signing key. RSA key required!"
        exit 1
    fi

    __verbose "$(emoji $EMOJI_ID_16_OK) - CA Signing Key - Done"

    local CA_CNF=$CA_DATABASE/__${CA_NAME}.cnf

    trap "cleanup_secret_file ${CA_KEY}; cleanup_secret_file ${CA_CNF}" EXIT

    truncate -s 0 ${CA_CNF}

    local IN_CNF=
    local LN_=
    while read -r LN_; do
        if [[ "${LN_}" =~ ^${__CA_CNF_SPLITTER}.* ]]; then
            IN_CNF=1
        elif (( $IN_CNF )); then
            if [[ -n "${LN_}" && ${LN_:0:1} != '#' ]]; then
                echo "${LN_}"|sed s+'%CA_HOST%'+${CA_HOST}+g >> ${CA_CNF}
            fi
        fi
    done <${BASH_SOURCE}

    __verbose "$(emoji $EMOJI_ID_16_OK) - CA Request Config - Done"

    local CA_CSR=$CA_DATABASE/__${CA_NAME}.csr

    trap "cleanup_secret_file ${CA_KEY}; cleanup_secret_file ${CA_CNF}; cleanup_secret_file ${CA_CSR}" EXIT

    $OPENSSL req -new -key ${CA_KEY} -keyform PEM \
            -config "${CA_CNF}" -out "${CA_CSR}" 2>/dev/null
    if [[ $? -ne 0 || ! -f ${CA_CSR} ]]; then
        print_error "Failed to create CA Request!"
        exit 1
    fi

    __verbose "$(emoji $EMOJI_ID_16_OK) - CA Request - Done"

    $OPENSSL x509 -req -days $CA_LIFETIME \
        -in "${CA_CSR}" -signkey "${CA_KEY}" -out "${CA_CRT}" 2>/dev/null
    if [[ $? -ne 0 || ! -f ${CA_CRT} ]]; then
        print_error "Failed to create CA Certificate!"
        exit 1
    fi

    __verbose "$(emoji $EMOJI_ID_16_OK) - CA Certificate - Done"

    truncate -s 0 ${CA_CRT_WITH_KEY}

    cat $CA_CRT >> ${CA_CRT_WITH_KEY}
    cat $CA_KEY >> ${CA_CRT_WITH_KEY}

    __verbose "$(emoji $EMOJI_ID_16_OK) - CA Certificate With Key - Done"
}

main $@

exit 0
#
#%> ________________________________________-CA CNF Template:
#
# Creating a self-signed certificate
#

[req]
serial                 = 0
distinguished_name     = req_info
x509_extensions        = v3_ca
prompt                 = no

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Following requisites are fictitious and have nothing to do 
# with the real country, city or organization.
[req_info]
countryName            = JM
stateOrProvinceName    = Kingston
localityName           = Kingston
organizationName       = Freedom
organizationalUnitName = CA
commonName             = %CA_HOST%

[v3_ca]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer:always
basicConstraints       = CA:TRUE
keyUsage               = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign
# Creating a wildcard certificate for common usage
subjectAltName         = DNS:*.net, DNS:*.org
issuerAltName          = issuer:copy
