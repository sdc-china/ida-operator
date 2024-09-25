#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
PLATFORM_VERSION=""
source ${CUR_DIR}/scripts/helper/common.sh

function show_help {
    echo -e "\nUsage: createDataPVC.sh -n pvc_name -s storage_class_name -m access_model -c stoage_capacity\n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -n  PVC name"
    echo "  -s  Storage class name"
    echo "  -m  Access mode, the defualt value is ReadWriteMany"
    echo "  -c  Stoage capacity, the defualt value is 5Gi"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?n:s:m:c:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        n)  PVCNAME=$OPTARG
            ;;
        s)  STORAGECLASS=$OPTARG
            ;;
        m)  ACCESSMODE=$OPTARG
            ;;
        c)  CAPACITY=$OPTARG
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

if [ ! -z ${PVCNAME} ]; then
# Change the pvc name
echo "Using the PVC name: $PVCNAME"
sed -e "s|name: ida-data-pvc|name: \"$PVCNAME\" |g" ./deploydatapvc.yaml > ./deploydatapvcsav.yaml ;  mv ./deploydatapvcsav.yaml ./deploydatapvc.yaml
fi

if [ ! -z ${STORAGECLASS} ]; then
# Change the storage class name
echo "Using the storage class name: $STORAGECLASS"
sed -e "s|storageClassName: .*|storageClassName: \"$STORAGECLASS\" |g" ./deploydatapvc.yaml > ./deploydatapvcsav.yaml ;  mv ./deploydatapvcsav.yaml ./deploydatapvc.yaml
fi

if [ ! -z ${ACCESSMODE} ]; then
# Change the storage access mode
echo "Using the access mode: $ACCESSMODE"
sed -e "s|ReadWriteMany|$ACCESSMODE |g" ./deploydatapvc.yaml > ./deploydatapvcsav.yaml ;  mv ./deploydatapvcsav.yaml ./deploydatapvc.yaml
fi

if [ ! -z ${CAPACITY} ]; then
# Change the storage capacity
echo "Using the storage capacity: $CAPACITY"
sed -e "s|storage: 20Gi|storage: $CAPACITY |g" ./deploydatapvc.yaml > ./deploydatapvcsav.yaml ;  mv ./deploydatapvcsav.yaml ./deploydatapvc.yaml
fi

${KUBE_CMD} apply -f ./deploydatapvc.yaml

echo -e "\033[32mThe Data PVC have been successfully created. Monitor the pvc status with '${KUBE_CMD} get pvc -w'.\033[0m"
