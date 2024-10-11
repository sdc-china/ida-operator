## Upgrade IDA from v24.0.7 to v24.0.8.1

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
scripts/loadImages.sh -p ida-24.0.8.1.tgz -r $REGISTRY_HOST/ida
```

Step 4. Log in to your cluster

```
oc project <ida_project_name>

#Get ida installer token
TOKENNAME=`oc describe  sa/ida-installer-sa  | grep Tokens |  awk '{print $2}'`
TOKEN=`oc get secret $TOKENNAME -o jsonpath='{.data.token}'| base64 --decode`

#Login by IDA installer token
oc login --token=$TOKEN --server=<OCP_API_SERVER>
```

### Backup IDA

Step 1. Back up the IDA database

Step 2. Back up the IDA instance configuration

```
mkdir -p idabackup
oc get IDACluster/idadeploy -o yaml > idabackup/idadeploy.yaml
```


### Upgrade IDA Operator

Step 1. Switch to the IDA Operator project.

```
oc project <operator_project_name>

#For example:
oc project ida
```

Step 2. Updrade IDA operator to v24.0.8.1.

```
chmod +x scripts/upgradeOperator.sh
scripts/upgradeOperator.sh -i <operator_image>

#Example of using private docker registry:
scripts/upgradeOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.8.1
```

Step 3. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```


### Upgrade IDA Instance

Step 1. Switch to the IDA Instance project.

```
oc project <ida_project_name>

#For example:
oc project ida
```

Step 2. Upgrade IDA Instance.

```
chmod +x scripts/upgradeIDA.sh
scripts/upgradeIDA.sh -i <ida_image>

#Example of using private docker registry:
scripts/upgradeIDA.sh -i $REGISTRY_HOST/ida/ida:24.0.8.1
```

Step 3. Monitor the pod until it shows a STATUS of "Running":

```
oc get pods -w
```

Step 4. Run Database migration page in IDA.

Please refer to IDA doc: https://sdc-china.github.io/IDA-doc/installation/installation-migrating-ida-application.html

Step 5. Restart IDA Pod.

```
oc rollout restart deployments/idadeploy-ida-web

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
chmod +x scripts/upgradeOperator.sh
scripts/upgradeOperator.sh -i <operator_image>

#Example of using private docker registry:
scripts/upgradeOperator.sh -i $REGISTRY_HOST/ida/ida-operator:24.0.7
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
oc get pods -w
```

