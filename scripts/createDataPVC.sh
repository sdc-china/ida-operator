#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
PLATFORM_VERSION=""
source ${CUR_DIR}/scripts/helper/common.sh
check_platform_version

function show_help {
    echo -e "\nUsage: createDataPVC.sh -s storage_class_name \n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -s  Storage class name"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?s:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        s)  STORAGECLASS=$OPTARG
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

[ -f ./deploydatapvc.yaml ] && rm ./deploydatapvc.yaml
cp ./descriptors/patterns/data-pvc.yaml ./deploydatapvc.yaml

if [ ! -z ${STORAGECLASS} ]; then
# Change the storage class name
echo "Using the storage class name: $STORAGECLASS"
sed -e "s|storageClassName: .*|storageClassName: \"$STORAGECLASS\" |g" ./deploydatapvc.yaml > ./deploydatapvcsav.yaml ;  mv ./deploydatapvcsav.yaml ./deploydatapvc.yaml
fi

oc apply -f ./deploydatapvc.yaml

echo -e "\033[32mThe Data PVC have been successfully created. Monitor the pvc status with 'oc get pvc -w'.\033[0m"
