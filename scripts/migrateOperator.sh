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

oc scale deployment/ida-operator --replicas=0

RELEASE=$(echo $IMAGEREGISTRY  | rev | cut -d':' -f 1 | rev)
IDA_OPERATOR_ROLEBINDING_NAME=$(oc get clusterrolebinding | grep ida-operator | head -n 1 | awk '{print$1}')


oc patch deployment/ida-operator --type=json --patch '
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
  oc delete rolebinding/ida-operator
  oc delete role/ida-operator
  oc apply -f ./descriptors/cluster/cluster-role.yaml
  oc label clusterrolebinding/$IDA_OPERATOR_ROLEBINDING_NAME release=$RELEASE --overwrite
else
  oc delete clusterrolebinding/$IDA_OPERATOR_ROLEBINDING_NAME
  oc delete clusterrole/ida-operator

  oc apply -f ./descriptors/namespaced/role.yaml
  oc apply -f ./descriptors/namespaced/role-binding.yaml

  oc patch deployment/ida-operator --type=json --patch '
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

oc apply -f ./descriptors/ida-operators-edit.yaml

# Change the operator image
oc set env deployment/ida-operator IDA_OPERATOR_IMAGE=$IMAGEREGISTRY --overwrite 
oc set image deployment/ida-operator operator=$IMAGEREGISTRY

#update label
oc label serviceaccount/ida-operator release=$RELEASE --overwrite

oc label crd/idaclusters.sdc.ibm.com release=$RELEASE --overwrite
oc label deployment/ida-operator release=$RELEASE --overwrite

oc scale deployment/ida-operator --replicas=1

echo -e "\033[32mIDA Operator has been upgraded. Monitor the pod status with 'oc get pods -w'.\033[0m"