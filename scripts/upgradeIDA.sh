#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
source ${CUR_DIR}/scripts/helper/common.sh

function show_help {
    echo -e "\nUsage: deployIDA.sh -i ida_image [-t] [-d] \n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -i  IDA image name"
    echo "      For example: registry_url/ida:version"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        i)  IMAGEREGISTRY=$OPTARG
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

# fix issue of field is immutable for field "type"
TLS_SECRET=$(oc get secret | grep ida-web-tls | awk '{print$1}')
if [ -z ${TLS_SECRET} ]; then
    SECRET_TYPE=$(oc get secret $TLS_SECRET -o jsonpath='{.type}')
    if [[ $SECRET_TYPE == "Opaque" ]]; then
        ${KUBE_CMD} delete secret $TLS_SECRET
    fi
fi

# Change the IDA image
${KUBE_CMD} patch --type=merge idacluster/idadeploy -p '{"spec": {"idaWeb": {"image": "'$IMAGEREGISTRY'"}}}'


sleep 10

IDA_DEPLOYMENT_NAME=$(${KUBE_CMD} get deployment | grep ida-web | head -n 1 | awk '{print$1}')
ROLLOUT_STATUS_CMD="${KUBE_CMD} rollout status deployment/$IDA_DEPLOYMENT_NAME"
until $ROLLOUT_STATUS_CMD; do
  $ROLLOUT_STATUS_CMD
done

echo -e "\033[32mIDA Instance has been successfully upgraded. \033[0m"
