if !isdefined(:Cluster)

include("hostmanager.jl") 
include("data_directory.jl")
include("computation_node.jl")
include("dependency_graph.jl")
include("tiled_dependency_graph.jl")
include("executor.jl")

type Cluster
	hostname::String
	process_id::Int

	data_directory::DataDirectory
	computation_nodes::Vector{ComputationNode}
	data_request_queues_to_node_memories::Dict{String, RemoteChannel} 

	computation_units::Dict{Int, ComputationUnit}	
	instruction_queues_to_computation_units::Dict{Int, RemoteChannel}

	instruction_queue_from_client::RemoteChannel
	response_queue_to_client::RemoteChannel

	function Cluster(hostmanager::HostManager)	
		cluster_hostname = get_cluster_hostname(hostmanager)
		hostname = cluster_hostname
		process_id = addprocs([hostname])[1]
		
		data_directory = DataDirectory(hostname)
		data_request_queue_to_data_directory = get_data_request_queue(data_directory)

		computation_nodes = Vector{ComputationNode}()
		data_request_queues_to_node_memories = Dict{String, RemoteChannel}()

		last_computation_unit_id = 0
		computation_units = Dict{Int, ComputationUnit}()
		instruction_queues_to_computation_units = Dict{Int, RemoteChannel}()
		
		for hostname = get_hostnames(hostmanager)
			hostconfiguration = get_hostconfiguration(hostmanager, hostname)
			computation_node = ComputationNode(hostname, hostconfiguration, 
											   data_request_queue_to_data_directory)
			push!(computation_nodes, computation_node)
			data_request_queue = get_data_request_queue(computation_node)
			data_request_queues_to_node_memories[hostname] = data_request_queue

			for computation_unit = get_computation_units(computation_node) 
				last_computation_unit_id += 1
				computation_units[last_computation_unit_id] = computation_unit
				instruction_queues_to_computation_units[last_computation_unit_id] = get_instruction_queue(computation_unit)
			end
		end
		
		instruction_queue_from_client = RemoteChannel(addprocs([hostname])[1])
		response_queue_to_client = RemoteChannel(addprocs([hostname])[1])

		println("Cluster is created.")

		return new(hostname, process_id, data_directory,
				   computation_nodes, data_request_queues_to_node_memories,
				   computation_units, instruction_queues_to_computation_units,
				   instruction_queue_from_client, response_queue_to_client)
	end
end

get_hostname(cluster::Cluster) = cluster.hostname
get_process_id(cluster::Cluster) = cluster.process_id
get_data_request_queue_to_data_directory(cluster::Cluster) = get_data_request_queue(cluster.data_directory)
get_response_queue_to_client(cluster::Cluster) = cluster.response_queue_to_client
get_instruction_queue(cluster::Cluster) = cluster.instruction_queue_from_client

get_data_directory(cluster::Cluster) = cluster.data_directory
get_computation_nodes(cluster::Cluster) = cluster.computation_nodes
get_data_request_queues_to_node_memories(cluster::Cluster) = cluster.data_request_queues_to_node_memories
get_instruction_queues_to_computation_units(cluster::Cluster) = cluster.instruction_queues_to_computation_units

#=
get_computation_units(cluster::Cluster) = cluster.computation_units
get_instruction_queue(cluster::Cluster) = cluster.instruction_queue

function add_computation_node!(cluster::Cluster, computation_node::ComputationNode) 
	computation_units = get_computation_units(cluster)
	for computation_unit = get_computation_units(computation_node)
		push!(computation_units, computation_unit)
	end
end

end # expr_type_cluster
eval(expr_type_cluster)
=#

