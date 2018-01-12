type CachedMatrix
	key::Int
	matrix::SharedMatrix{Float64}
	last_access_time::Int
end

get_key(cached_matrix::CachedMatrix) = cached_matrix.key
get_matrix(cached_matrix::CachedMatrix) = cached_matrix.matrix
get_last_access_time(cache_matrix::CachedMatrix) = cached_matrix.last_access_time
function update_last_access_time!(cache_matrix::CachedMatrix, access_time::Int) 
	cached_matrix.last_access_time = access_time
end

type CacheInComputationUnits
	request_queue_to_memory::RemoteChannel
	capacity::Int
	cached_matrices::Vector{CachedData}
	current_time::Int

	function CacheInComputationUnits(capacity::Int )
		current_time = 0
		cached_matrices = Vector{CachedData}()
		return new(memory, capacity, cached_matrices, current_time)
	end
end
export CacheInComputationUnits

function get_current_access_time!(cache::CacheInComputationUnits)
	cache.current_time += 1
	return cache.current_time
end

function get!(cache::CacheInComputationUnits, key::Int) 
	for cached_matrix = cache.cached_matrices
		if getkey(cached_matrix) == key
			return getmatrix(cached_matrix)
		end
	end
	data_request_queue_to_memory 
end
export get!
function isfull(cache::CacheInComputationUnits)
	return cache.capacity == length(cache.cached_matrices)
end

function delete_oldest_matrix!(cache::CacheIncomputationUnits)
	oldest_time = cache.last_time 
	oldest_index = 0
	for i=1:cached_matrix = cache.cached_matrices
		used_time = get_used_time(Cached_matrix)
		if oldest > used_time
			oldest = used_time
		end
	end
end

function store!(cache::CacheInComputationUnits, 
				key::Int, matrix::SharedMatrix{Float64})
	
	access_time = get_current_access_time!(cache)
	cached_matrix = CachedMatrix(key, matrix, acc

	if !isfull(cache) 
		push!(cache.cached_matrices, cached_matrix)
	else
	

	end
end

