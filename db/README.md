# Configure standalone postgresql database by Openshift

## Create new namespace

```
oc new-project ida-db
```

## Create docker hub secrect

```
oc create secret docker-registry docker-hub-secret --docker-server=docker.io --docker-username=<docker_username> --docker-password=<docker_password>
```

## Create database config map

Get **schema-postgres.sql** and **data-postgres.sql** from IDA release package.

```
mv schema-postgres.sql 1-schema-postgres.sql
mv data-postgres.sql 2-data-postgres.sql
oc create configmap pg-db-configmap --from-file=2-data-postgres.sql --from-file=1-schema-postgres.sql
```

## Create database deployment

Edit **pg-db.yaml**.
- Modify the storageClassName of pg-db-pvc
- Modify the environment variables POSTGRES_USER and POSTGRES_PASSWORD of pg-db deployment

```
oc apply -f pg-db.yaml
```

## Access database by adminer router

```
oc get route adminer
```