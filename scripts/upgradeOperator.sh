#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
source ${CUR_DIR}/scripts/helper/common.sh

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

${KUBE_CMD} rollout pause deployment/ida-operator

# Change the operator image
RELEASE=$(echo $IMAGEREGISTRY  | rev | cut -d':' -f 1 | rev)
${KUBE_CMD} set env deployment/ida-operator IDA_OPERATOR_IMAGE=$IMAGEREGISTRY --overwrite 
${KUBE_CMD} set image deployment/ida-operator operator=$IMAGEREGISTRY

#update label
${KUBE_CMD} label serviceaccount/ida-operator release=$RELEASE --overwrite
${KUBE_CMD} label clusterrole/ida-operators-edit release=$RELEASE --overwrite

IDAROLECOUNT=$(${KUBE_CMD} get role/ida-operator | tail -n +2 | wc -l)
if [[ "${IDAROLECOUNT}" == "1" ]];  then
  ${KUBE_CMD} label role/ida-operator release=$RELEASE --overwrite
  ${KUBE_CMD} label rolebinding/ida-operator release=$RELEASE --overwrite
fi
IDACLUSTERROLECOUNT=$(${KUBE_CMD} get clusterrole/ida-operator | tail -n +2 | wc -l)
if [[ "${IDACLUSTERROLECOUNT}" == "1" ]];  then
  ${KUBE_CMD} label clusterrole/ida-operator release=$RELEASE --overwrite
  IDA_OPERATOR_ROLEBINDING_NAME=$(${KUBE_CMD} get clusterrolebinding | grep ida-operator | head -n 1 | awk '{print$1}')
  ${KUBE_CMD} label clusterrolebinding/$IDA_OPERATOR_ROLEBINDING_NAME release=$RELEASE --overwrite
fi

${KUBE_CMD} label crd/idaclusters.sdc.ibm.com release=$RELEASE --overwrite
${KUBE_CMD} label deployment/ida-operator release=$RELEASE --overwrite

${KUBE_CMD} rollout resume deployment/ida-operator

echo -e "\033[32mIDA Operator has been upgraded. Monitor the pod status with '${KUBE_CMD}c get pods -w'.\033[0m"