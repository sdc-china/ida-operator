# Configure standalone postgresql database by Openshift

## Create new namespace

```
oc new-project ida-db
```

## Create private docker registry secret

```
oc create secret docker-registry docker-secret --docker-server=<docker_registry>  --docker-username=<docker_username> --docker-password=<docker_password>
```

## Create database configmap

Get **schema-postgres.sql** and **data-postgres.sql** from IDA release package.

```
mv schema-postgres.sql 1-schema-postgres.sql
mv data-postgres.sql 2-data-postgres.sql
oc create configmap pg-db-configmap --from-file=2-data-postgres.sql --from-file=1-schema-postgres.sql
```

## Create database deployment

Edit **pg-db.yaml**.
- Modify the **image** path according to your private docker registry.
- Modify the **storageClassName** of **pg-db-pvc**
```
# Get the storage class name of your cluster
oc get sc
```
- Modify the environment variables **POSTGRES_USER** and **POSTGRES_PASSWORD** of **pg-db** deployment

```
oc apply -f pg-db.yaml
```

## Access database

You can find the DB internal service url by command `echo $(oc get svc | grep pg-db | awk '{print$1}').<DB_NAMESPACE>.svc.cluster.local`.

## Example of db secret for ida

```
#Switch to your IDA Instance project:
oc project <ida_project_name>
  
oc create secret generic ida-db-credential --from-literal=DATABASE_USER=postgres \
--from-literal=DATABASE_PASSWORD=password
```
