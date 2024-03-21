#!/bin/bash
###############################################################################
#
# deployIDA.sh
#
###############################################################################
#set -xv
CUR_DIR=$(pwd)
source ${CUR_DIR}/scripts/helper/common.sh

progname=`basename $0`

usage(){
cat <<EOF

 Usage: $progname <options>"
        -h|--help                      - help page
        -i|--image                     - IDA image name (For example: registry_url/ida:version)
        -r|--replicas                  - Optional: IDA replicas number, the defualt value is 1
        -t|--installation-type         - Optional: Installation type (Options: embedded or external)
        -d|--db-type                   - Optional: IDA Database type, the default is postgres (Options: postgres, mysql, db2 or oracle.)
        -s|--pull-secret               - Optional: Image pull secret (Default is empty)
        -c|--tls-cert                  - Optional: Custom Liberty SSL certificate path (For example: /root/ida-operator/libertykeystore.p12)
        -p|--tls-cert-password         - Optional: Custom Liberty SSL certificate password, the default value is idaAdmin
        --data-pvc-name                - Optional: IDA data pvc name (Required when you want use the existing IDA data pvc)
        --db-pvc-name                  - Optional: IDA embedded database pvc name (Required when the insallation type is embedded and you want use the existing IDA database pvc)
        --storage-class                - Optional: Storage class name (Required when the insallation type is embedded)
        --data-storage-capacity        - Optional: IDA data storage capacity, the defualt value is 5Gi
        --embedded-db-image            - Optional: IDA embedded db image, the defualt value is 'postgres:14.3'
        --db-name                      - Optional: IDA external database name (Required when the insallation type is external)
        --db-port                      - Optional: IDA external database port (Required when the insallation type is external)
        --db-server-name               - Optional: IDA external database server host name (Required when the insallation type is external)
        --db-schema                    - Optional: IDA external database current schema
        --db-credential-secret         - Optional: The secret for IDA external database username and password (Required when the insallation type is external)
        --cpu-request                  - Optional: CPU resource requests for the IDA instance, the default is 2
        --memory-request               - Optional: Memory resource requests for the IDA instance, the default is 4Gi
        --cpu-limit                    - Optional: CPU resource limits for the IDA instance, the default is 4
        --memory-limit                 - Optional: Memory resource limits for the IDA instanc , the default is 8Gi


 Example of using openshift internal docker registry and embedded database:
 scripts/deployIDA.sh -i image-registry.openshift-image-registry.svc:5000/ida/ida:24.0.2 -r 1 -t embedded -d postgres --storage-class managed-nfs-storage

 Example of using external docker registry and external database with IDA instance resource requests and limits configuration:
 scripts/deployIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.2 -r 1 -t external -d postgres -s ida-docker-secret --storage-class managed-nfs-storage --db-server-name <DB_HOST> --db-name idaweb --db-port 5432  --db-credential-secret ida-external-db-credential --cpu-request 2 --memory-request 4Gi --cpu-limit 4 --memory-limit 8Gi

 Example of using openshift internal docker registry and external on-container database:
 scripts/deployIDA.sh -i image-registry.openshift-image-registry.svc:5000/ida/ida:24.0.2 -r 1 -t external -d postgres --storage-class managed-nfs-storage --db-server-name db.ida-db.svc.cluster.local --db-name idaweb --db-port 5432  --db-credential-secret ida-external-db-credential

EOF
}


