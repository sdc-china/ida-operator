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
#Example of using openshift internal docker registry:
podman login -u $(oc whoami) -p $(oc whoami -t) --tls-verify=false $REGISTRY_HOST

#Example of using external docker registry:
REGISTRY_HOST=<YOUR_PRIVATE_EXTERNAL_REGISTRY>
podman login --tls-verify=false $REGISTRY_HOST
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
oc new-project ida-operator
oc project ida-operator
```

Step 2. Preparing IDA Operator Image

- **If your cluster is connected to the internet**

  The ida-operator image is published in Docker Hub. You may need to create the docker hub pull secret.
  ```
  oc create secret docker-registry ida-operator-secret --docker-server=docker.io  --docker-username=<docker_username> --docker-password=<docker_password>
  ```

- **If your cluster is NOT connected to the internet**

  You can get the IDA operator image from the IDA release package, then push it to your private registry.

    ```
    chmod +x scripts/loadImages.sh
    scripts/loadImages.sh -p ida-operator-<version>.tgz -r <docker_registry>
    
    #Example of using openshift internal docker registry:
    scripts/loadImages.sh -p ida-operator-23.0.3.tgz -r $REGISTRY_HOST/ida-operator

    #Example of using external docker registry:
    scripts/loadImages.sh -p ida-operator-23.0.3.tgz -r $REGISTRY_HOST/ctesdc
    ```

Step 3. Deploy IDA operator to your cluster.

```
chmod +x scripts/deployOperator.sh
scripts/deployOperator.sh -i <operator_image> -n <operator_project_name> -s <image_pull_secret>

#Example of using public docker hub registry:
scripts/deployOperator.sh -i ctesdc/ida-operator:23.0.3 -n ida-operator -s ida-operator-secret

#Example of using openshift internal docker registry:
scripts/deployOperator.sh -i image-registry.openshift-image-registry.svc:5000/ida-operator/ida-operator:23.0.3 -n ida-operator

#Example of using external docker registry:
scripts/deployOperator.sh -i $REGISTRY_HOST/ctesdc/ida-operator:23.0.3 -n ida-operator -s ida-operator-secret
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

### Upgrade IDA Operator.

Step 1. Switch to the IDA Operator project.

```
oc project <operator_project_name>

#For example:
oc project ida-operator
```

Step 2. Preparing new IDA Operator Image

Follow the Step 2 of **Installing IDA Operator** to prepare the new IDA Operator Image.

Step 3. Upgrade IDA operator.

```
chmod +x scripts/upgradeOperator.sh
scripts/upgradeOperator.sh -i <operator_image>

#Example of using public docker hub registry:
scripts/upgradeOperator.sh -i ctesdc/ida-operator:23.0.3

#Example of using openshift internal docker registry:
scripts/upgradeOperator.sh -i image-registry.openshift-image-registry.svc:5000/ida-operator/ida-operator:23.0.3

#Example of using external docker registry:
scripts/upgradeOperator.sh -i $REGISTRY_HOST/ctesdc/ida-operator:23.0.3
```

Step 4. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```


## IDA Instance

### Preparing to install IDA Instance

Step 1. Go to the project that you want to install IDA Instance.

```
oc project <ida_project_name>

#For example:
oc new-project ida-demo
oc project ida-demo
```

Step 2. Load and push ida image to your docker registry.

Go to **ida-operator** folder, and load the ida image.

```
chmod +x scripts/loadImages.sh
scripts/loadImages.sh -p ida-<version>.tgz -r <docker_registry>

#Example of using openshift internal docker registry:
scripts/loadImages.sh -p ida-23.0.11.tgz -r $REGISTRY_HOST/ida-demo

#Example of using external docker registry:
scripts/loadImages.sh -p ida-23.0.11.tgz -r $REGISTRY_HOST/ctesdc
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

# Get the storage class name of your cluster
oc get sc

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

#Example of using openshift internal docker registry:
scripts/createDBConfigMap.sh -i $REGISTRY_HOST/ida-demo/ida:23.0.11

