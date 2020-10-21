#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
PLATFORM_VERSION=""
source ${CUR_DIR}/scripts/helper/common.sh
check_platform_version

function show_help {
    echo -e "\nUsage: deployOperator.sh -i operator_image -n namespace \n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -i  Operator image name"
    echo "      For example: registry_url/ida-operator:version"
    echo "  -n  The namespace to deploy Operator"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:n:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        i)  IMAGEREGISTRY=$OPTARG
            ;;
        n)  NAMESPACE=$OPTARG
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

[ -f ./deployoperator.yaml ] && rm ./deployoperator.yaml
cp ./descriptors/operator.yaml ./deployoperator.yaml

[ -f ./cluster-role-binding.yaml ] && rm ./cluster-role-binding.yaml
cp ./descriptors/cluster-role-binding.yaml ./cluster-role-binding.yaml

sed -e "s|<NAMESPACE>|$NAMESPACE|g" ./cluster-role-binding.yaml > ./cluster-role-binding_temp.yaml ;  mv ./cluster-role-binding_temp.yaml ./cluster-role-binding.yaml

if [ ! -z ${IMAGEREGISTRY} ]; then
# Change the location of the image
echo "Using the operator image name: $IMAGEREGISTRY"
sed -e "s|image: .*|image: \"$IMAGEREGISTRY\" |g" ./deployoperator.yaml > ./deployoperatorsav.yaml ;  mv ./deployoperatorsav.yaml ./deployoperator.yaml
fi

oc apply -f ./descriptors/operator-crd.yaml
oc apply -f ./descriptors/service-account.yaml
oc apply -f ./descriptors/role.yaml
oc apply -f ./descriptors/role-binding.yaml
oc apply -f ./descriptors/cluster-role.yaml
oc apply -f ./cluster-role-binding.yaml

oc apply -f ./deployoperator.yaml
echo -e "\033[32mAll descriptors have been successfully applied. Monitor the pod status with 'oc get pods -w'.\033[0m"