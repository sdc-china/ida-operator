## Prerequisite steps of Installing the IDA operator with non cluster-admin user

### For Kubernetes

#### Cluster Admin 

```
kubectl create namespace ida
kubectl config set-context --current --namespace=ida
kubectl create sa ida-installer-sa
kubectl apply -f ./docs/rbac/ida-installer-k8s.yml 
kubectl create clusterrolebinding ida-installer-rolebinding --clusterrole=ida-installer --serviceaccount=ida:ida-installer-sa


kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ida-installer-secret
  annotations:
    kubernetes.io/service-account.name: ida-installer-sa
type: kubernetes.io/service-account-token
EOF

TOKEN=`kubectl get secret ida-installer-secret -o jsonpath={.data.token} | base64 -d`
```

#### IDA Installer

```
kubectl config set-credentials ida-installer/<cluster-host>:<port> --token=$TOKEN
kubectl config set-cluster <cluster-host>:<port> --insecure-skip-tls-verify=true --server=https://<cluster-host>:<port>
kubectl config set-context ida/<cluster-host>:<port>/ida-installer --user=ida-installer/<cluster-host>:<port> --namespace=ida --cluster=<cluster-host>:<port>
kubectl config use-context ida/<cluster-host>:<port>/ida-installer
```


### For OpenShift

#### Cluster Admin 

```
oc project ida
oc create sa ida-installer-sa
oc apply -f ./docs/rbac/ida-installer.yml
oc adm policy add-cluster-role-to-user ida-installer -z ida-installer-sa

TOKENNAME=`oc describe  sa/ida-installer-sa  | grep Tokens |  awk '{print $2}'`
TOKEN=`oc get secret $TOKENNAME -o jsonpath='{.data.token}'| base64 --decode`
```

#### IDA Installer

```
oc login --token=$TOKEN --server=<OCP_API_SERVER>
oc project ida
```
