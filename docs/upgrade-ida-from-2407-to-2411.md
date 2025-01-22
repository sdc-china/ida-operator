## Upgrade IDA from v24.0.7 to v24.0.11

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

Step 3. Load IDA docker images

Get the IDA image file **ida-&lt;version&gt;.tgz**, then push it to your private registry.

```
chmod +x scripts/loadImages.sh
scripts/loadImages.sh -p ida-<version>.tgz -r <docker_registry>
  
#Example of using private docker registry:
scripts/loadImages.sh -p ida-24.0.11.tgz -r $REGISTRY_HOST/ida
```

Step 4. Log in to your cluster by either of the two ways.

- Login with OpenShift User

```
oc login <OCP_API_SERVER> -u <ocp_user> -p <password>
```

- Login with IDA installer token

```
#Get ida installer token
oc project <ida_project_name>
TOKENNAME=`oc describe  sa/ida-installer-sa  | grep Tokens |  awk '{print $2}'`
TOKEN=`oc get secret $TOKENNAME -o jsonpath='{.data.token}'| base64 --decode`

#Login by IDA installer token
oc login --token=$TOKEN --server=<OCP_API_SERVER>

```

### Backup IDA

Step 1. Back up the IDA database

Step 2. Back up the Operator deployment and IDA instance configuration

```
oc project <ida_project_name>

mkdir -p idabackup
oc get deployment/ida-operator -o yaml > idabackup/ida-operator.yaml
oc get IDACluster/idadeploy -o yaml > idabackup/idadeploy.yaml
```


### Upgrade IDA Operator

Step 1. Switch to the IDA Operator project.

```
oc project <operator_project_name>

#For example:
oc project ida
```

Step 2. Updrade IDA operator to v24.0.11.

```
oc set env deployment/ida-operator IDA_OPERATOR_IMAGE-
oc set image deployment/ida-operator operator=$REGISTRY_HOST/ida/ida-operator:24.0.11
```

Step 3. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w | grep ida-operator
```


### Upgrade IDA Instance

Step 1. Switch to the IDA Instance project.

```
oc project <ida_project_name>

#For example:
oc project ida
```

Step 2. Create a new copy of the backup custom resource.

  ```
  # Create a new copy of the backup custom resource
  cp idabackup/idadeploy.yaml idabackup/idadeploy-2411.yaml
  
  ```
  
Step 3. Edit the new copy of the backup custom resource.

- **Updating shared configuration parameters**
  
  Update and add below configurations under **spec.shared**.


  ```
    # Image registry URL for all components, can be overridden individually. E.g., example.repository.com
    imageRegistry: <PRIVATE_REGISTRY_URL>
    # Image tag for IDA and Operator, can be overridden individually. E.g., 24.0.11
    imageTag: 24.0.11
    imagePullPolicy: IfNotPresent
    # A list of secrets name to use for pulling images from registries. E.g., ["ida-docker-secret"]
    # You can copy the value from spec.idaWeb.imagePullSecrets
    imagePullSecrets: ["ida-docker-secret"]
  ```
  
- **Updating IDA Web parameters**
  
  Delete below configurations from **spec.idaWeb**.
 

  ```
    image: <IDA_IMAGE>
    imagePullPolicy: Always
    imagePullSecrets: <PULL_SECRET>
  
  ```

  Update and add below configurations under **spec.idaWeb**.
  

  ```
    # IDA Image name. E.g., ida/ida
    imageName: ida/ida
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
 

  ```
 
Step 4. Apply IDA upgrade. 

  ```
   oc apply -f idabackup/idadeploy-2411.yaml --force
  ```

Step 5. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w | grep ida-web
```

Step 6. Run Database migration page in IDA.

Please refer to IDA doc: https://sdc-china.github.io/IDA-doc/installation/installation-migrating-ida-application.html

Step 7. Restart IDA Pod and monitor the pod until it shows a STATUS of "Running".

```
oc rollout restart deployments/idadeploy-ida-web

oc get pods -w | grep ida-web

```

## Rolling back IDA to v24.0.7

### Rolling back IDA database

If your database schema changed during the upgrade, restore your databases from the backups that you made before you upgraded in section [Backup IDA](#backup-ida). Otherwise, you do not need to roll back your database.


### Rolling back IDA Operator

Step 1. Switch to the IDA Operator project.

```
oc project <operator_project_name>

#For example:
oc project ida
```

Step 2. Roll back IDA operator.

```
#Delete the ida operator deployment of the upgraded release.
oc delete deployment/ida-operator

#Apply the backup operator deployment
oc apply -f idabackup/ida-operator.yaml
```

Step 3. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```


### Rolling back IDA Instance

Step 1. Switch to the IDA Instance project.

```
oc project <ida_project_name>

#For example:
oc project ida
```

Step 2. Roll back IDA Instance.

```
#Delete the custom resource of the upgraded release.
oc delete IDACluster/idadeploy

#Apply the backup custom resource
oc apply -f idabackup/idadeploy.yaml
```

Step 3. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w | grep ida-web
```

