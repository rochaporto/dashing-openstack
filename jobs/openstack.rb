SCHEDULER.every '2s' do
  require 'bundler/setup'
  require 'aviator'

  # common config file
  dashing_config = './config.yaml'
  config = YAML.load_file(dashing_config)

  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

  session = Aviator::Session.new(
    config_file: 'aviator.yml',
    environment: :production,
    log_file:    'aviator.log'
  )
  session.authenticate
 
  keystone = session.identity_service
  response = keystone.request(:list_tenants)
  puts response.body

end
