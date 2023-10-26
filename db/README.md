# Configure standalone postgresql database by Openshift

## Create new namespace

```
oc new-project ida-db
```

## Create docker hub secrect

```
oc create secret docker-registry docker-hub-secret --docker-server=docker.io --docker-username=<docker_username> --docker-password=<docker_password>
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
- Modify the **storageClassName** of **pg-db-pvc**
- Modify the environment variables **POSTGRES_USER** and **POSTGRES_PASSWORD** of **pg-db** deployment

```
oc apply -f pg-db.yaml
```

## Access database by Adminer

```
echo "http://$(oc get route | grep adminer | awk '{print$2}')"
```

## Example of db secret for ida

```
oc create secret generic ida-external-db-secret --from-literal=DATABASE_SERVER_NAME=db.ida-db.svc.cluster.local \
--from-literal=DATABASE_NAME=idaweb \
--from-literal=DATABASE_PORT_NUMBER=5432 \
--from-literal=DATABASE_USER=postgres \
--from-literal=DATABASE_PASSWORD=password
```
