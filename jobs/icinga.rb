SCHEDULER.every '10s' do
  require 'bundler/setup'
  require 'net/http'
  require 'rubygems'
  require 'json'
  require 'uri'

  # common config file
  dashing_config = './config.yaml'
  config = YAML.load_file(dashing_config)

  # handy function to wrap icinga requests
  def icinga_get(status, auth_key, host='localhost', proto='http', port=80)

    path = "#{proto}://#{host}:#{port}/icinga-web/web/api/service/filter%5BAND(SERVICE_CURRENT_STATE%7C=%7C#{status};SERVICE_CURRENT_STATE%7C=%7C#{status})%5D/columns%5BSERVICE_NAME%7CSERVICE_CURRENT_STATE%5D/countColumn=SERVICE_ID/authkey=#{auth_key}/json"

    uri = URI.parse(path)
    resp = Net::HTTP.get_response(uri)
    return JSON.parse(resp.body)

  end

  # only run if an icinga section exists in the config
  if config.has_key?('icinga')

    # check and update each of the configured icinga envs
    config['icinga'].each do |key, env|

      warning = icinga_get(1, env['auth_key'], env['host'], env['proto'], env['port'])
      critical = icinga_get(2, env['auth_key'], env['host'], env['proto'], env['port'])
  
      status = critical['total'] > 0 ? "red" : (warning['total'] > 0 ? "yellow" : "green")

      send_event('nagios-' + key.to_s, { criticals: critical['total'], warnings: warning['total'], status: status })

    end
  end
end
