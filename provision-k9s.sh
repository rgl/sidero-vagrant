#!/bin/bash
source /vagrant/lib.sh


k9s_tag="${1:-v0.24.15}"; shift || true # see https://github.com/derailed/k9s/releases


title "Installing k9s $k9s_tag"
wget -qO- "https://github.com/derailed/k9s/releases/download/$k9s_tag/k9s_Linux_x86_64.tar.gz" \
  | tar xzf - k9s
install -m 755 k9s /usr/local/bin/
rm k9s

# try it.
k9s version
