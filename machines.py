import ipaddress
import json
import logging
import os.path
import re
import socket
import subprocess
import sys
import yaml


def get_dnsmasq_machines():
    for machine in get_machines():
        yield (machine['type'], machine['name'], machine['mac'], machine['ip'])


def save_dnsmasq_machines():
    domain = socket.getfqdn().split('.', 1)[-1]

    def __save(machines, type):
        with open(f'/etc/dnsmasq.d/{type}-machines.conf', 'w') as f:
            for (_, hostname, mac, ip) in (m for m in machines if m[0] == type):
                f.write(f'dhcp-host={mac},{ip},{hostname}\n')

    machines = list(get_dnsmasq_machines())

    __save(machines, 'virtual')
    __save(machines, 'physical')


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
# see https://www.sidero.dev/docs/v0.3/resource-configuration/metadata/
# see https://www.sidero.dev/docs/v0.3/resource-configuration/servers/
# see https://www.sidero.dev/docs/v0.3/resource-configuration/serverclasses/
# see https://www.sidero.dev/docs/v0.3/guides/patching/
# see https://www.sidero.dev/docs/v0.3/guides/first-cluster/
# see https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/#use-a-json-merge-patch-to-update-a-deployment
def save_sidero_machines():
    # add Servers.
    for m in get_machines():
        if 'uuid' not in m:
            continue
        config = {
            'apiVersion': 'metal.sidero.dev/v1alpha1',
            'kind': 'Server',
            'metadata': {
                'name': m['uuid'],
                'labels': {
                    'name': m['name'],
                    'role': m['role'],
                    'arch': m['arch'],
                },
            },
            'spec': {
                'accepted': True,
                'configPatches': [
                    {
                        'op': 'replace',
                        'path': '/machine/install',
                        'value': {
                            'disk': m['installDisk'],
                            'extraKernelArgs': [
                                'ipv6.disable=1'
                            ],
                        },
                    },
                ],
            },
        }
        logging.info(f'Adding the {m["name"]} Server...')
        subprocess.run(['kubectl', 'apply', '-f', '-'], input=yaml.dump(config, encoding='utf-8'), check=True)
    # add ServerClasses.
    for role in ('controlplane', 'worker'):
        config = {
            'apiVersion': 'metal.sidero.dev/v1alpha1',
            'kind': 'ServerClass',
            'metadata': {
                'name': role,
            },
            'spec': {
                'selector': {
                    'matchLabels': {
                        'role': role,
                    },
                },
            },
        }
        logging.info(f'Adding the {role} ServerClass...')
        subprocess.run(['kubectl', 'apply', '-f', '-'], input=yaml.dump(config, encoding='utf-8'), check=True)


def get_machines(prefix='/vagrant'):
    with open(os.path.join(prefix, 'Vagrantfile'), 'r') as f:
        for line in f:
            m = re.match(r'^\s*CONFIG_PANDORA_DHCP_RANGE = \'(.+?),.+?\'', line)
            if m and m.groups(1):
                ip_address = ipaddress.ip_address(m.group(1))
            m = re.match(r'^\s*CONFIG_PANDORA_HOST_IP = \'(.+?)\'', line)
            if m and m.groups(1):
                host_ip_address = ipaddress.ip_address(m.group(1))

    with open(os.path.join(prefix, 'machines.yaml'), 'r') as f:
        machines = yaml.safe_load(f)

    # populate the missing mac address.
    for machine in machines:
        if machine['type'] != 'virtual':
            continue
        if 'mac' not in machine:
            machine['mac'] = '08:00:27:00:00:%02x' % (machine['hostNumber'])

    # populate the missing uuid.
    for machine in machines:
        if machine['type'] != 'virtual':
            continue
        if 'uuid' not in machine:
            machine['uuid'] = '00000000-0000-4000-8000-%s' % (machine['mac'].replace(':', ''))

    # populate the missing ip address.
    for machine in machines:
        if 'ip' not in machine:
            machine['ip'] = str(ip_address + machine['hostNumber'])

    # populate the virtual machines vbmc ip address and port.
    for machine in machines:
        if machine['type'] != 'virtual':
            continue
        machine['bmcType'] = 'ipmi'
        machine['bmcIp'] = str(host_ip_address)
        machine['bmcPort'] = 8000 + machine['hostNumber']
        machine['bmcQmpPort'] = 9000 + machine['hostNumber']

    # populate the machines amt bmc ip address and port.
    for machine in machines:
        if not 'bmcType' in machine:
            continue
        if machine['bmcType'] != 'amt':
            continue
        if 'bmcIp' not in machine:
            machine['bmcIp'] = machine['ip']
        if 'bmcPort' not in machine:
            machine['bmcPort'] = 16992

    # populate the missing installDisk.
    for machine in machines:
        if 'installDisk' not in machine:
            if machine['type'] == 'virtual':
                machine['installDisk'] = '/dev/vda'
            elif machine['type'] == 'physical':
                machine['installDisk'] = '/dev/sda'

    return machines


if __name__ == '__main__':
    logging.basicConfig(level=logging.DEBUG)
    if 'get-machines-json' in sys.argv:
        print(json.dumps(get_machines('.'), indent=4))
    if 'save-dnsmasq-machines' in sys.argv:
        save_dnsmasq_machines()
    if 'save-sidero-machines' in sys.argv:
        save_sidero_machines()
