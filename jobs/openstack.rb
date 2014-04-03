SCHEDULER.every '2s' do
  require 'bundler/setup'
  require 'aviator'

  # common config file
  dashing_config = './config.yaml'
  config = YAML.load_file(dashing_config)

  # handy for test envs, remove if not
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

  session = Aviator::Session.new(
    config_file: 'config.yaml',
    environment: :aviator,
    log_file:    'aviator.log'
  )
  session.authenticate do |params|
    params.username    = 'admin'
    params.password    = '123456'
    params.tenant_name = 'openstack'
  end

  keystone = session.identity_service
  response = keystone.request(:list_tenants)
  puts response.body

end
