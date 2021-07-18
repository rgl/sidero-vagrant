#!/bin/bash
source /vagrant/lib.sh


host_ip_address="$(ip addr show eth1 | perl -n -e'/ inet (\d+(\.\d+)+)/ && print $1')"
first_vm_uuid="$(cat /vagrant/shared/machines.json | jq -r '.[] | select(.type == "virtual") | .uuid' | head -1)"
control_plane_ips="$(cat /vagrant/shared/machines.json | jq -r '.[] | select(.role == "controlplane") | .ip')"
first_control_plane_ip="$(echo "$control_plane_ips" | head -1)"


title 'sidero addresses'
cat <<EOF
http://$host_ip_address/configdata?uuid=$first_vm_uuid

NB we can only use these endpoints after the server was allocated to a cluster.
EOF

title 'addresses'
python3 <<EOF
from tabulate import tabulate

headers = ('service', 'address', 'username', 'password')

def info():
    yield ('theila', 'http://$host_ip_address:8080',  None, None)

print(tabulate(info(), headers=headers))
EOF
