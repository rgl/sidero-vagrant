#!/bin/bash
source /vagrant/lib.sh


capi_infrastructure_tag='v0.3.0-alpha.1-29-gee36c74'
capi_infrastructure_provider="ruilopes-sidero:$capi_infrastructure_tag"


#
# use custom provider until https://github.com/talos-systems/sidero/pull/501 lands in a proper release.
# see https://github.com/talos-systems/sidero/releases/download/v0.3.0/metadata.yaml
# see https://github.com/talos-systems/sidero/releases/download/v0.3.0/cluster-template.yaml
# see https://github.com/talos-systems/sidero/releases/download/v0.3.0/infrastructure-components.yaml

# NB this block was used to build the image and push it to docker hub.
if false; then
apt-get install -y make
git clone https://github.com/talos-systems/sidero.git
pushd sidero
git checkout ee36c745016a324220b5d17b7ef5fff9d2ce85a8
docker login --username ruilopes
# build and push the image.
make PUSH=true REGISTRY=docker.io USERNAME=ruilopes sidero-controller-manager
# create the manifests and copy them to the host.
# NB these manifests must be commited to this repository.
rm -rf _out /vagrant/capi-manifests
make release
install -d /vagrant/capi-manifests
cp _out/infrastructure-sidero/*/* /vagrant/capi-manifests
sed -i -E "s,ghcr.io/talos-systems/sidero-controller-manager:.+,docker.io/ruilopes/sidero-controller-manager:$capi_infrastructure_tag,g" \
  /vagrant/capi-manifests/infrastructure-components.yaml
popd
fi

# see https://cluster-api.sigs.k8s.io/clusterctl/configuration.html#provider-repositories
# NB you can see the crd with kubectl get crd servers.metal.sidero.dev -o yaml
# NB provider Version must obey the syntax and semantics of the "Semantic Versioning" specification (http://semver.org/) and path format {basepath}/{provider-name}/{version}/{components.yaml}
title 'Adding custom provider to the clusterctl configuration'
capi_infrastructure_provider_path="$HOME/.cluster-api/providers/infrastructure-ruilopes-sidero/$capi_infrastructure_tag"
install -d "$capi_infrastructure_provider_path"
cp /vagrant/capi-manifests/* "$capi_infrastructure_provider_path"
cat >~/.cluster-api/clusterctl.yml <<EOF
providers:
  - name: ruilopes-sidero
    url: file://$capi_infrastructure_provider_path/infrastructure-components.yaml
    type: InfrastructureProvider
EOF