#Example of using external docker registry:
scripts/createDBConfigMap.sh -i $REGISTRY_HOST/ctesdc/ida:23.0.11
```

- Using External Database (For Product Purpose)

  Step 1. Configuring your database by either of the two ways.
  - [Create on-prem database](https://sdc-china.github.io/IDA-doc/installation/installation-database-installation-and-configuration.html).
  - [Create on-container postgresql database](db/README.md)

  Step 2. Creating a database credentials.

  ```
  #Switch to your IDA Instance project:
  oc project <ida_project_name>

  oc create secret generic ida-external-db-secret --from-literal=DATABASE_SERVER_NAME=<DATABASE_SERVER> \
  --from-literal=DATABASE_NAME=<DATABASE_NAME> \
  --from-literal=DATABASE_PORT_NUMBER=<DATABASE_PORT> \
  --from-literal=DATABASE_USER=<DATABASE_USER> \
  --from-literal=DATABASE_PASSWORD=<DATABASE_PASSWORD> \
  --from-literal=DATABASE_MAX_POOL_SIZE=<DATABASE_MAX_POOL_SIZE>

  #Example of On-premise DB:
  oc create secret generic ida-external-db-secret --from-literal=DATABASE_SERVER_NAME=localhost \
  --from-literal=DATABASE_NAME=idaweb \
  --from-literal=DATABASE_PORT_NUMBER=5432 \
  --from-literal=DATABASE_USER=postgres \
  --from-literal=DATABASE_PASSWORD=password \
  --from-literal=DATABASE_MAX_POOL_SIZE=50
  
  #Example of DB on OpenShift:
  oc create secret generic ida-external-db-secret --from-literal=DATABASE_SERVER_NAME=db.ida-db.svc.cluster.local \
  --from-literal=DATABASE_NAME=idaweb \
  --from-literal=DATABASE_PORT_NUMBER=5432 \
  --from-literal=DATABASE_USER=postgres \
  --from-literal=DATABASE_PASSWORD=password \
  --from-literal=DATABASE_MAX_POOL_SIZE=50
  ```

### Installing IDA Instance

Step 1. Go to the project that you want to install IDA Instance.

```
oc project <ida_project_name>

#For example:
oc project ida-demo
```

Step 2. Deploying an IDA Instance.

```
chmod +x scripts/deployIDA.sh
scripts/deployIDA.sh -i <ida_image> -n <ida_project_name> -r <replicas_number> -t <installation_type> -d <database_type> -s <image_pull_secret>

#Get help of deployIDA.sh
scripts/deployIDA.sh -h

#Example of using openshift internal docker registry and embedded database:
scripts/deployIDA.sh -i image-registry.openshift-image-registry.svc:5000/ida-demo/ida:23.0.11 -n ida-demo -r 1 -t embedded -d postgres

#Example of using external docker registry and external database:
scripts/deployIDA.sh -i $REGISTRY_HOST/ctesdc/ida:23.0.11 -n ida-demo -r 1 -t external -d postgres -s ida-docker-secret

#Example of using openshift internal docker registry and external database:
scripts/deployIDA.sh -i image-registry.openshift-image-registry.svc:5000/ida-demo/ida:23.0.11 -n ida-demo -r 1 -t external -d postgres
```

If success, you will see the log from your console
```
Success! You could visit IDA by the url "https://<IDA_HOST>/ida"
```

Step 3. Monitor the pod until it shows a STATUS of "Running":

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

### Upgrade IDA Instance.

Step 1. Prerequisite.

If there are database changes for the new IDA version, please execute the corresponding migration scripts before upgrade.

Step 2. Switch to the IDA Instance project.

```
oc project <ida_project_name>

#For example:
oc project ida-demo
```

Step 3. Preparing new IDA Image

Follow the Step 2 of **Preparing to install IDA Instance** to prepare the new IDA Image.

Step 4. Upgrade IDA Instance.

```
chmod +x scripts/upgradeIDA.sh
scripts/upgradeIDA.sh -i <ida_image>

#Example of using openshift internal docker registry:
scripts/upgradeIDA.sh -i image-registry.openshift-image-registry.svc:5000/ida-demo/ida:23.0.11

#Example of using external docker registry:
scripts/upgradeIDA.sh -i $REGISTRY_HOST/ctesdc/ida:23.0.11
```
