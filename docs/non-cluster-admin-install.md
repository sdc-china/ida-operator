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

## Replace IDA JDBC drivers
```
IDA_POD_NAME=$(oc get pod | grep ida-web | head -n 1 | awk '{print$1}')

# Replace MySQL JDBC driver
oc cp <DB2_JDBC_DRIVER_PATH> $IDA_POD_NAME:/opt/ol/wlp/usr/shared/resources/jdbc/db2/db2jcc4.jar
# Replace MySQL JDBC driver
oc cp <MYSQL_JDBC_DRIVER_PATH> $IDA_POD_NAME:/opt/ol/wlp/usr/shared/resources/jdbc/mysql/mysql-connector-java.jar
# Replace Oracle JDBC driver
oc cp <ORACLE_JDBC_DRIVER_PATH> $IDA_POD_NAME:/opt/ol/wlp/usr/shared/resources/jdbc/oracle/ojdbc8.jar
# Replace PostgreSQL JDBC driver
oc cp <PostgreSQL_JDBC_DRIVER_PATH> $IDA_POD_NAME:/opt/ol/wlp/usr/shared/resources/jdbc/postgres/postgresql.jar

oc delete pod $(oc get pod | grep ida-web | awk '{print$1}')

```


## ResourceQuota

### IDA

```
spec:
  hard:
    limits.cpu: '5'
    limits.memory: 10Gi
    pods: '5'
    requests.cpu: '4'
    requests.memory: 8Gi
```

### IDA & Operator

```
spec:
  hard:
    limits.cpu: '6'
    limits.memory: 12Gi
    pods: '7'
    requests.cpu: '5'
    requests.memory: 10Gi
```

### IDA & Operator & Selenium

```
spec:
  hard:
    limits.cpu: '15'
    limits.memory: 30Gi
    pods: '30'
    requests.cpu: '13'
    requests.memory: 26Gi
```
