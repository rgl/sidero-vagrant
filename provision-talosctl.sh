#!/bin/bash
source /vagrant/lib.sh


# see https://github.com/talos-systems/talos/releases
talos_version="${1:-0.11.2}"; shift || true


title "Installing talosctl $talos_version"
wget -qO /usr/local/bin/talosctl "https://github.com/talos-systems/talos/releases/download/v$talos_version/talosctl-$(uname -s | tr "[:upper:]" "[:lower:]")-amd64"
chmod +x /usr/local/bin/talosctl
talosctl completion bash >/usr/share/bash-completion/completions/talosctl
talosctl version --client
