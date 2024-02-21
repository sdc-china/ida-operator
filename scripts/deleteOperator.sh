#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
PLATFORM_VERSION=""
source ${CUR_DIR}/scripts/helper/common.sh
check_platform_version

function show_help {
    echo -e "\nUsage: deleteOperator.sh -c <operator_scope> \n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -c  The Operator scope, Cluster or Namespaced, the default is Namespaced"
}

while getopts "h?c:" opt; do
    case "$opt" in
    h|\?)
        show_help
        exit 0
        ;;
    c)  SCOPE=$OPTARG
        ;;
    esac
done

if [ ! -z ${SCOPE} ] && [[ ${SCOPE} == "Cluster" ]]; then
    oc delete -f ./descriptors/cluster/operator.yaml
    oc delete -f ./descriptors/cluster/cluster-role.yaml
    [ -f ./cluster-role-binding.yaml ] && rm ./cluster-role-binding.yaml
    cp ./descriptors/cluster/cluster-role-binding.yaml ./cluster-role-binding.yaml
    NAMESPACE=$(oc config view --minify -o 'jsonpath={..namespace}')
    sed -e "s|<NAMESPACE>|$NAMESPACE|g" ./cluster-role-binding.yaml > ./cluster-role-binding_temp.yaml ;  mv ./cluster-role-binding_temp.yaml ./cluster-role-binding.yaml
    oc delete -f ./cluster-role-binding.yaml
else
    oc delete -f ./descriptors/namespaced/operator.yaml
    oc delete -f ./descriptors/namespaced/role.yaml
    oc delete -f ./descriptors/namespaced/role-binding.yaml
fi

oc delete -f ./descriptors/ida-operators-edit.yaml
oc delete -f ./descriptors/service-account.yaml


oc patch crd/idaclusters.sdc.ibm.com -p '{"metadata":{"finalizers":[]}}' --type=merge
oc delete crd idaclusters.sdc.ibm.com

echo "All descriptors have been successfully deleted."
