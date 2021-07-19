#!/bin/bash
source /vagrant/lib.sh


theila_tag="${1:-v0.1.0-alpha.1}"; shift || true

theila_image="ghcr.io/talos-systems/theila:$theila_tag"


# until the theila image is available, we built it ourselfs.
docker build -t "$theila_image" - <<EOF
FROM ubuntu:20.04
ADD --chmod=755 https://github.com/talos-systems/theila/releases/download/$theila_tag/theila-linux-amd64 /theila
# TODO remove the next line after https://github.com/moby/buildkit/pull/2171 lands in a docker release.
RUN chmod 755 /theila
ENTRYPOINT ["/theila"]
EOF

title 'Starting theila'
docker run -d \
    --restart=unless-stopped \
    --name theila \
    -p 8080:8080/tcp \
    -v "$HOME/.talos:/root/.talos:ro" \
    -v "$HOME/.kube:/root/.kube:ro" \
    "$theila_image"
