# Installing the IDA operator on Other Kubernetes Platform

Planning for IDA deployment according to [System Requirements](docs/system-requirements.md).

## Before you begin

Step 1. Install Kubectl

```
#Latest Version:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

#Specific Version:
curl -LO "https://dl.k8s.io/release/v1.28.2/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

```

Step 2. Log in to your cluster by either of the two ways.

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

```
#Create service account in target namespace by cluster admin
kubectl create namespace <ida_namespace>
kubectl config set-context --current --namespace=<ida_namespace>
kubectl create sa ida-installer-sa
kubectl apply -f ./descriptors/rbac/ida-installer-k8s.yml 
kubectl create clusterrolebinding ida-installer-rolebinding --clusterrole=ida-installer --serviceaccount=<ida_namespace>:ida-installer-sa

#Get service account token
kubectl apply -f ./descriptors/rbac/ida-installer-secret.yml
TOKEN=`kubectl get secret ida-installer-secret -o jsonpath={.data.token} | base64 -d`

#Login service account
kubectl config set-credentials ida-installer/<cluster-host>:<port> --token=$TOKEN
kubectl config set-cluster <cluster-host>:<port> --insecure-skip-tls-verify=true --server=https://<cluster-host>:<port>
kubectl config set-context ida/<cluster-host>:<port>/ida-installer --user=ida-installer/<cluster-host>:<port> --namespace=<ida_namespace> --cluster=<cluster-host>:<port>
kubectl config use-context ida/<cluster-host>:<port>/ida-installer
```

Step 3. Log in to your docker registry

```
#Example of using private docker registry:
REGISTRY_HOST=<YOUR_PRIVATE_REGISTRY>
podman login --tls-verify=false $REGISTRY_HOST
```

Step 4. Download IDA operator scripts

```
git clone https://github.com/sdc-china/ida-operator.git
cd ida-operator
```

Step 5. Load IDA docker images

Get the IDA image file **ida-&lt;version&gt;.tgz**, then push it to your private registry.

```
chmod +x scripts/loadImages.sh
scripts/loadImages.sh -p ida-<version>.tgz -r <docker_registry>

#Example of using private docker registry:
scripts/loadImages.sh -p ida-24.0.9.tgz -r $REGISTRY_HOST/ida
```

## IDA Operator

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
scripts/deployOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.9 -s ida-operator-secret

#Example of cluster-scoped operator:
scripts/deployOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.9 -c Cluster -s ida-operator-secret

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
scripts/upgradeOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.9
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

Step 3. Preparing signed SSL certificate secret (Optional)

By default, IDA uses self-signed SSL certification. You can also prepare your own signed SSL certifications which includes the files "tls.crt" and tls.key", then create a secret for it.

```
#For example:
kubectl create secret tls ida-tls-secret --cert tls.crt --key tls.key

```

Step 4. Preparing LDAPS SSL certificate secret (Optional)

If you want to integrate with LDAP server by LDAPS protocol, then you need to add the LDAPS SSL certificate into IDA trusted certification list.

- You can get the LDAPS certificate file by infrastructure team or export by LDAP server URL.

```
openssl s_client -showcerts -connect <LDAPS server host>:<LDAP server port> </dev/null 2>/dev/null|openssl x509 -outform PEM > /root/ldapserver-cert.crt

#For example:
openssl s_client -showcerts -connect c97721v.fyre.com:636 </dev/null 2>/dev/null|openssl x509 -outform PEM > /root/ldapserver-cert.crt
```

- Create trusted secret for the certificate file

```
#For example:
kubectl create secret generic ida-trusted-secret --from-file=ldap.crt=/root/ldapserver-cert.crt

```

Step 5. Preparing the IDA storage.

- **For Demo Purpose**

  IDA will automatically create the storage, and deleting ida instance will also remove it.

- **For Production Purpose**

  Please use below command to create a storage for IDA.


  ```
  chmod +x scripts/createDataPVC.sh
  scripts/createDataPVC.sh -n <pvc_name> -s <storage_class> -m <access_mode> -c <stoage_capacity>
  
  # Get the storage class name of your cluster
  kubectl get sc
  
  #Example of using default configurations(Name： ida-data-pvc, AccessMode: ReadWriteMany, Capacity: 20Gi):
  scripts/createDataPVC.sh -s managed-nfs-storage
  ```

  **Notes:** If you want to run multiple pods of IDA, please make sure the storage access mode is **ReadWriteMany**.

Step 6. Preparing Database.

- For Demo Purpose (Using Internal Database)

  IDA will create an internal db, and deleting ida instance will also remove the db.

