#expr_computation_unit = quote

# include("node_memory.jl")
# include("computation_unit_cache.jl")

type ComputationUnit
	process_id::Int
	data_request_queue_to_node_memory::RemoteChannel 
	instruction_queue_from_cluster::RemoteChannel
	num_of_threads::Int

	function ComputationUnit(hostname::String, num_of_threads::Int, 
							 data_request_queue_to_node_memory::RemoteChannel)
		
		process_id = addprocs([hostname])[1]
		instruction_queue_from_cluster = RemoteChannel(addprocs([hostname])[1]) 
		println("ComputationUnit(", hostname, ", ", num_of_threads,") is created.")

		return new(process_id, data_request_queue_to_node_memory, 
				   instruction_queue_from_cluster,
				   num_of_threads)
	end
end

get_process_id(computation_unit::ComputationUnit) = computation_unit.process_id 
get_num_of_threads(computation_unit::ComputationUnit) = computation_unit.num_of_threads
get_instruction_queue(computation_unit::ComputationUnit) = computation_unit.instruction_queue_from_cluster
get_data_request_queue_to_node_memory(computation_unit::ComputationUnit) = computation_unit.data_request_queue_to_node_memory

expr_do_computation_unit = quote

type Cache
	caches::Dict{Int, SharedMatrix{Float64}}
	data_request_queue_to_node_memory::RemoteChannel
	data_receiving_queue::RemoteChannel

	Cache(data_request_queue_to_node_memory::RemoteChannel) = new(Dict{Int,SharedMatrix{Float64}}(),
																  data_request_queue_to_node_memory,
																  RemoteChannel(myid()))
end
get_data_request_queue_to_node_memory(cache::Cache) = cache.data_request_queue_to_node_memory
get_data_receiving_queue(cache::Cache) = cache.data_receiving_queue

function store!(cache::Cache, tile_id::Int, sharedmatrix::SharedMatrix{Float64})
	cache.caches[tile_id] = sharedmatrix
	data_request_queue = get_data_request_queue_to_node_memory(cache)
	instruction_store = ("store", tile_id, sharedmatrix, 0)
	put!(data_request_queue, instruction_store)
	nothing
end
	
function get(cache::Cache, tile_id::Int) 
	if haskey(cache.caches, tile_id)
		return cache.caches[tile_id]
	else
		data_request_queue = get_data_request_queue_to_node_memory(cache)
		data_receiving_queue = get_data_receiving_queue(cache)
		instruction_get = ("get", tile_id, 0, data_receiving_queue)
		put!(data_request_queue, instruction_get)
		sharedmatrix = take!(data_receiving_queue)
		cache.caches[tile_id] = sharedmatrix
		return sharedmatrix
	end
end


function do_computation_unit(num_of_threads::Int, 
							 instruction_queue_from_cluster_controller::RemoteChannel,
							 data_request_queue_to_node_memory::RemoteChannel)

	BLAS.set_num_threads(num_of_threads)
	println("ComputationUnit on ", myid(), " starts running.")
	
	instruction = take!(instruction_queue_from_cluster_controller)
	operator = instruction[1] 
	computation_unit_id = instruction[2]
	response_queue_to_cluster_controller = instruction[4]	
	@assert operator == "init_cluster"
	
	response = ("init_success", computation_unit_id, 0, 0)
	put!(response_queue_to_cluster_controller, response)
	println("Initializing ComputationUnit(", computation_unit_id, ") completed.")

	cache = Cache(data_request_queue_to_node_memory)

	while true
		instruction = take!(instruction_queue_from_cluster_controller)
		operator = instruction[1]
		println("ComputationUnit(", myid(), ") ", operator)

		if operator == "input"
			tile_id = instruction[2]
			sharedmatrix = SharedMatrix{Float64}(instruction[4])
			store!(cache, tile_id, sharedmatrix)
		elseif operator == "matrix-matrix addition"
			tile_id = instruction[2]
			operands = instruction[3]
			tile_id_of_left_operand = operands[1]
			tile_id_of_right_operand = operands[2]
			left_operand = get(cache, tile_id_of_left_operand)
			right_operand = get(cache, tile_id_of_right_operand)
			result = SharedMatrix{Float64}(left_operand + right_operand)
			store!(cache, tile_id, result)
		elseif operator == "matrix-matrix multiplication"
			tile_id = instruction[2]
			operands = instruction[3]
			tile_id_of_left_operand = operands[1]
			tile_id_of_right_operand = operands[2]
			left_operand = get(cache, tile_id_of_left_operand)
			right_operand = get(cache, tile_id_of_right_operand)
			result = SharedMatrix{Float64}(left_operand * right_operand)
			store!(cache, tile_id, result)
		elseif operator == "finalize_cluster"
			response_queue_to_cluster_controller = instruction[4]
			break
		else
			throw("Undefined operator is received.")
		end 
		#=
		operator, result_id, left_operand_id, right_operand_id = instruction

		if operator == MatrixMatrixAddition
			left = get(cache, left_operand_id)
			right = get(cache, right_operand_id)
			result = left + right
			store!(cache, result_id, result)
		elseif operator == MatrixMatrixMultiplication
			left = get_matrix(cache, left_operand_id)
			right = get_matrix(cache, right_operand_id)
			result = left + right
			set_matrix!(cache, result_id, result)
		elseif operator == Terminate
			println("Computation Unit(", myid(), ") finishes.")
			break
		else
			throw("Undefined operator to computation unit")
		end
		=#
		#println("ComputationUnit processed TileID(", tile_id, ").")

	end
	finalize_success_response = ("finalize_success", computation_unit_id, 0, 0)
	put!(response_queue_to_cluster_controller, finalize_success_response)
	println("ComputationUnit(", computation_unit_id, ") terminates.")
end
end # expr_do_computatoin
eval(expr_do_computation_unit)

function computation_unit_do(computation_unit::ComputationUnit)
	process_id = get_process_id(computation_unit)
	num_of_threads = get_num_of_threads(computation_unit)	
	instruction_queue_from_cluster_controller = get_instruction_queue(computation_unit)
	data_request_queue_to_node_memory = get_data_request_queue_to_node_memory(computation_unit)

	@fetchfrom process_id eval(expr_do_computation_unit)
	remote_do(do_computation_unit, process_id, num_of_threads,
			  instruction_queue_from_cluster_controller,	
			  data_request_queue_to_node_memory)
end






