# Install IDA and Selenium with ArgoCD + Kustomize + Helm Charts

## Prerequisites

### Enable helm build option in ArgoCD

Patch config map **argocd-cm** of your ArgoCD deployment.

```
kubectl patch configmap/argocd-cm --type merge -p '{"data":{"kustomize.buildOptions":"--enable-helm"}}'
```

More details refer to doc [https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/#kustomizing-helm-charts](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/#kustomizing-helm-charts)

### Setup private IDA Helm Charts Repository

1. The helm charts repository can be hosted by any web server, the layout of the repository looks like this:

```
charts/
  |
  |- index.yaml
  |
  |- idaweb-helm-24.0.7.tgz
  |
  |- selenium-grid-0.28.4.tgz
```

2. Download [idaweb-helm-24.0.7.tgz](https://github.com/sdc-china/ida-operator/releases/download/24.0.7/idaweb-helm-24.0.7.tgz), and upload it to your private repository.

3. Download [selenium-grid-0.28.4.tgz](https://github.com/SeleniumHQ/docker-selenium/releases/download/selenium-grid-0.28.4/selenium-grid-0.28.4.tgz), and upload it to your private repository.

4. Create **index.yaml**, and then upload it to your private repository. Example:

```
apiVersion: v1
entries:
  idaweb-helm:
  - apiVersion: v2
    appVersion: 24.0.7
    created: "2024-09-06T04:01:18.106366179-07:00"
    description: A Helm chart for creating a IDA Web Server in Kubernetes
    digest: 46479ea5108923c0ceff6d5b78e25380f3354951ac1ea67749f05bfdf9e87a8a
    name: idaweb-helm
    type: application
    urls:
    - https://<YOUR_PRIVATE_REPO_HOST>/charts/idaweb-helm-24.0.7.tgz
    version: 24.0.7
  selenium-grid:
  - apiVersion: v2
    appVersion: 4.18.1-20240224
    created: "2024-03-05T06:31:21.030214418Z"
    description: A Helm chart for creating a Selenium Grid Server in Kubernetes
    digest: 5aff9afb7b6e7d90bc9d02f8d242eca7b536f0c849d7c7f8fdf957405484df5f
    icon: https://github.com/SeleniumHQ/docker-selenium/raw/trunk/logo.png
    maintainers:
    - email: selenium-developers@googlegroups.com
      name: SeleniumHQ
    name: selenium-grid
    sources:
    - https://github.com/SeleniumHQ/docker-selenium
    type: application
    urls:
    - https://<YOUR_PRIVATE_REPO_HOST>/charts/selenium-grid-0.28.4.tgz
    version: 0.28.4
generated: "2024-09-06T04:01:17.548051179-07:00"
```

More details please refer to doc [https://helm.sh/docs/topics/chart_repository](https://helm.sh/docs/topics/chart_repository).

## IDA Installation

### Initial IDA Database

Please refer to doc 
[https://sdc-china.github.io/IDA-doc/installation/installation-database-installation-and-configuration.html#install-and-configure-postgresql-db](https://sdc-china.github.io/IDA-doc/installation/installation-database-installation-and-configuration.html#install-and-configure-postgresql-db)

### Push IDA docker images to your private docker registry

Please refer to doc [https://github.com/sdc-china/ida-operator?tab=readme-ov-file#before-you-begin](https://github.com/sdc-china/ida-operator?tab=readme-ov-file#before-you-begin)

### Create docker registry secret

```
kubectl create secret docker-registry ida-docker-secret --docker-server=<PRIVATE_DOCKER_REGISTRY> --docker-username=<USERNAME> --docker-password=<PASSWORD>
```

### Create ida-external-db-credential.yaml for DB secrets

```
apiVersion: v1
kind: Secret
metadata:
  name: "ida-external-db-credential"
stringData:
  DATABASE_USER: "postgres"
  DATABASE_PASSWORD: "password"
```

### create ida-data-pvc.yaml

To enable IDA high availability topology, please use ReadWriteMany accessMode storage.

```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ida-data
spec:
  storageClassName: ida-data
  accessModes:
    - ReadWriteMany
  capacity:
    storage: 50Gi
  nfs:
    path: /<filestore-file-share-name>/ida-data
    server: <filestore-instance-ip>
  persistentVolumeReclaimPolicy: Retain  

---

apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ida-data
spec:
  storageClassName: ida-data
  accessModes:
    - ReadWriteMany
  volumeName: ida-data
  resources:
    requests:
      storage: 50Gi
```

More details about storage access mode, please refer to [https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes)


### Create values.yaml for IDA helm charts parameters

```
# IDA chart values
idaDatabase:
  # Database type, the value could be mysql, postgres, db2, oracle
  type: postgres
  internal:
    enabled: false
  external:
    enabled: true
    databaseName: idaweb
    databasePort: 5432
    databaseServerName: localhost
    currentSchema:
    # The secret for database username and password
    databaseCredentialSecret: ida-external-db-credential

operator:
  image: <PRIVATE_DOCKER_REGISTRY>/ida/ida-operator:24.0.7

idaWeb:
  image: <PRIVATE_DOCKER_REGISTRY>/ida/ida:24.0.7
  imagePullPolicy: Always
  imagePullSecrets: ida-docker-secret
  replicas: 2
  resources:
    cpuLimit: 4
    cpuRequest: 2
    memoryLimit: 8Gi
    memoryRequest: 4Gi
  storage:
    existingDataPVCName: ida-data
  tlsCert:
  ldapCert:
  serviceType: ClusterIP
```

### Create Kustomization.yaml for ArgoCD project

The resources that are not managed by IDA helm charts can be added to the **resources** section.
The customization for existing IDA helm charts resources can be added to the **patches** section.

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ida-external-db-credential.yaml
- ida-data-pvc.yaml
- cloud-sql-sa.yaml
- dns.yaml
- dns-proxy.yaml
- ingress_gke.yaml

patches:
- path: cloud-sql-proxy.yaml

helmCharts:
- name: idaweb-helm
  repo: https://<YOUR_PRIVATE_REPO_HOST>/charts
  version: 24.0.7
  releaseName: idaweb-helm
  namespace: <NAMESPACE>
  valuesFile: values.yaml
```

### Example of cloud-sql-proxy.yaml which enable the sidecar container in IDA deployment.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: idaweb-helm-ida-web
spec:
  template:
    spec:
      containers:
        - name: cloud-sql-proxy
          # It is recommended to use the latest version of the Cloud SQL proxy
          # Make sure to update on a regular schedule!
          image: nexus3.systems.uk.hsbc:18080/com/hsbc/group/itid/es/safe/cloud-sql-proxy:2.11.0
          imagePullPolicy: IfNotPresent
          args:
            # If connecting from a VPC-native GKE cluster, you can use the
            # following flag to have the proxy connect over private IP
            - "--private-ip"
            # Replace DB_PORT with the port the proxy should listen on
            - "--port=5432"
            - "xxx"
            - "--auto-iam-authn"          
          ports:
          - name: tcp-db
            containerPort: 5432
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
              - all
            runAsNonRoot: true
            runAsUser: 1000
          resources:
            limits:
              cpu: 1
              memory: 1Gi
            requests:
              memory: 256Mi
              cpu: 100m
```

## Selenium Installation

### Create values.yaml for IDA helm charts parameters

```
global:
  seleniumGrid:
    imageTag: '4.18.1'
    nodesImageTag: '122.0'

basicAuth:
  enabled: false

ingress:
  enabled: false

edgeNode:
  enabled: true
  service:
    enabled: false
  replicas: 4

chromeNode:
  enabled: true
  service:
    enabled: false
  replicas: 4

firefoxNode:
  enabled: false
  deploymentEnabled: false
  service:
    enabled: false
  service:
    enabled: false
```

### Create Kustomization.yaml for ArgoCD project

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
- name: selenium-grid
  repo: https://<YOUR_PRIVATE_REPO_HOST>/charts
  version: 0.28.4
  releaseName: selenium-grid
  namespace: <NAMESPACE>
  valuesFile: values.yaml
```