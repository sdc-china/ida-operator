#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
PLATFORM_VERSION=""
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


# Change the IDA image
oc patch --type=merge idacluster/idadeploy -p '{"spec": {"idaWeb": {"image": "'$IMAGEREGISTRY'"}}}'


sleep 10

IDA_DEPLOYMENT_NAME=$(oc get deployment | grep ida-web | head -n 1 | awk '{print$1}')
ROLLOUT_STATUS_CMD="oc rollout status deployment/$IDA_DEPLOYMENT_NAME"
until $ROLLOUT_STATUS_CMD; do
  $ROLLOUT_STATUS_CMD
done

echo -e "\033[32mIDA Instance has been successfully upgraded. \033[0m"
