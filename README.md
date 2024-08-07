# Installing the IDA operator by hand

## Before you begin

Step 1. Log in to your cluster

```
#Using the OpenShift CLI:

oc login https://<cluster-ip>:<port> -u <cluster-admin> -p <password>
```

Step 2. Log in to your docker registry


```
#Example of using external docker registry:
REGISTRY_HOST=<YOUR_PRIVATE_EXTERNAL_REGISTRY>
podman login --tls-verify=false $REGISTRY_HOST
```

Step 3. Download IDA operator scripts

```
git clone https://github.com/sdc-china/ida-operator.git
cd ida-operator
```

Step 4. Download IDA release package

## IDA Operator

By default, IDA operator watches and manages resources in a single Namespace. You need to change the operator scope to cluster-scoped when operator installation if you want IDA Operator watches resources that are created in any Namespace.

**Notes:**  IDA Operator installation requires an Openshift user with the cluster-admin role.

### Installing IDA Operator

Step 1. Go to the project that you want to install IDA Operator.

```
oc project <project_name>

#For example:
oc new-project ida
oc project ida
```

Step 2. Preparing IDA Operator Image

  IDA operator image is published in Docker Hub. You can access it directly if your cluster is connected to internet.

- **If your cluster is NOT connected to the internet**

  You can get the IDA operator image from the IDA release package, then push it to your private registry.

    ```
    chmod +x scripts/loadImages.sh
    scripts/loadImages.sh -p ida-operator-<version>.tgz -r <docker_registry>
    
    #Example of using external docker registry:
    scripts/loadImages.sh -p ida-operator-24.0.6.tgz -r $REGISTRY_HOST/ida
    ```

Step 3. Preparing docker registry secret (Optional)

  If you are using external docker registry, then you may need to create the docker pull secret.
  
  ```
  oc create secret docker-registry ida-operator-secret --docker-server=<docker_registry>  --docker-username=<docker_username> --docker-password=<docker_password>
  ```

Step 4. Deploy IDA operator to your cluster.

```
chmod +x scripts/deployOperator.sh
scripts/deployOperator.sh -i <operator_image> -c <operator_scope> -s <image_pull_secret>

#Example of namespace-scoped operator and using external docker registry:
scripts/deployOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.6 -s ida-operator-secret

#Example of cluster-scoped operator and using public docker hub registry:
scripts/deployOperator.sh -i ctesdc/ida-operator:24.0.6 -c Cluster -s ida-operator-secret

```

Step 5. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```

**Notes:** When started, you can monitor the operator logs with the following command:

```
oc logs -f deployment/ida-operator
```

### Uninstall IDA Operator.

```
oc project <project_name>

chmod +x scripts/deleteOperator.sh
scripts/deleteOperator.sh -c <operator_scope>

#Example of namespace-scoped operator uninstallation:
scripts/deleteOperator.sh 

#Example of cluster-scoped operator uninstallation:
scripts/deleteOperator.sh -c Cluster
```

### Upgrade IDA Operator.

Step 1. Switch to the IDA Operator project.

```
oc project <operator_project_name>

#For example:
oc project ida
```

Step 2. Preparing new IDA Operator Image

Follow the Step 2 of **Installing IDA Operator** to prepare the new IDA Operator Image.

Step 3. Upgrade IDA operator.

```
chmod +x scripts/upgradeOperator.sh
scripts/upgradeOperator.sh -i <operator_image>

#Example of using external docker registry:
scripts/upgradeOperator.sh -i $REGISTRY_HOST/ctesdc/ida-operator:24.0.6

#Example of using public docker hub registry:
scripts/upgradeOperator.sh -i ctesdc/ida-operator:24.0.6
```

Step 4. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```


## IDA Instance

**Notes:**  If Installing the IDA with non cluster-admin user, cluster admin needs to assign the **ida-operators-edit** role to installer user.

```
oc adm policy add-cluster-role-to-user ida-operators-edit <OCP_USER>
```

### Preparing to install IDA Instance

Step 1. Go to the project that you want to install IDA Instance.

```
oc project <ida_project_name>

#For example:
oc new-project ida
oc project ida
```