if [ $# -eq 0 ]; then
   echo " $progname: one or more arguments are required"
   usage
   exit 1
fi


# Read input parameters
# Specify command line arguments and suboptions here
shortopt=hi:r:t:d:s:c:p:
longopt=help:,image:,replicas:,installation-type:,db-type:,pull-secret:,tls-cert:,tls-cert-password:,embedded-db-image:,db-name:,db-port:,db-server-name:,db-schema:,db-credential-secret:,cpu-request:,memory-request:,cpu-limit:,memory-limit:,data-pvc-name:,db-pvc-name:,storage-class:,data-storage-capacity:

getopt -T > /dev/null
if [ $? -eq 4 ]; then
    # GNU enhanced getopt
   options=`getopt --name "$progname" --options "$shortopt" --long "$longopt" -- "$@"`
else
   # Original getopt
   options=`getopt "$shortopt" "$@"`
fi
if [ $? -ne 0 ]; then
   echo "Error in getopt" >&2
   usage
   exit 2
fi

eval set -- "$options"

# Extract options and their arguments into variables.
while true ; do
    case "$1" in
        -h|--help) helppage=true ; shift ; break ;;
        -i|--image)
            case "$2" in
                "") shift 2 ;;
                *) IMAGEREGISTRY=$2 ; shift 2 ;;
            esac ;;
        -r|--replicas)
            case "$2" in
                "") shift 2 ;;
                *) REPLICAS=$2 ; shift 2 ;;
            esac ;;
        -t|--installation-type)
            case "$2" in
                "") shift 2 ;;
                *) INSTALLATION_TYPE=$2 ; shift 2 ;;
            esac ;;
        -d|--db-type)
            case "$2" in
                "") shift 2 ;;
                *) DATABASE=$2 ; shift 2 ;;
            esac ;;
        -s|--pull-secret)
            case "$2" in
                "") shift 2 ;;
                *) SECRET=$2 ; shift 2 ;;
            esac ;;
        -c|--tls-cert)
            case "$2" in
                "") shift 2 ;;
                *) CERT_PATH=$2 ; shift 2 ;;
            esac ;;
        -p|--tls-cert-password)
            case "$2" in
                "") shift 2 ;;
                *) CERT_PASSWORD=$2 ; shift 2 ;;
            esac ;;
        --data-pvc-name)
            case "$2" in
                "") shift 2 ;;
                *) DATA_PVC_NAME=$2 ; shift 2 ;;
            esac ;;
        --db-pvc-name)
            case "$2" in
                "") shift 2 ;;
                *) DB_PVC_NAME=$2 ; shift 2 ;;
            esac ;;
        --storage-class)
            case "$2" in
                "") shift 2 ;;
                *) STORAGEPCLASS_NAME=$2 ; shift 2 ;;
            esac ;;
        --data-storage-capacity)
            case "$2" in
                "") shift 2 ;;
                *) DATA_STORAGE_CAPACITY=$2 ; shift 2 ;;
            esac ;;
        --embedded-db-image)
            case "$2" in
                "") shift 2 ;;
                *) DATABASE_IMAGE=$2 ; shift 2 ;;
            esac ;;
        --db-name)
            case "$2" in
                "") shift 2 ;;
                *) DATABASE_NAME=$2 ; shift 2 ;;
            esac ;;
        --db-port)
            case "$2" in
                "") shift 2 ;;
                *) DATABASE_PORT=$2 ; shift 2 ;;
            esac ;;
        --db-server-name)
            case "$2" in
                "") shift 2 ;;
                *) DATABASE_SERVER_NAME=$2 ; shift 2 ;;
            esac ;;
        --db-schema)
            case "$2" in
                "") shift 2 ;;
                *) DATABASE_SCHEMA=$2 ; shift 2 ;;
            esac ;;
        --db-credential-secret)
            case "$2" in
                "") shift 2 ;;
                *) DATABASE_CREDENTIAL_SECRET=$2 ; shift 2 ;;
            esac ;;
        --cpu-request)
            case "$2" in
                "") shift 2 ;;
                *) CPU_REQUEST=$2 ; shift 2 ;;
            esac ;;
        --memory-request)
            case "$2" in
                "") shift 2 ;;
                *) MEMORY_REQUEST=$2 ; shift 2 ;;
            esac ;;
        --cpu-limit)
            case "$2" in
                "") shift 2 ;;
                *) CPU_LIMIT=$2 ; shift 2 ;;
            esac ;;
        --memory-limit)
            case "$2" in
                "") shift 2 ;;
                *) MEMORY_LIMIT=$2 ; shift 2 ;;
            esac ;;

        --) shift ; break ;;
        *) echo "$progname: Internal error!" ; exit 5 ;;
    esac
done

if [ "$helppage" == "true" ]; then
   usage
   exit
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


