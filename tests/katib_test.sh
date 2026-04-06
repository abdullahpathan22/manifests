#!/bin/bash
set -euxo pipefail

KF_PROFILE=${1:-kubeflow-user-example-com}
KIND_CLUSTER=${2:-kubeflow}

function debug_on_failure {
    echo "=== Test failed! Collecting debug info ==="
    kubectl describe experiment -n "$KF_PROFILE" || true
    kubectl describe trials -n "$KF_PROFILE" || true
    kubectl get pods -n "$KF_PROFILE" || true
    kubectl logs -n kubeflow -l katib.kubeflow.org/component=controller --tail=200 || true
}
trap debug_on_failure ERR

# Pre-pull image to avoid CI wait time being consumed by image pulls
echo "Pre-pulling training image..."
if command -v docker &>/dev/null; then
    docker pull ghcr.io/kubeflow/katib/pytorch-mnist-cpu:v0.19.0 || true
    kind load docker-image ghcr.io/kubeflow/katib/pytorch-mnist-cpu:v0.19.0 \
        --name "$KIND_CLUSTER" || true
else
    echo "Docker not available, skipping pre-pull"
fi

kubectl apply -f tests/katib_test.yaml

echo "Waiting for experiment to reach Running state..."
kubectl wait --for=condition=Running experiments.kubeflow.org \
    -n "$KF_PROFILE" --all --timeout=300s

echo "Waiting for trials to be Succeeded..."
kubectl wait --for=condition=Succeeded trials.kubeflow.org \
    -n "$KF_PROFILE" --all --timeout=600s

kubectl get trials.kubeflow.org -n "$KF_PROFILE"
echo "Katib test passed!"
