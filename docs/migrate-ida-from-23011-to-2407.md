## Migrate IDA from v23.0.11 to v24.0.7

### Prerequisite

Log in to your cluster by either of the two ways.

- For installer with cluster-admin role

```
#Using the OpenShift CLI:

oc login https://<cluster-ip>:<port> -u <cluster-admin> -p <password>
```

- For installer without cluster-admin role

Please refer to the steps in [Installing IDA without cluster-admin role](non-cluster-admin-install.md#for-openshift)

### Before you begin

Step 1. Download IDA operator scripts

```
git clone https://github.com/sdc-china/ida-operator.git
cd ida-operator
```

Step 2. Log in to your docker registry

```
#Example of using external docker registry:
REGISTRY_HOST=<YOUR_PRIVATE_EXTERNAL_REGISTRY>
podman login --tls-verify=false $REGISTRY_HOST
```

Step 3. Load and push the latest IDA Operator and IDA Web images to your docker registry

```
scripts/loadImages.sh -p ida-24.0.7.tgz -r $REGISTRY_HOST/ida
```

Step 4. Backup the IDA instance configuration and delete it from OCP

```
oc project ida
oc get IDACluster/idadeploy -o yaml > idadeploy.yaml
oc delete IDACluster/idadeploy
```


### Migrate IDA Operator.

Step 1. Switch to the IDA Operator project.

```
oc project <operator_project_name>

#For example:
oc project ida
```

Step 2. Migrate IDA operator to v24.0.7.

```
chmod +x scripts/migrateOperator.sh
scripts/migrateOperator.sh -i <operator_image>

#Example of using external docker registry:
scripts/migrateOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.7
```

Step 3. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```


### Migrate IDA Instance.

Step 1. Switch to the IDA Instance project.

```
oc project <ida_project_name>

#For example:
oc project ida
```

Step 2. Delete unused objects.

```
oc delete clusterrole/hazelcast-cluster-role
oc delete rolebinding/hazelcast-role-binding
oc get route | grep ida-web | awk '{print$1}' | xargs oc delete route
```

Step 3. Creating IDA database credentials.

```

oc create secret generic ida-external-db-credential --from-literal=DATABASE_USER=<DATABASE_USER> \
--from-literal=DATABASE_PASSWORD=<DATABASE_PASSWORD>

#Example:
oc create secret generic ida-external-db-credential --from-literal=DATABASE_USER=postgres \
--from-literal=DATABASE_PASSWORD=password

```

Step 4. Migrate IDA Instance.

**Notes:** If you want to configure SSL certificate for IDA, or add trusted LDAPS certificate, please prepare the certification files according to the steps in [Certificates Configuration](certificates-configuration.md).

```
chmod +x scripts/deployIDA.sh
scripts/deployIDA.sh -i <ida_image> -r <replicas_number> -t <installation_type> -d <database_type> -s <image_pull_secret> --data-pvc-name <existing_data_pvc> --db-server-name <external_db_server> --db-name <external_db_name> --db-port <external_db_port> --db-schema <external_db_schema> --db-credential-secret <external_db_credential_secret_name> --cpu-request <cpu_request> --memory-request <memory_request> --cpu-limit <cpu_limit> --memory-limit <memory_limit> --tls-cert <tls_cert>

#Example of using external docker registry and external database with IDA instance resource requests and limits configuration:
scripts/deployIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.7 -r 1 -t external -d postgres -s ida-docker-secret --data-pvc-name ida-data-pvc --db-server-name <DB_HOST> --db-name idaweb --db-port <DB_PORT> --db-schema <DB_SCHEMA>> --db-credential-secret ida-external-db-credential --cpu-request 2 --memory-request 4Gi --cpu-limit 4 --memory-limit 8Gi --tls-cert <tls_cert_path>
```

Step 5. Run Database migration page in IDA.

Please refer to IDA doc: https://sdc-china.github.io/IDA-doc/installation/installation-migrating-ida-application.html

Step 6. Restart IDA Pod.

```
oc rollout restart deployments/idadeploy-ida-web

```

