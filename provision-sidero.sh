#!/bin/bash
source /vagrant/lib.sh


control_plane_ip="${1:-10.10.0.2}"; shift || true
capi_version="${1:-0.3.19}"; shift || true
capi_boostrap_provider="${1:-talos:v0.2.0}"; shift || true
capi_control_plane_provider="${1:-talos:v0.1.1}"; shift || true
capi_infrastructure_provider="${1:-sidero:v0.4.0-alpha.0}"; shift || true
talos_version="${1:-0.11.5}"; shift || true
kubernetes_version="${1:-1.21.3}"; shift || true

talos_image="ghcr.io/talos-systems/talos:v$talos_version"


#
# install the sidero local "cluster".
# see https://www.sidero.dev/docs/v0.3/getting-started/prereq-kubernetes/
# NB sidero host ports: 69 (TFTP) and 80 (HTTP).

title 'Creating the sidero local "cluster"'
time talosctl cluster create \
    --name sidero \
    --provisioner docker \
    --image $talos_image \
    --kubernetes-version $kubernetes_version \
    --endpoint $control_plane_ip \
    --nameservers $control_plane_ip \
    --docker-host-ip $control_plane_ip \
    --exposed-ports 69:69/udp,80:8081/tcp,30443:30443/tcp \
    --masters 1 \
    --workers 0 \
    --config-patch '[{"op": "add", "path": "/cluster/allowSchedulingOnMasters", "value": true}]'

title 'Configuring talosctl'
talosctl config endpoints $control_plane_ip
talosctl config nodes $control_plane_ip
talosctl version
install -d -m 700 -o vagrant -g vagrant /home/vagrant/.kube
install -m 600 -o vagrant -g vagrant ~/.kube/config /home/vagrant/.kube/config
cp ~/.kube/config /vagrant/shared/kubeconfig


#
# copy the binaries and configuration to the host.

cp /usr/local/bin/talosctl /vagrant/shared
cp ~/.talos/config /vagrant/shared/talosconfig


#
# install sidero.
# see https://www.sidero.dev/docs/v0.3/getting-started/install-clusterapi/
# see https://www.sidero.dev/docs/v0.3/overview/installation/
# see https://www.sidero.dev/docs/v0.3/resource-configuration/environments/
# see https://github.com/talos-systems/sidero/releases/download/v0.4.0-alpha.0/metadata.yaml
# see https://github.com/talos-systems/sidero/releases/download/v0.4.0-alpha.0/cluster-template.yaml
# see https://github.com/talos-systems/sidero/releases/download/v0.4.0-alpha.0/infrastructure-components.yaml

title 'Installing sidero'
export SIDERO_CONTROLLER_MANAGER_HOST_NETWORK=true
export SIDERO_CONTROLLER_MANAGER_API_ENDPOINT=$control_plane_ip
export SIDERO_CONTROLLER_MANAGER_API_PORT=80 # NB provision-dnsmasq.sh expects port 80.
time clusterctl init \
    --bootstrap "$capi_boostrap_provider" \
    --control-plane "$capi_control_plane_provider" \
    --infrastructure "$capi_infrastructure_provider" \
    --core "cluster-api:v$capi_version"

title 'Waiting for sidero to be ready'
kubectl get deployments --all-namespaces -o json | jq -r '.items[].metadata | [.namespace,.name] | @tsv' | while read ns deployment_name; do
    kubectl -n $ns rollout status deployment $deployment_name
done
while ! kubectl get environment default >/dev/null 2>&1; do sleep 3; done

title "Patching sidero to use talos $talos_version"
kubectl patch environment default --type json --patch-file /dev/stdin <<EOF
- op: replace
  path: /spec/initrd/url
  value: https://github.com/talos-systems/talos/releases/download/v$talos_version/initramfs-amd64.xz
- op: replace
  path: /spec/kernel/url
  value: https://github.com/talos-systems/talos/releases/download/v$talos_version/vmlinuz-amd64
- op: add
  path: /spec/kernel/args/-
  value: ipv6.disable=1
EOF
