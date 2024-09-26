#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
source ${CUR_DIR}/scripts/helper/common.sh

function show_help {
    echo -e "\nUsage: createDBPVC.sh -s storage_class_name \n"
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

[ -f ./deploydbpvc.yaml ] && rm ./deploydbpvc.yaml
cp ./descriptors/patterns/db-pvc.yaml ./deploydbpvc.yaml

if [ ! -z ${STORAGECLASS} ]; then
# Change the storage class name
echo "Using the storage class name: $STORAGECLASS"
sed -e "s|storageClassName: .*|storageClassName: \"$STORAGECLASS\" |g" ./deploydbpvc.yaml > ./deploydbpvcsav.yaml ;  mv ./deploydbpvcsav.yaml ./deploydbpvc.yaml
fi

${KUBE_CMD} apply -f ./deploydbpvc.yaml

echo -e "\033[32mThe Demo DB PVC have been successfully created. Monitor the pvc status with '${KUBE_CMD} get pvc -w'.\033[0m"
