#!/bin/bash
set -euxo pipefail
kustomize build common/user-namespace/base | kubectl apply -f -
sleep 30 # Let the profile controler reconcile the namespace
PROFILE_CONTROLLER_POD=$(kubectl get pods -n kubeflow -o json | jq -r '.items[] | select(.metadata.name | startswith("profiles-deployment")) | .metadata.name')
kubectl logs -n kubeflow "$PROFILE_CONTROLLER_POD"
KF_PROFILE=kubeflow-user-example-com
kubectl -n $KF_PROFILE get pods,configmaps,secrets
# Verify that the restricted label is indeed applied natively by the Profile Controller
LABEL=$(kubectl get ns $KF_PROFILE \
  -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}')
if [ "$LABEL" != "restricted" ]; then
  echo "ERROR: Namespace is not labeled restricted natively (got: $LABEL)"
  exit 1
fi
echo "Namespace is successfully labeled restricted natively!"
