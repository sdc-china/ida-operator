# Installing the IDA operator on OpenShift

Planning for IDA deployment according to [System Requirements](docs/system-requirements.md).

For other Kubernetes platform please refer to [README_K8S](README_K8S.md).

## Before you begin

Step 1. Log in to your cluster by either of the two ways.

- For installer with cluster-admin role

```
#Login cluster admin
oc login https://<cluster-ip>:<port> -u <cluster-admin> -p <password>
```

- For installer without cluster-admin role

```
#Create service account in target project by cluster admin
oc project <project_name>
oc create sa ida-installer-sa
oc apply -f ./descriptors/rbac/ida-installer.yml
oc adm policy add-cluster-role-to-user ida-installer -z ida-installer-sa

#Get service account token
TOKENNAME=`oc describe  sa/ida-installer-sa  | grep Tokens |  awk '{print $2}'`
TOKEN=`oc get secret $TOKENNAME -o jsonpath='{.data.token}'| base64 --decode`

#Login service account
oc login --token=$TOKEN --server=<OCP_API_SERVER>
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
scripts/loadImages.sh -p ida-24.0.10.1.tgz -r $REGISTRY_HOST/ida
```

## IDA Operator

### Installing IDA Operator

Step 1. Go to the project that you want to install IDA Operator.

```
oc project <project_name>

#For example:
oc new-project ida
oc project ida
```

Step 2. Preparing private docker registry secret

  ```
  oc create secret docker-registry ida-operator-secret --docker-server=<docker_registry>  --docker-username=<docker_username> --docker-password=<docker_password>
  ```

Step 3. Deploy IDA operator to your cluster.

```
chmod +x scripts/deployOperator.sh
scripts/deployOperator.sh -i <operator_image> -c <operator_scope> -s <image_pull_secret>

#Example of namespace-scoped operator:
scripts/deployOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.10.1 -s ida-operator-secret

#Example of cluster-scoped operator:
scripts/deployOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.10.1 -c Cluster -s ida-operator-secret

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
#Example of using private docker registry:
oc set image deployment/ida-operator operator=$REGISTRY_HOST/ida/ida-operator:24.0.10.1
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

Step 2. Preparing private docker registry secret

```
oc create secret docker-registry ida-docker-secret --docker-server=<docker_registry> --docker-username=<docker_username> --docker-password=<docker_password>
```

Step 3. Preparing signed SSL certificate secret (Optional)

By default, IDA uses self-signed SSL certification. You can also prepare your own signed SSL certifications which includes the files "tls.crt" and tls.key", then create a secret for it.

```
#For example:
oc create secret tls ida-tls-secret --cert tls.crt --key tls.key

```

Step 4. Preparing LDAPS SSL certificate secret (Optional)

If you want to integrate with LDAP server by the LDAPS protocol, then you need to add the LDAPS SSL certificate into IDA trusted certification list.

- You can get the LDAPS certificate file by infrastructure team or export by LDAP server URL.

```
openssl s_client -showcerts -connect <LDAPS server host>:<LDAP server port> </dev/null 2>/dev/null|openssl x509 -outform PEM > /root/ldapserver-cert.crt

#For example:
openssl s_client -showcerts -connect c97721v.fyre.com:636 </dev/null 2>/dev/null|openssl x509 -outform PEM > /root/ldapserver-cert.crt
```

- Create trusted secret for the certificate file

```
#For example:
oc create secret generic ida-trusted-secret --from-file=ldap.crt=/root/ldapserver-cert.crt

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
  oc get sc
  
  #Example of using default configurations(Name： ida-data-pvc, AccessMode: ReadWriteMany, Capacity: 20Gi):
  scripts/createDataPVC.sh -s managed-nfs-storage
  ```

  **Notes:** If you want to run multiple pods of IDA, please make sure the storage access mode is **ReadWriteMany**.

Step 6. Preparing Database.

- **For Demo Purpose** (Using Internal Database)

  IDA will create an internal db, and deleting ida instance will also remove the db.

- **For Production Purpose** (Using External Database)

  Step 1. Configuring your database by either of the two ways.
  - [Create on-prem database](https://sdc-china.github.io/IDA-doc/installation/installation-database-installation-and-configuration.html).
  - [Create on-container postgresql database](db/README.md)

  Step 2. Creating a database credentials.

  ```
  #Switch to your IDA Instance project:
  oc project <ida_project_name>

  oc create secret generic ida-db-credential --from-literal=DATABASE_USER=<DATABASE_USER> \
  --from-literal=DATABASE_PASSWORD=<DATABASE_PASSWORD>

  #Example:
  oc create secret generic ida-db-credential --from-literal=DATABASE_USER=postgres \
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

A custom resource YAML is a configuration file that describes an instance of a deployment and includes parameters to install IDA. Each time that you need to make an update or modification, you must apply the changes to your deployments.

- **Configuring IDA Custom Resource**

  Please check and edit the IDA custom resource (CR) file before you apply it to the operator, and you can find the IDA CR template at **descriptors/patterns/ida-cr-production.yaml**.

  - **Configuring shared configuration parameters**

  Parameters | Description
  --- | --------------
  shared.imageRegistry | Image registry URL for all components, can be overridden individually. E.g., example.repository.com
  shared.imageTag | Image tag for IDA and Operator, can be overridden individually. E.g., 24.0.10.1
  shared.imagePullPolicy | Image pull policy, The possible values are "IfNotPresent", "Always", and "Never", the default value is **IfNotPresent**, can be overridden individually. 
  shared.imagePullSecrets | A list of secrets name to use for pulling images from registries. E.g., ["ida-docker-secret", "ida-operator-secret"].
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
  idaWeb.imageName | IDA Image name. E.g., ida/ida
  idaWeb.imagePullPolicy | Image pull policy. The default value is **IfNotPresent**.
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

  Use the OpenShift CLI to apply the custom resource.


  ```
  oc apply -f descriptors/patterns/ida-cr-production.yaml
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
oc patch --type=merge idacluster/idadeploy -p '{"spec": {"shared": {"imageTag": "24.0.10.1"}}}'
```

Step 4. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```

