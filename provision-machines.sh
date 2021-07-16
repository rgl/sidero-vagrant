#!/bin/bash
source /vagrant/lib.sh


#
# register the machines with dnsmasq.
# NB a server is identified by its SMBIOS UUID.
# NB until a server is accepted, it will be continuously pxe booting
#    talos and rebooting.
# NB after a server is accepted, it will be wiped, and then sidero will
#    stop pxe booting it.
#    NB the Server resource will eventually have the properties:
#           status.isClean: true
#           status.ready: true
# NB the talos configuration file is server by sidero at:
#       http://$control_plane_ip/configdata?uuid=$server_uuid
#    NB we can only use that endpoint after the server was allocated.
# see https://www.sidero.dev/docs/v0.3/resource-configuration/servers/
# see https://www.sidero.dev/docs/v0.3/resource-configuration/metadata/
# see https://www.sidero.dev/docs/v0.3/guides/patching/
# see https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#use-a-json-merge-patch-to-update-a-deployment

title 'Provisioning the machines...'
python3 /vagrant/machines.py save-sidero-machines
