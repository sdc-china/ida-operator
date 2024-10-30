# IDA Helm Charts

## Load IDA docker image
ida-24.0.8.1.tgz is provided in the IDA release package.
```
tar -zxvf ida-24.0.8.1.tgz
docker load --input images/ida-operator-24.0.8.1.tar.gz
docker load --input images/ida-24.0.8.1.tar.gz
```

## Prepare Helm Charts values.yaml

Example of values.yaml

```
idaDatabase:
  # Database type. The possible values are "mysql", "postgres", "db2" and "oracle".
  type: postgres
  internal:
    # Enable internal database for demo purpose.
    enabled: false
  external:
    # Enable external database for production purpose.
    enabled: true
    # The JDBC URL. Only Oracle is supported. E.g., jdbc:oracle:thin:@serverName:port:databaseName
    #databaseUrl:
    # Database instance name, for database except Oracle. E.g., ida
    databaseName: ida
    # Database port, for database except Oracle. E.g., 5432
    databasePort: 5432
    # Database server name in the form of either a fully qualified domain name (FQDN) or an IP address, for database except Oracle. E.g., example.postgre.com
    databaseServerName: example.postgre.com
    # Database schema name. This parameter is optional. E.g., databaseschema
    #currentSchema:
    # Secret name that contains the DATABASE_USER and DATABASE_PASSWORD keys.
    databaseCredentialSecret: ida-db-credential

operator:
  image: ida-operator:24.0.8.1

idaWeb:
  # Image URL
  image: ida:24.0.8.1
  # Image pull policy
  imagePullPolicy: Always
  # Image Pull secrets
  imagePullSecrets: ida-docker-secret
  # Number of IDA pods.
  replicas: 1
  resources:
    requests:
      # Minimum number of CPUs for IDA container.
      cpu: 2000m
      # Minimum amount of memory required for IDA container.
      memory: 4096Mi
    limits:
      # Maximum number of CPUs allowed for IDA container.
      cpu: 4000m
      # Maximum amount of memory allowed for IDA container.
      memory: 8192Mi
  storage:
    #The existing PVC for the persisted IDA data. E.g., ida-data-pvc
    existingDataPVCName: ida-data
  initContainer:
    resources:
      requests:
        # Minimum number of CPUs for IDA init containers.
        cpu: 100m
        # Minimum amount of memory required for IDA init containers.
        memory: 256Mi
      limits:
        # Maximum number of CPUs allowed for IDA init containers.
        cpu: 200m
        # Maximum amount of memory allowed for IDA init containers.
        memory: 512Mi
  #jvmArgs:
  # Secret name that contains the files tls.crt and tls.key for IDA. E.g., ida-tls-secret.
  #tlsCertSecret:
  # Secret name that contains trusted certificate files. E.g., ida-trusted-secret.
  #trustedCertSecret:
  serviceType: ClusterIP
  serviceAccountName: default

```

## Install IDA
```
helm install idadeploy idaweb-helm --repo https://sdc-china.github.io/ida-operator -f values.yaml 
```
