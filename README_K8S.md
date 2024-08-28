# Installing the IDA operator on Other Kubernetes Platform

## Prerequisite

Log in to your cluster by either of the two ways.

- For installer with cluster-admin role

```
#Login By Basic Auth
kubectl config set-credentials <cluster-user>/<cluster-host>:<port> --username=<cluster-user> --password=<password>
#Login By Token
kubectl config set-credentials <cluster-user>/<cluster-host>:<port> --token=<user_token>

kubectl config set-cluster <cluster-host>:<port> --insecure-skip-tls-verify=true --server=https://<cluster-host>:<port>
kubectl config set-context default/<cluster-host>:<port>/<cluster-user> --user=<cluster-user>/<cluster-host>:<port> --namespace=default --cluster=<cluster-host>:<port>
kubectl config use-context default/<cluster-host>:<port>/<cluster-user>
```

- For installer without cluster-admin role

Please refer to the steps in [Installing IDA without cluster-admin role](docs/non-cluster-admin-install.md#for-kubernetes)

## Before you begin

Step 1. Install Kubectl (Optional)

```
#Latest Version:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

#Specific Version:
curl -LO "https://dl.k8s.io/release/v1.28.2/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

```

Step 2. Log in to your docker registry


```
#Example of using private docker registry:
REGISTRY_HOST=<YOUR_PRIVATE_REGISTRY>
podman login --tls-verify=false $REGISTRY_HOST
```

Step 3. Download IDA operator scripts

```
git clone https://github.com/sdc-china/ida-operator.git
cd ida-operator
```

Step 4. Load IDA docker images

  Get the IDA image file **ida-&lt;version&gt;.tgz**, then push it to your private registry.

    ```
    chmod +x scripts/loadImages.sh
    scripts/loadImages.sh -p ida-<version>.tgz -r <docker_registry>
    
    #Example of using private docker registry:
    scripts/loadImages.sh -p ida-24.0.7.tgz -r $REGISTRY_HOST/ida
    ```

## IDA Operator

By default, IDA operator watches and manages resources in a single Namespace. You need to change the operator scope to cluster-scoped when operator installation if you want IDA Operator watches resources that are created in any Namespace.

### Installing IDA Operator

Step 1. Go to the namespace that you want to install IDA Operator.

```
kubectl config set-context --current --namespace=<ida_namespace>

#For example:
kubectl create namespace ida
kubectl config set-context --current --namespace=ida
```

Step 2. Preparing private docker registry secret

  ```
  kubectl create secret docker-registry ida-operator-secret --docker-server=<docker_registry>  --docker-username=<docker_username> --docker-password=<docker_password>
  ```

Step 3. Deploy IDA operator to your cluster.

```
chmod +x scripts/deployOperator.sh
scripts/deployOperator.sh -i <operator_image> -c <operator_scope> -s <image_pull_secret>

#Example of namespace-scoped operator:
scripts/deployOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.7 -s ida-operator-secret

#Example of cluster-scoped operator:
scripts/deployOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.7 -c Cluster -s ida-operator-secret

```

Step 4. Monitor the pod until it shows a STATUS of "Running":

```
kubectl get pods -w
```

**Notes:** When started, you can monitor the operator logs with the following command:

```
kubectl logs -f deployment/ida-operator
```

### Uninstall IDA Operator.

```
kubectl config set-context --current --namespace=<ida_namespace>

chmod +x scripts/deleteOperator.sh
scripts/deleteOperator.sh -c <operator_scope>

#Example of namespace-scoped operator uninstallation:
scripts/deleteOperator.sh 

#Example of cluster-scoped operator uninstallation:
scripts/deleteOperator.sh -c Cluster
```

### Upgrade IDA Operator.

Step 1. Switch to the IDA Operator namespace.

```
kubectl config set-context --current --namespace=<ida_namespace>

#For example:
kubectl config set-context --current --namespace=ida
```

Step 2. Preparing new IDA Operator Image

Follow the Step 2 of **Installing IDA Operator** to prepare the new IDA Operator Image.

Step 3. Upgrade IDA operator.

```
chmod +x scripts/upgradeOperator.sh
scripts/upgradeOperator.sh -i <operator_image>

#Example of using private docker registry:
scripts/upgradeOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.7
```

Step 4. Monitor the pod until it shows a STATUS of "Running":

```
kubectl get pods -w
```


## IDA Instance

**Notes:**  If Installing the IDA with non cluster-admin user, cluster admin needs to assign the **ida-operators-edit** role to installer user.

```
kubectl create clusterrolebinding ida-edit-rolebinding --clusterrole ida-operators-edit --user <K8S_USER>
```

### Preparing to install IDA Instance

Step 1. Go to the namespace that you want to install IDA Instance.

```
kubectl config set-context --current --namespace=<ida_namespace>

#For example:
kubectl create namespace ida
kubectl config set-context --current --namespace=ida
```

Step 2. Preparing private docker registry secret

```
kubectl create secret docker-registry ida-docker-secret --docker-server=<docker_registry> --docker-username=<docker_username> --docker-password=<docker_password>
```

Step 3. Preparing Database.

- For Demo Purpose (Using Embedded Database)

  IDA will create an embedded db, and deleting ida instance will also remove the embedded db.

- For Product Purpose (Using External Database)

  Step 1. Configuring your database by either of the two ways.
  - [Create on-prem database](https://sdc-china.github.io/IDA-doc/installation/installation-database-installation-and-configuration.html).
  - [Create on-container postgresql database](db/README_K8S.md)

  Step 2. Creating a database credentials.

  ```
  #Switch to your IDA Instance namespace:
  kubectl config set-context --current --namespace=<ida_namespace>

  kubectl create secret generic ida-external-db-credential --from-literal=DATABASE_USER=<DATABASE_USER> \
  --from-literal=DATABASE_PASSWORD=<DATABASE_PASSWORD>

  #Example:
  kubectl create secret generic ida-external-db-credential --from-literal=DATABASE_USER=postgres \
  --from-literal=DATABASE_PASSWORD=password
  ```

### Installing IDA Instance

Step 1. Go to the namespace that you want to install IDA Instance.

```
kubectl config set-context --current --namespace=<ida_namespace>

#For example:
kubectl config set-context --current --namespace=ida
```

Step 2. Deploying an IDA Instance.

**Notes:** If you want to configure SSL certificate for IDA, or add trusted LDAPS certificate, please prepare the certification files according to the steps in [Certificates Configuration](docs/certificates-configuration.md).

```
chmod +x scripts/deployIDA.sh
scripts/deployIDA.sh -i <ida_image> -r <replicas_number> -t <installation_type> -d <database_type> -s <image_pull_secret> --storage-class <storage_class> --db-server-name <external_db_server> --db-name <external_db_name> --db-port <external_db_port> --db-schema <external_db_schema> --db-credential-secret <external_db_credential_secret_name> --cpu-request <cpu_request> --memory-request <memory_request> --cpu-limit <cpu_limit> --memory-limit <memory_limit> --tls-cert <tls_cert>

#Get help of deployIDA.sh
scripts/deployIDA.sh -h

# Get the storage class name of your cluster
kubectl get sc

#Example of using private docker registry and embedded database:
scripts/deployIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.7 -r 1 -t embedded -d postgres -s ida-docker-secret --storage-class managed-nfs-storage

#Example of using private docker registry and external on-container database:
scripts/deployIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.7 -r 1 -t external -d postgres -s ida-docker-secret --storage-class managed-nfs-storage --db-server-name db.ida-db.svc.cluster.local --db-name idaweb --db-port 5432 --db-credential-secret ida-external-db-credential

#Example of using private docker registry and external database with IDA instance resource requests and limits configuration:
scripts/deployIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.7 -r 1 -t external -d postgres -s ida-docker-secret --storage-class managed-nfs-storage --db-server-name <DB_HOST> --db-name idaweb --db-port <DB_PORT> --db-credential-secret ida-external-db-credential --cpu-request 2 --memory-request 4Gi --cpu-limit 4 --memory-limit 8Gi
```

If success, you will see the log from your console

```
"Success! The IDA cluster internal service url is: `idadeploy-ida-web.ida.svc.cluster.local`, please expose IDA service based on your cluster network."
```

Step 3. Monitor the pod until it shows a STATUS of "Running":

```
kubectl get pods -w
```

**Notes:** When started, you can monitor the IDA logs with the following command:

```
kubectl logs -f deployment/idadeploy-ida-web
```

### IDA Access URL

You can find the IDA cluster internal service url by command `echo $(kubectl get svc | grep ida-web | awk '{print$1}').<IDA_NAMESPACE>.svc.cluster.local`, please expose IDA service based on your cluster network.

```
#Example of exposing IDA service by NGINX Ingress Controller:
kubectl create ingress ida-web --class=nginx --rule <IDA_HOST>/*=idadeploy-ida-web:9443 --annotation nginx.ingress.kubernetes.io/backend-protocol=HTTPS -n <IDA_NAMESPACE>
```


### Uninstall IDA Instance

```
kubectl delete IDACluster idadeploy
```

### Upgrade IDA Instance.

Step 1. Switch to the IDA Instance namespace.

```
kubectl config set-context --current --namespace=<ida_namespace>

#For example:
kubectl config set-context --current --namespace=ida
```

Step 2. Preparing new IDA Image

Follow the Step 2 of **Preparing to install IDA Instance** to prepare the new IDA Image.

Step 3. Upgrade IDA Instance.

```
chmod +x scripts/upgradeIDA.sh
scripts/upgradeIDA.sh -i <ida_image>

#Example of using private docker registry:
scripts/upgradeIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.7
```

