#!/bin/bash
source /vagrant/lib.sh


clusterapi_version="${1:-0.3.23}"; shift || true


title "Installing clusterctl $clusterapi_version"
wget -qO /usr/local/bin/clusterctl "https://github.com/kubernetes-sigs/cluster-api/releases/download/v$clusterapi_version/clusterctl-linux-amd64"
chmod +x /usr/local/bin/clusterctl
clusterctl version
cp /usr/local/bin/clusterctl /vagrant/shared
