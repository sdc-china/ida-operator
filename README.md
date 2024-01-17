# Installing the IDA operator by hand

## Before you begin

Step 1. Log in to your cluster

```
#Using the OpenShift CLI:

oc login https://<cluster-ip>:<port> -u <cluster-admin> -p <password>
```

Step 2. Expose OCP internal registy (Optional)

If you are using OCP default internal docker registry, please expose the registry manually

```
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
REGISTRY_HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
``` 

Step 3. Log in to your docker registry

```
#Using the Podman CLI:
podman login -u $(oc whoami) -p $(oc whoami -t) --tls-verify=false $REGISTRY_HOST
```

Step 4. Download IDA operator scripts

```
git clone git@github.com:sdc-china/ida-operator.git
cd ida-operator
```

Step 5. Download IDA release package

## IDA Operator

IDA operator watches all namespaces. You only need to install the Operator in one namespace.

### Installing IDA Operator

Step 1. Go to the project that you want to install IDA Operator.

```
oc project <operator_project_name>

#For example:
oc project ida-operator
```

Step 2. Preparing IDA Operator Image

- **If your cluster is connected to the internet**

  The ida-operator image is published in Docker Hub. You may need to create the docker hub pull secret.
  ```
  oc create secret docker-registry ida-operator-secret --docker-server=docker.io --   docker-username=<docker_username> --docker-password=<docker_password>
  ```

- **If your cluster is NOT connected to the internet**

  You can get the IDA operator image from the IDA release package or Docker Hub, then push it to your private registry.

    - **From IDA release package**

    ida-operator-23.0.3.tgz is provided in the IDA release package.

    ```
    tar -zxvf ida-operator-23.0.3.tgz
    docker load --input images/ida-operator-23.0.3.tar.gz
    docker tag ctesdc/ida-operator:23.0.3 <YOUR_PRIVATE_REGISTRY_URL>/ctesdc/ida-operator:23.0.3
    docker push <YOUR_PRIVATE_REGISTRY_URL>/ctesdc/ida-operator:23.0.3
    ```

    - **From Docker Hub**

    ```
    docker pull ctesdc/ida-operator:23.0.3
    docker tag ctesdc/ida-operator:23.0.3 <YOUR_PRIVATE_REGISTRY_URL>/ctesdc/ida-operator:23.0.3
    docker push <YOUR_PRIVATE_REGISTRY_URL>/ctesdc/ida-operator:23.0.3
    ```

Step 3. Deploy IDA operator to your cluster.

```
chmod +x scripts/deployOperator.sh
scripts/deployOperator.sh -i <operator_image> -n <operator_project_name> -s <image_pull_secret>

#For example:
scripts/deployOperator.sh -i ctesdc/ida-operator:23.0.3 -n ida-operator -s ida-operator-secret
```

Step 4. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```

**Notes:** When started, you can monitor the operator logs with the following command:

```
oc logs -f deployment/ida-operator
```

### Uninstall IDA Operator.

```
chmod +x scripts/deleteOperator.sh
scripts/deleteOperator.sh
```

## IDA Instance

### Preparing to install IDA Instance

Step 1. Go to the project that you want to install IDA Instance.

```
oc project <ida_project_name>

#For example:
oc project ida-demo
```

Step 2. Load and push ida image to your docker registry.

Go to **ida-operator** folder, and load the ida image.

```
chmod +x scripts/loadImages.sh
scripts/loadImages.sh -p ida-<version>.tgz -r <docker_registry>

#For example:
scripts/loadImages.sh -p ida-23.0.11.tgz -r $REGISTRY_HOST/ida-demo
```
**Notes:** 
ida-\<version\>.tgz is provided in the IDA release package.

Step 3. Preparing docker registry secret (Optional)

If you are using external docker registry, then you may need to create the docker pull secret.
```
oc create secret docker-registry ida-docker-secret --docker-server=<docker_registry> --docker-username=<docker_username> --docker-password=<docker_password>
```

Step 4. Preparing the IDA storage.

```
chmod +x scripts/createDataPVC.sh
scripts/createDataPVC.sh -s <storage_class>

#For example:
scripts/createDataPVC.sh -s managed-nfs-storage
```

Step 5. Preparing Database.

- Using Embedded Database (For Demo Purpose, deleting ida operator instance will also remove the embedded db)

Create an ida-db-pvc and ida-embedded-db-configmap for IDA custom resource.

```
chmod +x scripts/createDBPVC.sh
scripts/createDBPVC.sh -s <storage_class>

chmod +x scripts/createDBConfigMap.sh
scripts/createDBConfigMap.sh -i <ida_image>

#For example:
scripts/createDBPVC.sh -s managed-nfs-storage
scripts/createDBConfigMap.sh -i $REGISTRY_HOST/ida-demo/ida:23.0.11
```

- Using External Database (For Product Purpose)

  Step 1. Configuring your database by either of the two ways.
  - [Create on-prem database](https://sdc-china.github.io/IDA-doc/installation/installation-database-installation-and-configuration.html).
  - [Create on-container postgresql database](db/README.md)

  Step 2. Creating a database credentials.

  ```
  oc create secret generic ida-external-db-secret --from-literal=DATABASE_SERVER_NAME=<DATABASE_SERVER> \
  --from-literal=DATABASE_NAME=<DATABASE_NAME> \
  --from-literal=DATABASE_PORT_NUMBER=<DATABASE_PORT> \
  --from-literal=DATABASE_USER=<DATABASE_USER> \
  --from-literal=DATABASE_PASSWORD=<DATABASE_PASSWORD> \
  --from-literal=DATABASE_MAX_POOL_SIZE=<DATABASE_MAX_POOL_SIZE>

  #For example:
  oc create secret generic ida-external-db-secret --from-literal=DATABASE_SERVER_NAME=localshot \
  --from-literal=DATABASE_NAME=idaweb \
  --from-literal=DATABASE_PORT_NUMBER=5432 \
  --from-literal=DATABASE_USER=postgres \
  --from-literal=DATABASE_PASSWORD=password \
  --from-literal=DATABASE_MAX_POOL_SIZE=50
  ```

### Installing IDA Instance

Step 1. Deploying an IDA Instance.

```
chmod +x scripts/deployIDA.sh
scripts/deployIDA.sh -i <ida_image> -n <ida_project_name> -r <replicas_number> -t <installation_type> -d <database_type> -s <image_pull_secret>

#Get help of deployIDA.sh
scripts/deployIDA.sh -h

#Example of using openshift internal docker registry and embedded database:
scripts/deployIDA.sh -i image-registry.openshift-image-registry.svc:5000/ida-demo/ida:23.0.11 -n ida-demo -r 1 -t embedded -d postgres

#Example of using external docker registry and external database:
scripts/deployIDA.sh -i $REGISTRY_HOST/ida:23.0.11 -n ida-demo -r 1 -t external -d postgres -s ida-docker-secret
```

If success, you will see the log from your console
```
Success! You could visit IDA by the url "https://<IDA_HOST>/ida"
```

Step 2. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```

**Notes:** When started, you can monitor the IDA logs with the following command:

```
oc logs -f deployment/idadeploy-ida-web
```

### IDA Access URL

```
echo "https://$(oc get route | grep ida-web | awk '{print$2}')/ida"
```

### Uninstall IDA Instance

```
oc delete IDACluster idadeploy
```