expr_do_cluster = quote
function do_cluster(instruction_queue::RemoteChannel, 
					data_directory_queue::RemoteChannel,
					response_queue_to_client::RemoteChannel, 
					data_request_queues_to_node_memories::Dict{String, RemoteChannel},
					instruction_queues_to_computation_units::Dict{Int, RemoteChannel},
					hostname::String)


	println("Cluster (", hostname, ", ", myid(), ") starts running.")
	const receiving_response_queue = RemoteChannel(myid())

	init_cluster_instruction = ("init_cluster", 0, 0, 
								receiving_response_queue)
	put!(data_directory_queue, init_cluster_instruction)
	response = take!(receiving_response_queue)
	@assert response[1] == "init_success"
	println("Initializing data directory completed successfully.")


	for hostname = keys(data_request_queues_to_node_memories)
		data_request_queue_to_node_memory = data_request_queues_to_node_memories[hostname]
		init_cluster_instruction = ("init_cluster", hostname, 0,
									receiving_response_queue)
		put!(data_request_queue_to_node_memory, init_cluster_instruction)
		response = take!(receiving_response_queue)
		@assert response[1] == "init_success"
		@assert response[2] == hostname
	end
	println("Initializing all node memories completed successfully.")

	for computation_unit_id = keys(instruction_queues_to_computation_units)
		instruction_queue_to_computation_unit = instruction_queues_to_computation_units[computation_unit_id]
		init_cluster_instruction = ("init_cluster", computation_unit_id, 
								0, receiving_response_queue)
		put!(instruction_queue_to_computation_unit, init_cluster_instruction)
		
		response  = take!(receiving_response_queue) 
		@assert response[1] == "init_success"
		@assert response[2] == computation_unit_id
	end
	println("Initializing all computation units completed successfully.")
	const init_success_response = ("init_success", 0, 0, 0)
	put!(response_queue_to_client, init_success_response)	
	
	input_matrices = Dict{Int, Matrix{Float64}}()
	dependency_graph = DependencyGraph()


	while true
		instruction = take!(instruction_queue)
		operator = instruction[1]

		println("Cluster took ", operator, " operator.")
		if operator == "input"
			parmatrix_id = instruction[2]
			dimensions = instruction[3]
			matrix = take!(instruction_queue)
			input_matrices[parmatrix_id] = matrix

			lazymatrix = LazyMatrix(operator, parmatrix_id, dimensions)
			add!(dependency_graph, lazymatrix)
			println("ParMatrixID(", parmatrix_id, ") is added to dependency graph")
	
		elseif operator == "matrix-matrix addition"
			parmatrix_id = instruction[2]
			dimensions = instruction[3]
			operands = instruction[4]

			lazymatrix = LazyMatrix(operator, parmatrix_id, dimensions, operands)
			add!(dependency_graph, lazymatrix)
			println("ParMatrixID(", parmatrix_id, ") is added to dependency graph")
	
		elseif operator == "matrix-matrix multiplication"
			parmatrix_id = instruction[2]
			dimensions = instruction[3]
			operands = instruction[4]
			
			lazymatrix = LazyMatrix(operator, parmatrix_id, dimensions, operands)
			add!(dependency_graph, lazymatrix)
			println("ParMatrixID(", parmatrix_id, ") is added to dependency graph")
		elseif operator == "getvalue"
			parmatrix_id = instruction[2]
			tiled_dependency_graph = TiledDependencyGraph(12000)
			add_tiles!(tiled_dependency_graph, dependency_graph, parmatrix_id)
			#show_matches(tiled_dependency_graph)
			#show_dependency_graph(tiled_dependency_graph)
	
			@time res = execute(tiled_dependency_graph, parmatrix_id,
					input_matrices,
					instruction_queues_to_computation_units,
					data_directory_queue,
					response_queue_to_client)	
			
			put!(response_queue_to_client, ("done", 0, 0, res))
		elseif operator == "show_dependency_graph"
			show_dependency_graph(dependency_graph)
			put!(response_queue_to_client, ("done", 0, 0, 0))

		elseif operator == "finalize_cluster"
			break
		
		else
			throw("Undefined operator to cluster.")
		end
	end


	#=
	parmatrix_dependency_graph = ParMatrixDependencyGraph()
	
	while true
		instruction = take!(instruction_queue)
		println("Received Instruction - Cluster Controller.")
		
		operator, id, source = instruction

		if operator == "matrix-matrix addition" ||
			operator == "matrix-matrix multiplication"
			
			parmatrix_id = id
			dimensions, parmatrix_ids_of_operands = source

			parmatrix_operation = ParMatrixOperation(operator, parmatrix_id, 
													 dimensions, 
													 parmatrix_ids_of_operands) 
			add_parmatrix_operation!(parmatrix_dependency_graph,
									parmatrix_operation) 
		
			println(operator, "(", parmatrix_id, ")\t", dimensions)
			println("(", parmatrix_ids_of_operands[1], ", ", parmatrix_ids_of_operands[2], ")")


		
		elseif operator == "terminate"
			println("Cluster Controler terminates")
			put!(data_directory_queue, instruction)

			put!(source, ("terminate", 0, 0))
			break
		elseif operator == "test"
			
			 
				
		else
		end 
	end
	println("All systems terminated.")
	instruction = ("terminate", 0, 0, 0)
	put!(response_queue_to_client, instruction)
	=#

	finalize_cluster_instruction = ("finalize_cluster", 0, 0, 
								receiving_response_queue)
	put!(data_directory_queue, finalize_cluster_instruction)
	response = take!(receiving_response_queue)
	@assert response[1] == "finalize_success"
	println("Finalizing data directory completed successfully.")
	
	for hostname = keys(data_request_queues_to_node_memories)
		data_request_queue_to_node_memory = data_request_queues_to_node_memories[hostname]
		finalize_cluster_instruction = ("finalize_cluster", hostname, 0,
									receiving_response_queue)
		put!(data_request_queue_to_node_memory, finalize_cluster_instruction)
		response = take!(receiving_response_queue)
		@assert response[1] == "finalize_success"
		@assert response[2] == hostname
	end
	println("Finalizing all node memories completed successfully.")

	# Finalizing Computation Units
	for computation_unit_id = keys(instruction_queues_to_computation_units)
		instruction_queue_to_computation_unit = instruction_queues_to_computation_units[computation_unit_id]
		finalize_instruction = ("finalize_cluster", computation_unit_id, 
								0, receiving_response_queue)
		put!(instruction_queue_to_computation_unit, finalize_instruction)
		response  = take!(receiving_response_queue) 
		@assert response[1] == "finalize_success"
		@assert response[2] == computation_unit_id
	end
	println("Finalizing all computation units completed successfully.")
	# Finalizing Answer
	finalize_success_response = ("finalize_success", 0, 0, 0)
	put!(response_queue_to_client, finalize_success_response)

