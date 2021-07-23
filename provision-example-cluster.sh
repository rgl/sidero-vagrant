#!/bin/bash
source /vagrant/lib.sh


capi_infrastructure_provider="${1:-sidero:v0.4.0-alpha.0}"; shift || true
talos_version="${1:-0.11.3}"; shift || true
kubernetes_version="${1:-1.21.3}"; shift || true

# NB we use the first control plane machine as the bootstrap one.
control_plane_ip="$(cat /vagrant/shared/machines.json | jq -r '.[] | select(.role == "controlplane") | .ip' | head -1)"
control_plane_replicas="$(cat /vagrant/shared/machines.json | jq -r '.[] | select(.role == "controlplane") | .ip' | wc -l)"
worker_replicas="$(cat /vagrant/shared/machines.json | jq -r '.[] | select(.role == "worker") | .ip' | wc -l)"

# see https://www.sidero.dev/docs/v0.3/guides/first-cluster/
# see https://www.sidero.dev/docs/v0.3/getting-started/create-workload/
title 'Provisioning the example cluster...'
TALOS_VERSION="v$talos_version" \
KUBERNETES_VERSION="v$kubernetes_version" \
CONTROL_PLANE_ENDPOINT="$control_plane_ip" \
CONTROL_PLANE_PORT=6443 \
CONTROL_PLANE_SERVERCLASS='controlplane' \
WORKER_SERVERCLASS='worker' \
    clusterctl config cluster \
        example \
        --infrastructure "$capi_infrastructure_provider" \
        >example-cluster.yaml
yq --inplace eval "select(.kind == \"TalosControlPlane\").spec.replicas = $control_plane_replicas" example-cluster.yaml
yq --inplace eval "select(.kind == \"MachineDeployment\").spec.replicas = $worker_replicas" example-cluster.yaml
cp example-cluster.yaml /vagrant/shared
kubectl apply -f example-cluster.yaml