Step 2. Load and push ida image to your docker registry.

Go to **ida-operator** folder, and load the ida image.

```
chmod +x scripts/loadImages.sh
scripts/loadImages.sh -p ida-<version>.tgz -r <docker_registry>

#Example of using external docker registry:
scripts/loadImages.sh -p ida-24.0.6.tgz -r $REGISTRY_HOST/ida
```

**Notes:** 
ida-\<version\>.tgz is provided in the IDA release package.

Step 3. Preparing docker registry secret (Optional)

If you are using external docker registry, then you may need to create the docker pull secret.

```
oc create secret docker-registry ida-docker-secret --docker-server=<docker_registry> --docker-username=<docker_username> --docker-password=<docker_password>
```

Step 5. Preparing Database.

- For Demo Purpose (Using Embedded Database)

  IDA will create an embedded db, and deleting ida instance will also remove the embedded db.

- For Product Purpose (Using External Database)

  Step 1. Configuring your database by either of the two ways.
  - [Create on-prem database](https://sdc-china.github.io/IDA-doc/installation/installation-database-installation-and-configuration.html).
  - [Create on-container postgresql database](db/README.md)

  Step 2. Creating a database credentials.

  ```
  #Switch to your IDA Instance project:
  oc project <ida_project_name>

  oc create secret generic ida-external-db-credential --from-literal=DATABASE_USER=<DATABASE_USER> \
  --from-literal=DATABASE_PASSWORD=<DATABASE_PASSWORD>

  #Example:
  oc create secret generic ida-external-db-credential --from-literal=DATABASE_USER=postgres \
  --from-literal=DATABASE_PASSWORD=password
  ```

### Installing IDA Instance

Step 1. Go to the project that you want to install IDA Instance.

```
oc project <ida_project_name>

#For example:
oc project ida
```

Step 2. Deploying an IDA Instance.

**Notes:** If you want to configure SSL certificate for IDA, or add trusted LDAPS certificate, please prepare the certification files according to the steps in [Certificates Configuration](docs/certificates-configuration.md).

```
chmod +x scripts/deployIDA.sh
scripts/deployIDA.sh -i <ida_image> -r <replicas_number> -t <installation_type> -d <database_type> -s <image_pull_secret> --storage-class <storage_class> --db-server-name <external_db_server> --db-name <external_db_name> --db-port <external_db_port> --db-schema <external_db_schema> --db-credential-secret <external_db_credential_secret_name> --cpu-request <cpu_request> --memory-request <memory_request> --cpu-limit <cpu_limit> --memory-limit <memory_limit> --tls-cert <tls_cert>

#Get help of deployIDA.sh
scripts/deployIDA.sh -h

# Get the storage class name of your cluster
oc get sc

#Example of using external docker registry and embedded database:
scripts/deployIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.6 -r 1 -t embedded -d postgres -s ida-docker-secret --storage-class managed-nfs-storage

#Example of using external docker registry and external on-container database:
scripts/deployIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.6 -r 1 -t external -d postgres -s ida-docker-secret --storage-class managed-nfs-storage --db-server-name db.ida-db.svc.cluster.local --db-name idaweb --db-port 5432 --db-credential-secret ida-external-db-credential

#Example of using external docker registry and external database with IDA instance resource requests and limits configuration:
scripts/deployIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.6 -r 1 -t external -d postgres -s ida-docker-secret --storage-class managed-nfs-storage --db-server-name <DB_HOST> --db-name idaweb --db-port <DB_PORT> --db-credential-secret ida-external-db-credential --cpu-request 2 --memory-request 4Gi --cpu-limit 4 --memory-limit 8Gi
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

Step 1. Switch to the IDA Instance project.

```
oc project <ida_project_name>

#For example:
oc project ida
```

Step 2. Preparing new IDA Image

Follow the Step 2 of **Preparing to install IDA Instance** to prepare the new IDA Image.

Step 3. Upgrade IDA Instance.

```
chmod +x scripts/upgradeIDA.sh
scripts/upgradeIDA.sh -i <ida_image>

#Example of using external docker registry:
scripts/upgradeIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.6
```

