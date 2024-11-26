#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
source ${CUR_DIR}/scripts/helper/common.sh

function show_help {
    echo -e "\nUsage: deployOperator.sh -i operator_image \n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -i  Operator image name"
    echo "      For example: registry_url/ida-operator:version"
    echo "  -c  The Operator scope, Cluster or Namespaced, the default is Namespaced"
    echo "  -s  Optional: Image pull secret, the default is empty"
    echo "      For example: ida-operator-secret"
    echo "  -p  Optional: Image pull policy, IfNotPresent or Always, the default is IfNotPresent"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:c:s:p:w:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        i)  IMAGEREGISTRY=$OPTARG
            ;;
        c)  SCOPE=$OPTARG
            ;;
        s)  SECRET=$OPTARG
            ;;
        p)  PULLPOLICY=$OPTARG
            ;;
        w)  WATCH_NAMESPACE=$OPTARG
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

[ -f ./deployoperator.yaml ] && rm ./deployoperator.yaml
[ -f ./operator-crd.yaml ] && rm ./operator-crd.yaml
cp ./descriptors/operator-crd.yaml ./operator-crd.yaml

if ([ ! -z ${SCOPE} ] && [[ ${SCOPE} == "Cluster" ]]) || [ ! -z ${WATCH_NAMESPACE} ]; then
    cp ./descriptors/cluster/operator.yaml ./deployoperator.yaml
    
    [ -f ./cluster-role-binding.yaml ] && rm ./cluster-role-binding.yaml
    cp ./descriptors/cluster/cluster-role-binding.yaml ./cluster-role-binding.yaml

    NAMESPACE=$(${KUBE_CMD} config view --minify -o 'jsonpath={..namespace}')
    sed -e "s|<NAMESPACE>|$NAMESPACE|g" ./cluster-role-binding.yaml > ./cluster-role-binding_temp.yaml ;  mv ./cluster-role-binding_temp.yaml ./cluster-role-binding.yaml
else
    cp ./descriptors/namespaced/operator.yaml ./deployoperator.yaml
fi


if [ ! -z ${IMAGEREGISTRY} ]; then
    # Change the location of the image
    echo "Using the operator image name: $IMAGEREGISTRY"
    sed -e "s|<IDA_OPERATOR_IMAGE>|\"$IMAGEREGISTRY\" |g" ./deployoperator.yaml > ./deployoperatorsav.yaml ;  mv ./deployoperatorsav.yaml ./deployoperator.yaml
fi

if [ -z ${SECRET} ]; then
    # Change the docker secret
    echo "Reset the docker secret"
    sed -e "s|imagePullSecrets:| |g" ./deployoperator.yaml > ./deployoperatorsav.yaml ;  mv ./deployoperatorsav.yaml ./deployoperator.yaml
    sed -e "s|- name: <IMAGE_PULL_SECRET>| |g" ./deployoperator.yaml > ./deployoperatorsav.yaml ;  mv ./deployoperatorsav.yaml ./deployoperator.yaml
else
    # Change the docker secret
    echo "Using the docker secret: $SECRET"
    sed -e "s|name: <IMAGE_PULL_SECRET>|name: \"$SECRET\" |g" ./deployoperator.yaml > ./deployoperatorsav.yaml ;  mv ./deployoperatorsav.yaml ./deployoperator.yaml
fi

if [ ! -z ${PULLPOLICY} ]; then
    # Change the image pull policy
    echo "Using the image pull policy: $PULLPOLICY"
    sed -e "s|imagePullPolicy: IfNotPresent|imagePullPolicy: $PULLPOLICY |g" ./deployoperator.yaml > ./deployoperatorsav.yaml ;  mv ./deployoperatorsav.yaml ./deployoperator.yaml
fi

if ([ ! -z ${SCOPE} ] && [[ ${SCOPE} == "Cluster" ]]) || [ ! -z ${WATCH_NAMESPACE} ]; then
    ${KUBE_CMD} apply -f ./descriptors/cluster/cluster-role.yaml
    ${KUBE_CMD} apply -f ./cluster-role-binding.yaml
else
    ${KUBE_CMD} apply -f ./descriptors/namespaced/role.yaml
    ${KUBE_CMD} apply -f ./descriptors/namespaced/role-binding.yaml
fi

${KUBE_CMD} apply -f ./operator-crd.yaml
${KUBE_CMD} apply -f ./descriptors/ida-operators-edit.yaml
${KUBE_CMD} apply -f ./descriptors/service-account.yaml

${KUBE_CMD} apply -f ./deployoperator.yaml

if [ ! -z ${WATCH_NAMESPACE} ]; then
  ${KUBE_CMD} set env deployment/ida-operator WATCH_NAMESPACE=$WATCH_NAMESPACE --overwrite 
fi
echo -e "\033[32mAll descriptors have been successfully applied. Monitor the pod status with '${KUBE_CMD} get pods -w'.\033[0m"