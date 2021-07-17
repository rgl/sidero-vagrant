#!/bin/bash
source /vagrant/lib.sh

title 'Install buildx dependencies'
apt-get install -y qemu-user-static

title 'Create local buildx'
docker buildx create \
    --name local \
    --driver docker-container \
    --use
docker buildx ls
