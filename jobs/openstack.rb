SCHEDULER.every '2s' do

  require 'bundler/setup'
  require 'aviator'
  require 'pp'

  def get_tenant_data(compute, id)
    tenant_data = Hash.new

    # limits
    resp = compute.request(:limits) do |params|
      params.tenant_id=id
    end
    limits = resp.body['limits']['absolute']
    tenant_data['instances_used'] = limits['totalInstancesUsed']
    tenant_data['instances_max'] = limits['maxTotalInstances']
    tenant_data['cores_used'] = limits['totalCoresUsed']
    tenant_data['cores_max'] = limits['maxTotalCores']
    tenant_data['ram_used'] = limits['totalRAMUsed']
    tenant_data['ram_max'] = limits['maxTotalRAM']
    tenant_data['floatingips_used'] = limits['totalFloatingIpsUsed']
    tenant_data['floatingips_max'] = limits['maxTotalFloatingIps']
    tenant_data['securitygroups_used'] = limits['totalSecurityGroupsUsed']
    tenant_data['securitygroups_max'] = limits['maxTotalSecurityGroups']
    tenant_data['keypairs_used'] = limits['totalKeypairsUsed']
    tenant_data['keypairs_max'] = limits['maxTotalKeypairs']

    # quotas
    resp = compute.request(:quotas) do |params|
      params.tenant_id=id
    end
    quotas = resp.body['quota_set']
    tenant_data['instances_quota'] = quotas['instances']
    tenant_data['cores_quota'] = quotas['cores']
    tenant_data['ram_quota'] = quotas['ram']
    tenant_data['floatingips_quota'] = quotas['floating_ips']
    tenant_data['securitygroups_quota'] = quotas['security_groups']
    tenant_data['keypairs_quota'] = quotas['key_pairs']

    # usage
    resp = compute.request(:simple_tenant_usage) do |params|
      params.tenant_id=id
    end
    usage = resp.body['tenant_usages'][0]
    tenant_data['cores_period_usage'] = usage['total_vcpus_usage']
    tenant_data['ram_period_usage'] = usage['total_memory_mb_usage']
    tenant_data['hours_period_usage'] = usage['total_hours']
    tenant_data['localdisk_usage'] = usage['total_local_gb_usage']

    return tenant_data
  end

  # common config file
  dashing_config = './config.yaml'
  config = YAML.load_file(dashing_config)

  # handy for test envs, remove if not
  OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

  # session object
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

  # start by listing tenants (we'll loop them)
  keystone = session.identity_service
  response = keystone.request(:list_tenants)
  tenants = response.body['tenants']

  data = Hash.new
  # retrieve limits and usage info for each tenant, and put in data
  compute = session.compute_service
  tenants.each do |tenant|
    data[tenant['name']] = get_tenant_data(compute, tenant['id'])
  end

  # populate the widgets
  {
    'cores' => 'VCPUs', 'instances' => 'Instances', 'ram' => 'Memory', 'floatingips' => 'Floating IPs',
  }.each do | key, title |
    progress = Array.new
    data.sort_by {|k, v| v["#{key}_used"]}.reverse.each do |tenant|
      progress.push({
        name: tenant[0], progress: (tenant[1]["#{key}_used"] * 100.0) / tenant[1]["#{key}_quota"]
      })
    end
    send_event("#{key}-progress", { title: title, progress_items: progress})
  end

end
