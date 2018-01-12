
#expr_node_memory = quote 
#include("data_directory.jl")

type NodeMemory
	hostname::String
	process_id::Int
	data_request_queue::RemoteChannel
	data_request_queue_to_data_directory::RemoteChannel

	function NodeMemory(hostname::String, data_request_queue_to_data_directory::RemoteChannel)
		process_id = addprocs([hostname])[1]
		data_request_queue = RemoteChannel(addprocs([hostname])[1])	
		println("NodeMemory(", hostname, ") is created.")
		return new(hostname, process_id, data_request_queue, data_request_queue_to_data_directory)		
	end
end

get_hostname(node_memory::NodeMemory) = node_memory.hostname
get_process_id(node_memory::NodeMemory) = node_memory.process_id
get_data_request_queue_to_data_directory(node_memory::NodeMemory) = node_memory.data_request_queue_to_data_directory
get_data_request_queue(node_memory::NodeMemory) = node_memory.data_request_queue

expr_do_node_memory = quote

function do_node_memory(data_request_queue_to_data_directory::RemoteChannel,
					   data_request_instruction_queue::RemoteChannel)

	println("NodeMemory on ", myid(), " starts running.")
	
	instruction = take!(data_request_instruction_queue)
	operator = instruction[1]
	hostname = instruction[2]
	response_queue_to_cluster_controller = instruction[4]
	@assert operator == "init_cluster"
	
	response = ("init_success", hostname, 0, 0)
	put!(response_queue_to_cluster_controller, response)
	println("Initializing NodeMemory(", hostname, ") completed.")

	database = Dict{Int, SharedMatrix}()
	waiting = Dict{Int, Vector{RemoteChannel}}()

	while true
		instruction = take!(data_request_instruction_queue)
		operator = instruction[1]
		tile_id = instruction[2]
		println("NodeMemory(", myid(), ") took ", operator, " TileID(", tile_id, ").")
			
		if operator == "get"
			data_receiving_queue = instruction[4]
			if haskey(database, tile_id)
				put!(data_receiving_queue, database[tile_id])
			else
				if !haskey(waiting, tile_id)
					waiting[tile_id] = Vector{RemoteChannel}()
					remote_get_instruction = ("remote_get", tile_id, data_request_instruction_queue, myid())
			#		println(remote_get_instruction)
					put!(data_request_queue_to_data_directory, remote_get_instruction)
				end
				push!(waiting[tile_id], data_receiving_queue)
			end
		elseif operator == "store"
			sharedmatrix = instruction[3]
			whence = instruction[4]
			database[tile_id] = sharedmatrix
			
			if haskey(waiting, tile_id)
				for data_receiving_queue = waiting[tile_id]
					@async put!(data_receiving_queue, sharedmatrix)
				end
				delete!(waiting, tile_id)
			end
			
			if whence == 0
				inform_instruction = ("inform", tile_id, data_request_instruction_queue, myid())
				put!(data_request_queue_to_data_directory, inform_instruction)
			end
		elseif operator == "remote_get"
			data_request_instruction = ("store", tile_id, database[tile_id], 1)
			@async put!(instruction[3], data_request_instruction)
		elseif operator == "finalize_cluster"
			response_queue_to_cluster_controller = instruction[4]
			break
		else
			throw("Unknown operator is received.")
		end
	end

	#=
	while true
		operator, id, source = take!(data_request_queue)
		
		if operator == "remote_request"
			instruction = "store", id, sharedmatrices[id]
			put!(source, instruction)
		
		elseif operator == "local_request"
			data_receiving_queue = source
			if haskey(sharedmatrices, id)
				put!(data_receiving_queue, sharedmatrices[id]) 
			else
				if !haskey(pending_request, id)
					pending_request[id] = Vector{RemoteChannel}()
					instruction = "remote_request", id, data_request_queue
					put!(data_directory_queue, instruction)
				end
				push!(pending_request[id], data_receiving_queue)
			end

		
		elseif operator == "store"
			sharedmatrix = source
			sharedmatrices[id] = sharedmatrix
			if haskey(pending_request, id)
				for data_receiving_queue = pending_request[id]
					put!(data_receiving_queue, sharedmatrix)
				end
				delete!(pending_request, id)
			end
			data_request_instruction = "store", id, data_request_queue
			put!(data_directory_queue, data_request_instruction)
		elseif operator == "exit"
			break
		else
			throw("Undefined operator is given to node memory.")
		end
	end
	=#

	finalize_success_response = ("finalize_success", hostname, 0, 0)
	put!(response_queue_to_cluster_controller, finalize_success_response)
	println("NodeMemory(", hostname, ") terminates.")
end
end # expr_do_node_memory
eval(expr_do_node_memory)

function node_memory_do(node_memory::NodeMemory)
	process_id = get_process_id(node_memory)
	data_request_queue_to_data_directory = get_data_request_queue_to_data_directory(node_memory)
	data_request_queue = get_data_request_queue(node_memory)
	@fetchfrom process_id eval(expr_do_node_memory)
	remote_do(do_node_memory, process_id, 
			  data_request_queue_to_data_directory,
			  data_request_queue)
end


