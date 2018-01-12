expr_computation_unit_cache = quote


type ComputationUnitCache
	data_request_queue::RemoteChannel
	data_receiving_queue::RemoteChannel 
	cached_matrices::Dict{Int, SharedMatrix{Float64}}
	
	function ComputationUnitCache(data_request_queue::RemoteChannel)
		data_receiving_queue = RemoteChannel(myid())
		cached_matrices = Dict{Int, SharedMatrix{Float64}}()
		return new(data_request_queue, data_receiving_queue, cached_matrices)
	end
end

import Base.get
function get(cache::ComputationUnitCache, id::Int) 
	if haskey(cache.cached_matrices, id)
		return cache.cached_matrices[id] 
	else
		request_instruction = "local_request", id, cache.data_receiving_queue 
		put!(cache.data_request_queue, request_instruction)
		cache.cached_matrices[id] = take!(cache.data_receiving_queue)
	end
end

function store!(cache::ComputationUnitCache, id::Int, sharedmatrix::SharedMatrix{Float64})
	cache.cached_matrices[id] = sharedmatrix
	request_instruction = "store", id, sharedmatrix
	put!(cache.data_request_queue, request_instruction)
end

end # expr_computation_unit_cache

eval(expr_computation_unit_cache)