if [ ! -z ${IMAGEREGISTRY} ]; then
# Change the location of the image
echo "Using the IDA image name: $IMAGEREGISTRY"
cat ./deploycr.yaml | sed -e "s|image: <IDA_IMAGE>|image: \"$IMAGEREGISTRY\" |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

NAMESPACE=$(oc config view --minify -o 'jsonpath={..namespace}')
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

if [ ! -z ${CERT_PASSWORD} ]; then
# Change Liberty SSL certificate Password
CERT_PASSWORD_ENCODED=$(echo -n $CERT_PASSWORD | base64)
cat ./deploycr.yaml | sed -e "s|tlsCertPassword:|tlsCertPassword: $CERT_PASSWORD_ENCODED |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${DATA_PVC_NAME} ]; then
cat ./deploycr.yaml | sed -e "s|existingDataPVCName:|existingDataPVCName: $DATA_PVC_NAME |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${DB_PVC_NAME} ]; then
cat ./deploycr.yaml | sed -e "s|existingDBPVCName:|existingDBPVCName: $DB_PVC_NAME |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${STORAGEPCLASS_NAME} ]; then
cat ./deploycr.yaml | sed -e "s|storageClassName:|storageClassName: $STORAGEPCLASS_NAME |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${DATA_STORAGE_CAPACITY} ]; then
cat ./deploycr.yaml | sed -e "s|storageCapacity: 5Gi|storageCapacity: $DATA_STORAGE_CAPACITY |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi



if [[ ${INSTALLATION_TYPE} == "external" ]]; then
    # Change the database configuration
    cat ./deploycr.yaml | sed -e "s|databaseName:|databaseName: $DATABASE_NAME |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
    cat ./deploycr.yaml | sed -e "s|databasePort:|databasePort: $DATABASE_PORT |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
    cat ./deploycr.yaml | sed -e "s|databaseServerName:|databaseServerName: $DATABASE_SERVER_NAME |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
	if [ ! -z ${DATABASE_SCHEMA} ]; then
	  echo "DB Schema: $DATABASE_SCHEMA"
	  cat ./deploycr.yaml | sed -e "s|currentSchema:|currentSchema: $DATABASE_SCHEMA |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
	fi
     cat ./deploycr.yaml | sed -e "s|databaseCredentialSecret: ida-external-db-secret|databaseCredentialSecret: $DATABASE_CREDENTIAL_SECRET |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi


if [ ! -z ${CPU_REQUEST} ]; then
# Change CPU resource requests 
echo "CPU resource requests: $CPU_REQUEST"
cat ./deploycr.yaml | sed -e "s|cpuRequest: 2|cpuRequest: $CPU_REQUEST |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${MEMORY_REQUEST} ]; then
# Change Memory resource requests
echo "Memory resource requests: $MEMORY_REQUEST"
cat ./deploycr.yaml | sed -e "s|memoryRequest: 4Gi|memoryRequest: $MEMORY_REQUEST |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${CPU_LIMIT} ]; then
# Change CPU resource limits
echo "CPU resource limits: $CPU_LIMIT"
cat ./deploycr.yaml | sed -e "s|cpuLimit: 4|cpuLimit: $CPU_LIMIT |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [ ! -z ${MEMORY_LIMIT} ]; then
# Change Memory resource limits
echo "Memory resource limits: $MEMORY_LIMIT"
cat ./deploycr.yaml | sed -e "s|memoryLimit: 8Gi|memoryLimit: $MEMORY_LIMIT |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

if [[ ${INSTALLATION_TYPE} == "embedded" ]]; then

if [ ! -z ${DATABASE_IMAGE} ]; then
  # Change DB image 
  echo "DB Image: $DATABASE_IMAGE"
  cat ./deploycr.yaml | sed -e "s|postgres:14.3|$DATABASE_IMAGE |g" > ./deploycrsav.yaml ;  mv ./deploycrsav.yaml ./deploycr.yaml
fi

chmod +x scripts/createDBConfigMap.sh
scripts/createDBConfigMap.sh -i $IMAGEREGISTRY -d $DATABASE
fi

oc apply -f ./deploycr.yaml


echo -e "\033[1;32mWaiting IDA Ready... \033[0m"

sleep 10

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

  

exit 0