#!/bin/bash

# This script need to be executed under root path ida-operator

oc delete -f descriptors/operator.yaml
oc delete -f cluster-role-binding.yaml
oc delete -f descriptors/cluster-role.yaml
oc delete -f descriptors/role-binding.yaml
oc delete -f descriptors/role.yaml
oc delete -f descriptors/service-account.yaml
oc patch crd/idaclusters.sdc.ibm.com -p '{"metadata":{"finalizers":[]}}' --type=merge
oc delete crd idaclusters.sdc.ibm.com

echo "All descriptors have been successfully deleted."
