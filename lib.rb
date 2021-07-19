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
