## Upgrade IDA from v25.0.1 to v25.0.4

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

Get the IDA image file, then push it to your private registry.

```
chmod +x scripts/loadImages.sh
scripts/loadImages.sh -p <ida_image_archive> -r <docker_registry>

#Example of loading tar file and using private docker registry:
scripts/loadImages.sh -p ida-25.0.4-java17.tar -r $REGISTRY_HOST

#Example of loading tgz file and using private docker registry:
scripts/loadImages.sh -p ida-25.0.4-java17.tgz -r $REGISTRY_HOST
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

Back up the Operator deployment and IDA instance configuration

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

Step 2. Updrade IDA operator to v25.0.4.

```
oc set image deployment/ida-operator operator=$REGISTRY_HOST/ida-operator:25.0.4
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
  cp idabackup/idadeploy.yaml idabackup/idadeploy-2504.yaml
  
  ```
  
Step 3. Edit the new copy of the backup custom resource.

- **Updating shared configuration parameters**
  
  Update below configurations under **spec.shared**.


  ```
    # Image tag for IDA and Operator, can be overridden individually. E.g., 25.0.4
    imageTag: 25.0.4
  ```
 
Step 4. Apply IDA upgrade. 

  ```
   oc apply -f idabackup/idadeploy-2504.yaml --force
  ```

Step 5. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w | grep ida-web
```


## Rolling back IDA to v25.0.1

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

