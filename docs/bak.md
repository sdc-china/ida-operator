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

## LimitRange

```
kind: LimitRange
apiVersion: v1
metadata:
  name: project-limits
spec:
  limits:
    - type: Container
      max:
        cpu: '4'
        memory: 8Gi
      min:
        cpu: 50m
        memory: 256Mi
      default:
        cpu: '1'
        memory: 2Gi
      defaultRequest:
        cpu: '1'
        memory: 2Gi
    - type: Pod
      max:
        cpu: '4'
        memory: 8Gi
      min:
        cpu: 50m
        memory: 256Mi
    - type: openshift.io/Image
      max:
        storage: 5Gi
    - type: openshift.io/ImageStream
      max:
        openshift.io/image-tags: '30'
        openshift.io/images: '30'
    - type: PersistentVolumeClaim
      max:
        storage: 20Gi
      min:
        storage: 1Gi

```


## Replace IDA JDBC drivers (Deprecated)
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
