#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
PLATFORM_VERSION=""
source ${CUR_DIR}/scripts/helper/common.sh
JDBC_DRIVER_DIR=${CUR_DIR}/scripts/jdbc

function show_help {
    echo -e "\nUsage: deployIDA.sh -i ida_image \n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -i  IDA image name"
    echo "      For example: registry_url/ida:version"
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

function select_installation_type(){
    COLUMNS=12
    echo -e "\x1B[1mIs this an install with embedded or external database?\x1B[0m"
    options=("Embedded" "External")
    PS3='Enter a valid option [1 to 2]: '
    select opt in "${options[@]}"
    do
        case $opt in
            "Embedded")
                INSTALLATION_TYPE="embedded"
                break
                ;;
            "External")
                INSTALLATION_TYPE="external"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}

select_installation_type

if [[ ${INSTALLATION_TYPE} == "embedded" ]]; then
    [ -f ./deploycr.yaml ] && rm ./deploycr.yaml
    cp ./descriptors/patterns/ida-cr-demo-embedded.yaml ./deploycr.yaml
elif [[ ${INSTALLATION_TYPE} == "external" ]]
then
    [ -f ./deploycr.yaml ] && rm ./deploycr.yaml
    cp ./descriptors/patterns/ida-cr-demo-external.yaml ./deploycr.yaml
fi

if [ ! -z ${IMAGEREGISTRY} ]; then
# Change the location of the image
echo "Using the IDA image name: $IMAGEREGISTRY"
cat ./deploycr.yaml | sed -e "s|image: <IDA_IMAGE>|image: \"$IMAGEREGISTRY\" |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

oc apply -f ./deploycr.yaml

echo -e "\033[1;32mDeploying IDA custom resource. \033[0m"
while true; do
    echo -e "\x1B[1mChecking IDA POD Status\x1B[0m"
    IDA_POD_NAME=$(oc get pod | grep ida-web | awk '{print$1}')
    IDA_POD_STATUS=$(oc get pod | grep ida-web | awk '{print$3}')
    echo "The Pod status is $IDA_POD_STATUS"
    if [ "$IDA_POD_STATUS" = "Running" ] ; then
        echo -e "\033[1;32mCopying JDBC drivers. \033[0m"
        oc rsync $JDBC_DRIVER_DIR $IDA_POD_NAME:/var/ida/data/
        oc delete pod $IDA_POD_NAME
        break;
    else
        echo "Waiting..."
        sleep 10
    fi
done

while true; do
    echo -e "\x1B[1mChecking IDA POD Status\x1B[0m"
    IDA_POD_NAME=$(oc get pod | grep ida-web | awk '{print$1}')
    IDA_POD_STATUS=$(oc get pod | grep ida-web | awk '{print$3}')
    echo "The Pod status is $IDA_POD_STATUS"
    if [ "$IDA_POD_STATUS" = "Running" ] ; then
        break;
    else
        echo "Waiting..."
        sleep 10
    fi
done


while true; do
    IDA_POD_NAME=$(oc get pod | grep ida-web | awk '{print$1}')
    oc logs $IDA_POD_NAME >> log
    IDA_READY=$(cat log | grep 'Application ida started')
    echo $IDA_READY
    if [ ! -z "$IDA_READY"  ] ; then
        rm -f log
        sleep 3
        echo "IDA started!"
        break;
    else
        echo "IDA is starting..."
        sleep 10
    fi
done

IDA_ROUTE_NAME=$(oc get route | grep ida-web | awk '{print$1}')

if [ "$IDA_ROUTE_NAME" = "" ] ; then
  oc create route passthrough --service $(oc get svc | grep ida-web | awk '{print$1}')
fi

echo -e "\033[1;32mSuccess! You could visit IDA by the url: https://$(oc get route | grep ida-web | awk '{print$2}')/ida \033[0m"
