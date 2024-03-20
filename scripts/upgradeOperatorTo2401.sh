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

oc scale deployment/ida-operator --replicas=0

oc delete rolebinding/ida-operator
oc delete role/ida-operator

oc apply -f ./descriptors/cluster/cluster-role.yaml
oc apply -f ./descriptors/ida-operators-edit.yaml

# Change the operator image
RELEASE=$(echo $IMAGEREGISTRY  | rev | cut -d':' -f 1 | rev)
oc set image deployment/ida-operator operator=$IMAGEREGISTRY

#update label
oc label serviceaccount/ida-operator release=$RELEASE --overwrite

IDA_OPERATOR_ROLEBINDING_NAME=$(oc get clusterrolebinding | grep ida-operator | head -n 1 | awk '{print$1}')
oc label clusterrolebinding/$IDA_OPERATOR_ROLEBINDING_NAME release=$RELEASE --overwrite

oc label crd/idaclusters.sdc.ibm.com release=$RELEASE --overwrite
oc label deployment/ida-operator release=$RELEASE --overwrite

oc scale deployment/ida-operator --replicas=1

echo -e "\033[32mIDA Operator has been upgraded. Monitor the pod status with 'oc get pods -w'.\033[0m"