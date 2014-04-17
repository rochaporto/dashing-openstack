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
    #resp = compute.request(:simple_tenant_usage) do |params|
    #  params.tenant_id=id
    #end
    #usage = resp.body['tenant_usages'][0]
    #tenant_data['cores_period_usage'] = usage['total_vcpus_usage']
    #tenant_data['ram_period_usage'] = usage['total_memory_mb_usage']
    #tenant_data['hours_period_usage'] = usage['total_hours']
    #tenant_data['localdisk_usage'] = usage['total_local_gb_usage']

    return tenant_data
  end

  def get_hypervisor_data(compute)
    data = Hash.new

    resp = compute.request(:hypervisors) do |params|
      params.detail = true
    end
    hypervisors = resp.body['hypervisors']
    hypervisors.each do |hypervisor|
      name = hypervisor['hypervisor_hostname']
      data[name] = Hash.new
      data[name]['vcpus_used'] = hypervisor['vcpus_used']
      data[name]['vcpus_total'] = hypervisor['vcpus']
      data[name]['ram_used'] = hypervisor['memory_mb_used'] * 1000 * 1000
      data[name]['ram_total'] = hypervisor['memory_mb'] * 1000 * 1000
      data[name]['running_vms'] = hypervisor['running_vms']
    end

    return data
  end

  def convert_num(num)

    if num >= 1024**6
      "#{(num / (1024**6)).ceil} EB"
    elsif num >= 1024**5
      "#{(num / (1024**5)).ceil} PB"
    elsif num >= 1024**4
      "#{(num / (1024**4)).ceil} TB"
    elsif num >= 1024**3
      "#{(num / (1024**3)).ceil} GB"
    elsif num >= 1024**2
      "#{(num / (1024**2)).ceil} MB"
    elsif num >= 1024
      "#{(num / 1024).ceil }KB"
    else
      "#{num}B"
    end
  
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
  session.authenticate

  # start by listing tenants (we'll loop them)
  keystone = session.identity_service
  response = keystone.request(:list_tenants)
  tenants = response.body['tenants']

  tenant_stats = Hash.new
  # retrieve limits and usage info for each tenant, and put in data
  compute = session.compute_service
  tenants.each do |tenant|
    tenant_stats[tenant['name']] = get_tenant_data(compute, tenant['id'])
  end

  # populate the tenant widgets
  {
    'cores' => 'Tenant VCPUs', 'instances' => 'Tenant Instances', 'ram' => 'Tenant Memory', 'floatingips' => 'Tenant IPs',
  }.each do | metric, title |
    data = Array.new
    sorted_tenants = tenant_stats.sort_by {|k, v| v["#{metric}_used"]}.reverse
    for tenant in sorted_tenants[0..5] do
      data.push({
        name: tenant[0], progress: (tenant[1]["#{metric}_used"] * 100.0) / tenant[1]["#{metric}_quota"]
      })
    end
    other = { 'used' => 0.0, 'quota' => 0.0 }
    for tenant in sorted_tenants[6, sorted_tenants.length] do
      other['used'] += tenant[1]["#{metric}_used"].to_f
      other['quota'] += tenant[1]["#{metric}_quota"].to_f
    end
    data.push({
      name: 'other', progress: (other['used'] * 100.0) / other['quota']
    })
    send_event("#{metric}-tenant", { title: title, progress_items: data})
  end

  # retrieve the hypervisor information
  hypervisors_stats = get_hypervisor_data(compute)

  # populate the hypervisor widgets
  {
    'vcpus' => ['Cluster VCPUs', false], 'ram' => ['Cluster Memory', true],
  }.each do |metric, title|
    total = 0
    sum = 0
    hypervisors_stats.each do |name, metrics|
      total += metrics["#{metric}_total"].to_i
      sum += metrics["#{metric}_used"].to_i
    end
    total = total * config['openstack']["#{metric}_allocation_ratio"].to_f
    send_event("#{metric}-hypervisor", { title: title[0], 
                                         value: sum, min: 0, max: total.to_i,
                                         moreinfo: "#{title[1] ? convert_num(sum) : sum} out of #{title[1] ? convert_num(total.to_i) : total.to_i}", 
    })
  end

end
