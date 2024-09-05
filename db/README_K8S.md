# Configure standalone postgresql database by Kubernetes

## Create new namespace

```
kubectl create namespace ida-db
kubectl config set-context --current --namespace=ida-db
```

## Create private docker registry secret

```
kubectl create secret docker-registry docker-secret --docker-server=<docker_registry>  --docker-username=<docker_username> --docker-password=<docker_password>
```

## Create database configmap

Get **schema-postgres.sql** and **data-postgres.sql** from IDA release package.

```
mv schema-postgres.sql 1-schema-postgres.sql
mv data-postgres.sql 2-data-postgres.sql
kubectl create configmap pg-db-configmap --from-file=2-data-postgres.sql --from-file=1-schema-postgres.sql
```

## Create database deployment

Edit **pg-db.yaml**.
- Modify the **image** path according to your private docker registry.
- Modify the **storageClassName** of **pg-db-pvc**
```
# Get the storage class name of your cluster
kubectl get sc
```
- Modify the environment variables **POSTGRES_USER** and **POSTGRES_PASSWORD** of **pg-db** deployment

```
kubectl apply -f pg-db.yaml
```

## Access database

You can find the DB internal service url by command `echo $(kubectl get svc | grep pg-db | awk '{print$1}').<DB_NAMESPACE>.svc.cluster.local`.

## Example of db secret for ida

```
#Switch to your IDA Instance namespace:
kubectl config set-context --current --namespace=<ida_namespace>
  
kubectl create secret generic ida-external-db-credential --from-literal=DATABASE_USER=postgres \
--from-literal=DATABASE_PASSWORD=password
```
