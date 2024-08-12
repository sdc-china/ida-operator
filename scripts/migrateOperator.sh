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
    echo "  -c  The Operator scope, Cluster or Namespaced, the default is Namespaced"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:c:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        i)  IMAGEREGISTRY=$OPTARG
            ;;
        c)  SCOPE=$OPTARG
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

${KUBE_CMD} scale deployment/ida-operator --replicas=0

RELEASE=$(echo $IMAGEREGISTRY  | rev | cut -d':' -f 1 | rev)
IDA_OPERATOR_ROLEBINDING_NAME=$(${KUBE_CMD} get clusterrolebinding | grep ida-operator | head -n 1 | awk '{print$1}')


${KUBE_CMD} patch deployment/ida-operator --type=json --patch '
[
  { 
    "op": "replace",
    "path": "/spec/template/spec/containers/0/args",
    "value": [
        --metrics-bind-address=127.0.0.1:8080
     ]
  }
]
'


if [ ! -z ${SCOPE} ] && [[ ${SCOPE} == "Cluster" ]]; then
  ${KUBE_CMD} delete rolebinding/ida-operator
  ${KUBE_CMD} delete role/ida-operator
  ${KUBE_CMD} apply -f ./descriptors/cluster/cluster-role.yaml
  ${KUBE_CMD} label clusterrolebinding/$IDA_OPERATOR_ROLEBINDING_NAME release=$RELEASE --overwrite
else
  ${KUBE_CMD} delete clusterrolebinding/$IDA_OPERATOR_ROLEBINDING_NAME
  ${KUBE_CMD} delete clusterrole/ida-operator

  ${KUBE_CMD} apply -f ./descriptors/namespaced/role.yaml
  ${KUBE_CMD} apply -f ./descriptors/namespaced/role-binding.yaml

  ${KUBE_CMD} patch deployment/ida-operator --type=json --patch '
  [
    { 
      "op": "add",
      "path": "/spec/template/spec/containers/0/env",
      "value": [
          {
              "name": "WATCH_NAMESPACE",
              "valueFrom": {
                  "fieldRef": {
                      "fieldPath": "metadata.namespace"
                  }
              }
          }
       ]
    }
  ]
  '
  
fi

${KUBE_CMD} apply -f ./descriptors/ida-operators-edit.yaml

# Change the operator image
${KUBE_CMD} set env deployment/ida-operator IDA_OPERATOR_IMAGE=$IMAGEREGISTRY --overwrite 
${KUBE_CMD} set image deployment/ida-operator operator=$IMAGEREGISTRY

#update label
${KUBE_CMD} label serviceaccount/ida-operator release=$RELEASE --overwrite

${KUBE_CMD} label crd/idaclusters.sdc.ibm.com release=$RELEASE --overwrite
${KUBE_CMD} label deployment/ida-operator release=$RELEASE --overwrite

${KUBE_CMD} scale deployment/ida-operator --replicas=1

echo -e "\033[32mIDA Operator has been upgraded. Monitor the pod status with '${KUBE_CMD} get pods -w'.\033[0m"