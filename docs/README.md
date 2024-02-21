## Prerequisite steps of Installing the IDA operator with non cluster-admin user

### Cluster Admin 


```
oc project ida
oc create sa ida-installer-sa
oc apply -f rbac/ida-installer.yml
oc adm policy add-cluster-role-to-user ida-installer -z ida-installer-sa
```

### IDA Installer

```
oc project ida
TOKENNAME=`oc describe  sa/ida-installer-sa  | grep Tokens |  awk '{print $2}'`
TOKEN=`oc get secret $TOKENNAME -o jsonpath='{.data.token}'| base64 --decode`
oc login --token=$TOKEN --server=<OCP_API_SERVER>
```

