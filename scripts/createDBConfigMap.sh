#!/bin/bash

# This script need to be executed under root path ida-operator

CUR_DIR=$(pwd)
PLATFORM_VERSION=""
source ${CUR_DIR}/scripts/helper/common.sh

function show_help {
    echo -e "\nUsage: createDBConfigMap.sh -i ida_image -d db_type \n"
    echo "Options:"
    echo "  -h  Display help"
    echo "  -i  IDA image name"
    echo "  -d  IDA Database type"
    echo "      For example: registry_url/ida:version"
}

if [[ $1 == "" ]]
then
    show_help
    exit -1
else
    while getopts "h?i:d:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        i)  IMAGEREGISTRY=$OPTARG
            ;;
        d)  DATABASE=$OPTARG
            ;;
        :)  echo "Invalid option: -$OPTARG requires an argument"
            show_help
            exit -1
            ;;
        esac
    done
fi

if command -v "podman" >/dev/null 2>&1
then
    echo "Use podman command to load images."
    cli_cmd="podman"
    local_repo_prefix="localhost/"
    loaded_msg_prefix="Loaded image(s): localhost/"
elif command -v "docker" >/dev/null 2>&1
then
    echo "Use docker command to load images."
    cli_cmd="docker"
    local_repo_prefix=""
    loaded_msg_prefix="Loaded image: "
else
    echo "No available Docker-compatible command line. Exit."
    exit -1
fi

## create sqls secret
${cli_cmd} rmi $IMAGEREGISTRY
if [ "${cli_cmd}" = "podman" ]
then
    ${cli_cmd} pull --tls-verify=false $IMAGEREGISTRY
elif [ "${cli_cmd}" = "docker" ]
then
    ${cli_cmd} pull $IMAGEREGISTRY
fi

rm -rf tmp && mkdir tmp && chown 1001:0 tmp
${cli_cmd} run -v $(pwd)/tmp:/data --rm $IMAGEREGISTRY cp -r /opt/ol/wlp/sqls /data

if [[ ${DATABASE} == "postgres" ]]; then
    oc create configmap ida-embedded-db-configmap --from-file=./tmp/sqls/postgres/2-data-postgres.sql --from-file=./tmp/sqls/postgres/1-schema-postgres.sql --dry-run=client -o yaml | oc apply -f -
elif [[ ${DATABASE} == "mysql" ]]
then
    oc create configmap ida-embedded-db-configmap --from-file=./tmp/sqls/mysql/2-data-mysql.sql --from-file=./tmp/sqls/mysql/1-schema-mysql.sql --dry-run=client -o yaml | oc apply -f -
fi

echo -e "\033[32mThe Configmap have been successfully created.\033[0m"
