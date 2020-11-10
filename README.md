# Installing the IDA operator by hand

## Before you begin

Step 1. Log in to your cluster

```
#Using the OpenShift CLI:

oc login https://<cluster-ip>:<port> -u <cluster-admin> -p <password>
```

Step 2. Log in to your docker registry

```
#Using the Podman CLI:
podman login -u $(oc whoami) -p $(oc whoami -t) --tls-verify=false $(oc registry info)
```

## IDA Operator

IDA operator watches all namespaces. You only need to install the Operator in one namespace.

### Installing IDA Operator

Step 1. Go to the project that you want to install IDA Operator.

```
oc project <operator_project_name>

#For example:
oc project ida-operator
```

Step 2. Deploy IDA operator to your cluster.

```
chmod +x scripts/deployOperator.sh
scripts/deployOperator.sh -i <operator_image> -n <operator_project_name>

#For example:
scripts/deployOperator.sh -i ctesdc/ida-operator:1.0.2 -n ida-operator
```

Step 3. Monitor the pod until it shows a STATUS of "Running":

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

Path to ida-operator **ROOT Folder**

```
chmod +x scripts/loadImages.sh
scripts/loadImages.sh -p ida-<version>.tgz -r <docker_registry>

#For example:
scripts/loadImages.sh -p ida-3.0.0.tgz -r $(oc registry info)/ida-demo
```

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

- Using Embedded Database

Create an ida-db-pvc and ida-embedded-db-secret for IDA custom resource.

```
chmod +x scripts/createDBPVC.sh
scripts/createDBPVC.sh -s <storage_class>

chmod +x scripts/createDBSecret.sh
scripts/createDBSecret.sh -i <ida_image>

#For example:
scripts/createDBPVC.sh -s managed-nfs-storage
scripts/createDBSecret.sh -i $(oc registry info)/ida-demo/ida:3.1.0
```

- Using External Database

  Step 1. Configuring your database, please refer to [Database Installation and Configuration](https://sdc-china.github.io/IDA-doc/installation/installation-db.html#install-and-configure-mysql-db).

  Step 2. Creating a database credentials.

  ```
  # If you change the secret name, please update the 'idaDatabase.externalDatabase.secretCredentials' value in ./ida/ida.yaml
  oc create secret generic ida-external-db-secret --from-literal=DATABASE_SERVER_NAME=<DATABASE_SERVER> \
  --from-literal=DATABASE_NAME=<DATABASE_NAME> \
  --from-literal=DATABASE_PORT_NUMBER=<DATABASE_PORT> \
  --from-literal=DATABASE_USER=<DATABASE_USER> \
  --from-literal=DATABASE_PASSWORD=<DATABASE_PASSWORD>

  #For example:
  oc create secret generic ida-external-db-secret --from-literal=DATABASE_SERVER_NAME=localshot \
  --from-literal=DATABASE_NAME=keterweb \
  --from-literal=DATABASE_PORT_NUMBER=3306 \
  --from-literal=DATABASE_USER=root \
  --from-literal=DATABASE_PASSWORD=mysqladmin
  ```

### Installing IDA Instance

Step 1. Deploying an IDA Instance.

```
chmod +x scripts/deployIDA.sh
scripts/deployIDA.sh -i <ida_image>

#Example of using openshift internal docker registry:
scripts/deployIDA.sh -i image-registry.openshift-image-registry.svc:5000/ida-demo/ida:3.0.0

#Example of using external docker registry:
scripts/deployIDA.sh -i <docker_registry>/ida:3.0.0 -s ida-docker-secret
```

If success, you will see the log from your console
```
Success! You could visit IDA by the url "https://<HOST>/ida"
```

Step 2. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```

**Notes:** When started, you can monitor the IDA logs with the following command:

```
oc logs -f deployment/ida-demo-ida-web
```

### Uninstall IDA Instance

```
oc delete IDACluster ida-demo
```
