if !isdefined(:HostManager) && !isdefined(:Host)

type Host
	hostname::String
	configuration::Vector{Int}

	Host(hostname::String, configuration::Vector{Int}) = new(hostname, configuration)
end
get_hostname(host::Host) = host.hostname
get_configuration(host::Host) = host.configuration

type HostManager
	cluster_hostname::String
	computation_hostnames::Vector{String}
	hostconfigurations::Dict{String, Vector{Int}}

	HostManager(cluster_hostname::String) = new(cluster_hostname, 
												Vector{String}(), 
												Dict{String, Vector{Int}}())
end

get_cluster_hostname(hostmanager::HostManager) = hostmanager.cluster_hostname
get_hostnames(hostmanager::HostManager) = hostmanager.computation_hostnames
get_hostconfiguration(hostmanager::HostManager, hostname::String) = hostmanager.hostconfigurations[hostname]

function add_host!(hostmanager::HostManager, host::Host)
	hostname = get_hostname(host) 
	configuration = get_configuration(host)
	
	push!(hostmanager.computation_hostnames, hostname)
	hostmanager.hostconfigurations[hostname] = configuration
	nothing 
end 

end # if !isdefined(:HostManager)
