require 'open3'

def virtual_machines
  configure_virtual_machines
  machines = JSON.load(File.read('shared/machines.json')).select{|m| m['type'] == 'virtual'}
  machines.each_with_index.map do |m, i|
    [m['name'], m['arch'], m['firmware'], m['ip'], m['uuid'], m['mac'], m['bmcIp'], m['bmcPort'], m['bmcQmpPort']]
  end
end

def configure_virtual_machines
  stdout, stderr, status = Open3.capture3('python3', 'machines.py', 'get-machines-json')
  if status.exitstatus != 0
    raise "failed to run python3 machines.py get-machines-json. status=#{status.exitstatus} stdout=#{stdout} stderr=#{stderr}"
  end
  FileUtils.mkdir_p 'shared'
  File.write('shared/machines.json', stdout)
end

def vbmc_domain_name(machine)
  "#{File.basename(File.dirname(__FILE__))}_#{machine.name}"
end

def vbmc_container_name(machine)
  "vbmc-emulator-#{vbmc_domain_name(machine)}"
end

def vbmc_up(machine, bmc_ip, bmc_port)
  vbmc_destroy(machine)
  domain_name = vbmc_domain_name(machine)
  container_name = vbmc_container_name(machine)
  config_base_path = File.expand_path("tmp/#{container_name}")
  machine.ui.info("Creating the #{container_name} docker container...")
  FileUtils.mkdir_p("#{config_base_path}/#{domain_name}")
  File.write("#{config_base_path}/virtualbmc.conf", """\
[default]
pid_file = /vbmc.pid
[log]
debug = true
""")
  File.write("#{config_base_path}/#{domain_name}/config", """\
[VirtualBMC]
username = admin
password = password
address = 0.0.0.0
port = 6230
domain_name = #{domain_name}
libvirt_uri = qemu:///system
active = true
""")
  stdout, stderr, status = Open3.capture3(
    'docker',
    'run',
    '--name',
    container_name,
    '--detach',
    '-v',
    '/var/run/libvirt/libvirt-sock:/var/run/libvirt/libvirt-sock',
    '-v',
    '/var/run/libvirt/libvirt-sock-ro:/var/run/libvirt/libvirt-sock-ro',
    '-v',
    "#{config_base_path}:/root/.vbmc:ro",
    '-p',
    "#{bmc_ip}:#{bmc_port}:6230/udp",
    'ghcr.io/rgl/virtualbmc:v2.2.2')
  if status.exitstatus != 0
    if stderr.include? 'No such container'
      return
    end
    raise "failed to run the #{container_name} docker container. status=#{status.exitstatus} stdout=#{stdout} stderr=#{stderr}"
  end
end

def vbmc_destroy(machine)
  container_name = vbmc_container_name(machine)
  stdout, stderr, status = Open3.capture3('docker', 'inspect', container_name)
  if status.exitstatus != 0
    if stderr.include? 'No such object'
      return
    end
    raise "failed to inspect the #{container_name} docker container. status=#{status.exitstatus} stdout=#{stdout} stderr=#{stderr}"
  end
  container = JSON.parse(stdout)[0]
  if container['State']['Running']
    machine.ui.info("Stopping the #{container_name} docker container...")
    stdout, stderr, status = Open3.capture3('docker', 'kill', '--signal', 'INT', container_name)
    if status.exitstatus != 0
      if stderr.include? 'No such container'
        return
      end
      raise "failed to kill the #{container_name} docker container. status=#{status.exitstatus} stdout=#{stdout} stderr=#{stderr}"
    end
    stdout, stderr, status = Open3.capture3('docker', 'wait', container_name)
    if status.exitstatus != 0
      if stderr.include? 'No such container'
        return
      end
      raise "failed to wait for the #{container_name} docker container. status=#{status.exitstatus} stdout=#{stdout} stderr=#{stderr}"
    end
  end
  machine.ui.info("Destroying the #{container_name} docker container...")
  stdout, stderr, status = Open3.capture3('docker', 'rm', '-f', container_name)
  if status.exitstatus != 0
    if stderr.include? 'No such container'
      return
    end
    raise "failed to destroy the #{container_name} docker container. status=#{status.exitstatus} stdout=#{stdout} stderr=#{stderr}"
  end
end
