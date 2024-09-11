# System Requirements

## Small profile:

Component | CPU Request (m) | CPU Limit (m) | Memory Request (Mi) | Memory Limit (Mi) | Disk space (Gi) | Access mode | Number of replicas
--- | --- | --- | --- | --- | --- | --- | ---
IDA Operator | 100 | 500 | 256 | 512 |  |  | 1
IDA Web | 1000 | 2000 | 2048 | 4096 | 20 | ReadWriteOnce(RWO) | 1

## Medium profile (Recommended):

Component | CPU Request (m) | CPU Limit (m) | Memory Request (Mi) | Memory Limit (Mi) | Disk space (Gi) | Access mode | Number of replicas
--- | --- | --- | --- | --- | --- | --- | ---
IDA Operator | 100 | 500 | 256 | 512 |  |  | 1
IDA Web | 2000 | 4000 | 4096 | 8192 | 50 | ReadWriteMany(RWX) | 2


## Large profile:

Component | CPU Request (m) | CPU Limit (m) | Memory Request (Mi) | Memory Limit (Mi) | Disk space (Gi) | Access mode | Number of replicas
--- | --- | --- | --- | --- | --- | --- | ---
IDA Operator | 100 | 500 | 256 | 512 |  |  | 1
IDA Web | 2000 | 8000 | 4096 | 16384 | 80 | ReadWriteMany(RWX) | 2