end # do_cluster
end # expr_do_cluster
eval(expr_do_cluster)

function cluster_do(cluster::Cluster)

	data_directory = get_data_directory(cluster)	
	data_directory_do(data_directory)

	computation_nodes = get_computation_nodes(cluster)
	for computation_node = computation_nodes
		computation_node_do(computation_node)
	end

	data_request_queues_to_node_memories = get_data_request_queues_to_node_memories(cluster)
	instruction_queues_to_computation_units = get_instruction_queues_to_computation_units(cluster)

	hostname = get_hostname(cluster)
	process_id = get_process_id(cluster)

	instruction_queue_from_client = get_instruction_queue(cluster)
	data_request_queue_to_data_directory = get_data_request_queue_to_data_directory(cluster)
	response_queue_to_client = get_response_queue_to_client(cluster)

	@fetchfrom process_id eval(expr_type_dependency_graph)
	@fetchfrom process_id eval(expr_type_tiled_dependency_graph)
	@fetchfrom process_id eval(expr_function_execute)
	@fetchfrom process_id eval(expr_do_cluster)
	remote_do(do_cluster, process_id, 
			  instruction_queue_from_client,
			  data_request_queue_to_data_directory, 
			  response_queue_to_client,
			  data_request_queues_to_node_memories,
			  instruction_queues_to_computation_units,
			  hostname)


end

end # if !isdefined(:Cluster)
