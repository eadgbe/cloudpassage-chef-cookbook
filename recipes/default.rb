#
# Cookbook Name:: cloudpassage-halo
# Recipe:: default
#
# Copyright 2015, CloudPassage

# Instantiate config helper

config = node.default

# Add a routine to merge data bag config items over attribute file-configured
# keys

configurator = CloudPassage::ConfigHelper.new(
  config['agent_key'],
  grid_url: config['grid_url'], proxy_host: config['proxy_host'],
  proxy_port: config['proxy_port'], read_only: config['read_only'],
  server_tag: config['server_tag'], server_label: config['server_label'],
  proxy_user: config['proxy_user'],
  proxy_password: config['proxy_password'],
  windows_installer_protocol: config['windows_installer_protocol'],
  windows_installer_host: config['windows_installer_host'],
  windows_installer_port: config['windows_installer_port'],
  windows_installer_path: config['windows_installer_path'],
  windows_installer_file_name: config['windows_installer_file_name'])

# Set up repositories for Linux
case node['platform_family']
when 'debian'
  apt_repository 'cloudpassage' do
    uri config['apt_repo_url']
    key config['apt_key_location']
    not_if config['apt_repo_url'] == ''
  end
when 'rhel'
  yum_repository 'cloudpassage' do
    description 'CloudPassage Halo Repository'
    baseurl config['yum_repo_url']
    gpgkey config['yum_key_location']
    action :create
    not_if config['yum_repo_url'] == ''
  end
# Install and register the Halo agent
when 'debian', 'rhel'
  p_serv_name = 'cphalod'
  package 'cphalo' do
    action [:install, :upgrade]
  end
  execute 'cphalo-config' do
    command [
      'sudo', '/opt/cloudpassage/bin/configure',
      configurator.linux_configuration].join(' ')
    action :run
    # We don't run the configurator if the store.db file already exists
    not_if { File.exist?('/opt/cloudpassage/data/store.db') }
  end
when 'windows'
  p_serv_name = 'CloudPassage Halo Agent'
  windows_package 'CloudPassage Halo' do
    source configurator.windows_installation_path
    options configurator.windows_configuration
    installer_type :custom
    action :install
  end
end

# Now we start the agent using the platform's service manager!
service "#{p_serv_name}" do
  action [:enable, :start]
end
