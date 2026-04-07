#!/bin/bash
set -euxo pipefail

KF_PROFILE=${1:-kubeflow-user-example-com}
KIND_CLUSTER=${2:-kubeflow}

function debug_on_failure {
    echo "=== Test failed! Collecting debug info ==="
    kubectl get trainjobs -n "$KF_PROFILE" || true
    kubectl get pods -n "$KF_PROFILE" || true
    kubectl logs -n kubeflow-system \
        -l app.kubernetes.io/name=trainer --tail=100 || true
}
trap debug_on_failure ERR

kubectl get crd jobsets.jobset.x-k8s.io
kubectl get service jobset-webhook-service -n kubeflow-system
kubectl get mutatingwebhookconfiguration jobset-mutating-webhook-configuration
kubectl get validatingwebhookconfiguration jobset-validating-webhook-configuration

kubectl wait --for=condition=Available deployment/jobset-controller-manager \
    -n kubeflow-system --timeout=120s
kubectl wait --for=condition=Ready pod -l control-plane=controller-manager \
    -n kubeflow-system --timeout=60s

sleep 10

kubectl get endpoints jobset-webhook-service -n kubeflow-system
kubectl get deployment kubeflow-trainer-controller-manager -n kubeflow-system
kubectl get pods -n kubeflow-system -l app.kubernetes.io/name=trainer
kubectl get clustertrainingruntimes torch-distributed

# Install Python dependencies in a virtualenv (works on macOS and CI)
python3 -m venv /tmp/trainer-test-venv
source /tmp/trainer-test-venv/bin/activate
pip install --upgrade pip
pip install "kubeflow[trainer]" kubernetes

python3 tests/trainer_test.py "$KF_PROFILE"
echo "Trainer test passed!"
