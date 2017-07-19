module TargetHostsHelper

  # @param [Array] target_hosts
  def grouped_by_role(target_hosts)
    target_hosts.reduce({}) do
    # @type accm [Hash]
    # @type target_host [TargetHost]
    |accm, target_host|

      hosts = accm[target_host.role_name] || (accm[target_host.role_name] = [])
      hosts.push(target_host)
      accm
    end
  end
end