- For Product Purpose (Using External Database)

  Step 1. Configuring your database by either of the two ways.
  - [Create on-prem database](https://sdc-china.github.io/IDA-doc/installation/installation-database-installation-and-configuration.html).
  - [Create on-container postgresql database](db/README_K8S.md)

  Step 2. Creating a database credentials.

  ```
  #Switch to your IDA Instance namespace:
  kubectl config set-context --current --namespace=<ida_namespace>

  kubectl create secret generic ida-db-credential --from-literal=DATABASE_USER=<DATABASE_USER> \
  --from-literal=DATABASE_PASSWORD=<DATABASE_PASSWORD>

  #Example:
  kubectl create secret generic ida-db-credential --from-literal=DATABASE_USER=postgres \
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

A custom resource YAML is a configuration file that describes an instance of a deployment and includes parameters to install IDA. Each time that you need to make an update or modification, you must apply the changes to your deployments.

- **Configuring IDA Custom Resource**

  Please check and edit the IDA custom resource (CR) file before you apply it to the operator, and you can find the IDA CR template at **descriptors/patterns/ida-cr-production.yaml**.

  - **Configuring shared configuration parameters**

  Parameters | Description
  --- | --------------
  shared.storageClassName | Storage class if using dynamic provisioning. E.g., managed-nfs-storage

  - **Configuring database parameters**
  
  Parameters | Description
  --- | --------------
  idaDatabase.type | Database type. The possible values are "mysql", "postgres", "db2" and "oracle". Internal database only supports "mysql" and "postgres".
  idaDatabase.internal.enabled | Enable internal database for demo purpose. The default value is **false**.
  idaDatabase.external.enabled | Enable external database for production purpose. The default value is **true**.
  idaDatabase.external.databaseUrl | The JDBC URL. Only Oracle is supported. E.g., jdbc:oracle:thin:@serverName:port:databaseName
  idaDatabase.external.databaseName | Database instance name, for database except Oracle. E.g., ida 
  idaDatabase.external.databasePort | Database port, for database except Oracle. E.g., 5432 
  idaDatabase.external.databaseServerName | Database server name in the form of either a fully qualified domain name (FQDN) or an IP address, for database except Oracle. E.g., example.postgre.com 
  idaDatabase.external.currentSchema | Database schema name. This parameter is optional. E.g., databaseschema 
  idaDatabase.external.databaseCredentialSecret | Secret name that contains the **DATABASE_USER** and **DATABASE_PASSWORD** keys. E.g., ida-db-credential 
  
  - **Configuring IDA Web parameters**

  Parameters | Description
  --- | --------------
  idaWeb.image | Image URL. E.g., example.repository.com/ida/ida:24.0.9
  idaWeb.imagePullPolicy | Image pull policy. The default value is **Always**.
  idaWeb.imagePullSecrets | Image pull secrets. E.g., ida-docker-secret 
  idaWeb.replicas | Number of IDA pods. The default value is 1. 
  idaWeb.resources.requests.cpu | Minimum number of CPUs required for IDA container. The default value is **2**.
  idaWeb.resources.requests.memory | Minimum amount of memory required for IDA container. The default value is **4Gi**.
  idaWeb.resources.limits.cpu | Maximum number of CPUs allowed for IDA container. The default value is **4**.
  idaWeb.resources.limits.memory | Maximum amount of memory allowed for IDA container. The default value is **8Gi**.
  idaWeb.storage.storageCapacity | The storage capacity for persisting data, if using dynamic provisioning. The default value is **5Gi**.
  idaWeb.storage.existingDataPVCName | PVC for data if you are not using dynamic provisioning. E.g., ida-data-pvc
  idaWeb.initContainer.resources.requests.cpu | Minimum number of CPUs required for IDA init containers. The default value is **100m**.
  idaWeb.initContainer.resources.requests.memory | Minimum amount of memory required for IDA init containers. The default value is **256Mi**.
  idaWeb.initContainer.resources.limits.cpu | Maximum number of CPUs allowed for IDA init containers. The default value is **200m**.
  idaWeb.initContainer.resources.limits.memory | Maximum amount of memory allowed for IDA init containers. The default value is **512Mi**.
  idaWeb.tlsCertSecret | Secret name that contains the files **tls.crt** and **tls.key** for IDA. E.g., ida-tls-secret 
  idaWeb.trustedCertSecret | Secret name that contains trusted certificate files. E.g., ida-trusted-secret 
  idaWeb.network.type | IDA service expose type. The possible values are "route" and "ingress".

- **Deploying IDA Custom Resource**

  Use the Kubernetes CLI to apply the custom resource.


  ```
  kubectl apply -f descriptors/patterns/ida-cr-production.yaml
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
scripts/upgradeIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.9
```

