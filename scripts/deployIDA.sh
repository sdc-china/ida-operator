#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
PLATFORM_VERSION=""
source ${CUR_DIR}/scripts/helper/common.sh
JDBC_DRIVER_DIR=${CUR_DIR}/scripts/jdbc

function show_help {
    echo -e "\nUsage: deployIDA.sh -i ida_image [-t] [-d] \n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -i  IDA image name"
    echo "      For example: registry_url/ida:version"
    echo "  -n  The namespace to deploy IDA"
    echo "  -r  Optional: IDA replicas number"
    echo "      Defualt value is 1"
    echo "  -t  Optional: Installation type"
    echo "      For example: embedded or external"
    echo "  -d  Optional: Database type, the default is postgres"
    echo "      For example: postgres, mysql, db2 or oracle"
    echo "  -s  Optional: Image pull secret, the default is empty"
    echo "      For example: ida-docker-secret"
    echo "  -c  Optional: Custom Liberty SSL certificate path, the default is empty"
    echo "      For example: /root/ida-operator/libertykeystore.p12"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:n:r:t:d:s:c:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        i)  IMAGEREGISTRY=$OPTARG
            ;;
        n)  NAMESPACE=$OPTARG
            ;;
        r)  REPLICAS=$OPTARG
            ;;
        t)  INSTALLATION_TYPE=$OPTARG
            ;;
        d)  DATABASE=$OPTARG
            ;;
        s)  SECRET=$OPTARG
            ;;
        c)  CERT_PATH=$OPTARG
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
if [ -z "$INSTALLATION_TYPE" ]
then
    select_installation_type
fi

if [[ ${INSTALLATION_TYPE} == "embedded" ]]; then
    [ -f ./deploycr.yaml ] && rm ./deploycr.yaml
    cp ./descriptors/patterns/ida-cr-demo-embedded.yaml ./deploycr.yaml
elif [[ ${INSTALLATION_TYPE} == "external" ]]
then
    [ -f ./deploycr.yaml ] && rm ./deploycr.yaml
    cp ./descriptors/patterns/ida-cr-demo-external.yaml ./deploycr.yaml
fi

[ -f ./hazelcast-rbac.yaml ] && rm ./hazelcast-rbac.yaml
cp ./descriptors/hazelcast-rbac.yaml ./hazelcast-rbac.yaml

cat ./hazelcast-rbac.yaml | sed -e "s|<NAMESPACE>|$NAMESPACE|g" > ./hazelcast-rbac_temp.yaml ;  mv ./hazelcast-rbac_temp.yaml ./hazelcast-rbac.yaml


if [ ! -z ${IMAGEREGISTRY} ]; then
# Change the location of the image
echo "Using the IDA image name: $IMAGEREGISTRY"
cat ./deploycr.yaml | sed -e "s|image: <IDA_IMAGE>|image: \"$IMAGEREGISTRY\" |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

cat ./deploycr.yaml | sed -e "s|<NAMESPACE>|$NAMESPACE|g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml

if [ ! -z ${DATABASE} ]; then
# Change the database type
echo "Using the Database: $DATABASE"
cat ./deploycr.yaml | sed -e "s|type: postgres|type: $DATABASE |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${SECRET} ]; then
# Change the docker secret
echo "Using the docker secret: $SECRET"
cat ./deploycr.yaml | sed -e "s|imagePullSecrets:|imagePullSecrets: $SECRET |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${REPLICAS} ]; then
# Change replicas number
echo "Set replicas to $REPLICAS"
cat ./deploycr.yaml | sed -e "s|replicas: 1|replicas: $REPLICAS |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${CERT_PATH} ]; then
# Change Liberty SSL certificate
echo "Custom Liberty SSL Certificate path: $CERT_PATH"
CERT_ENCODED=$(base64 -w 0 $CERT_PATH)
cat ./deploycr.yaml | sed -e "s|tlsCert:|tlsCert: $CERT_ENCODED |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

oc apply -f ./hazelcast-rbac.yaml
oc apply -f ./deploycr.yaml


echo -e "\033[1;32mDeploying IDA custom resource. \033[0m"


if [[ ${INSTALLATION_TYPE} == "embedded" ]]; then
    # wait DB POD ready
    while true; do
        IDA_POD_NAME=$(oc get pod | grep ida-db | awk '{print$1}')
        IDA_POD_READY=$(oc get pods $IDA_POD_NAME -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | awk '{print$1}')
        if [ "$IDA_POD_READY" = "True" ] ; then
            break;
        else
            echo "Waiting IDA Embedded DB Pod Ready..."
            sleep 10
        fi
    done
fi

while true; do
    echo -e "\x1B[1mChecking IDA Web Pod Status\x1B[0m"
    IDA_POD_NAME=$(oc get pod | grep ida-web | head -n 1 | awk '{print$1}')
    IDA_POD_STATUS=$(oc get pod | grep ida-web | head -n 1 | awk '{print$3}')
    echo "The Pod status is $IDA_POD_STATUS"
    if [ "$IDA_POD_STATUS" = "Running" ] ; then
        echo -e "\033[1;32mCopying JDBC drivers. \033[0m"
        oc rsync $JDBC_DRIVER_DIR $IDA_POD_NAME:/var/ida/data/
        echo -e "\033[1;32mRestarting IDA Web Pod. \033[0m"
        oc delete pod $(oc get pod | grep ida-web | awk '{print$1}')
        break;
    else
        echo "Waiting IDA Web Pod Running..."
        sleep 10
    fi
done

IDA_DEPLOYMENT_NAME=$(oc get deployment | grep ida-web | head -n 1 | awk '{print$1}')
ROLLOUT_STATUS_CMD="oc rollout status deployment/$IDA_DEPLOYMENT_NAME"
until $ROLLOUT_STATUS_CMD; do
  $ROLLOUT_STATUS_CMD
done

IDA_ROUTE_NAME=$(oc get route | grep ida-web | awk '{print$1}')

if [ "$IDA_ROUTE_NAME" = "" ] ; then
  oc create route passthrough --service $(oc get svc | grep ida-web | awk '{print$1}')
fi

echo "Success! You could visit IDA by the url: https://$(oc get route | grep ida-web | awk '{print$2}')/ida"
