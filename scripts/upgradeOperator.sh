#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
PLATFORM_VERSION=""
source ${CUR_DIR}/scripts/helper/common.sh
check_platform_version

function show_help {
    echo -e "\nUsage: upgradeOperator.sh -i operator_image \n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -i  Operator image name"
    echo "      For example: registry_url/ida-operator:version"
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

# Change the operator image
oc set image deployment/ida-operator operator=$IMAGEREGISTRY


echo -e "\033[32mIDA Operator has been upgraded. Monitor the pod status with 'oc get pods -w'.\033[0m"