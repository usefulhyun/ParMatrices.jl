if !isdefined(:DataDirectory)
	
type DataDirectory
	hostname::String
	process_id::Int
	data_request_queue::RemoteChannel
	
	function DataDirectory(hostname::String)
		process_id = addprocs([hostname])[1]
		data_request_queue = RemoteChannel(process_id)
		println("DataDirectory(", hostname, ") is created.")
		return new(hostname, process_id, data_request_queue)
	end
end

get_hostname(data_directory::DataDirectory) = data_directory.hostname
get_process_id(data_directory::DataDirectory) = data_directory.process_id
get_data_request_queue(data_directory::DataDirectory) = data_directory.data_request_queue

expr_do_data_directory = quote
function do_data_directory(data_request_queue::RemoteChannel, hostname::String)	

	directory = Dict{Int, RemoteChannel}()
	waiting = Dict{Int, Vector{Tuple}}()
		
	println("DataDirectory on (", hostname, ", ", myid(), ") starts running.")
	instruction = take!(data_request_queue)
	operator = instruction[1]
	response_queue_to_cluster_controller = instruction[4]
	@assert operator == "init_cluster"
	response = ("init_success", 0, 0, 0)
	put!(response_queue_to_cluster_controller, response)
	println("Initializing Data Directory on ", hostname, " completed.")
	
	while true
		instruction = take!(data_request_queue)
		operator = instruction[1]
		tile_id = instruction[2]
		#println("Data Directory took ", operator, " TileID(", tile_id, ").")
		
		if operator == "inform"
			data_request_queue_that_has_data = instruction[3]
			whence = instruction[4] 
			directory[tile_id] = data_request_queue_that_has_data
			if haskey(waiting, tile_id)
				for instruction = waiting[tile_id]
					if whence != instruction[4]
						@async put!(data_request_queue_that_has_data, instruction)
					end
				end
				delete!(waiting, tile_id)
			end
		elseif operator == "remote_get"
			if haskey(directory, tile_id)
				@async put!(directory[tile_id], instruction)
			else
				if !haskey(waiting, tile_id)
					waiting[tile_id] = Vector{Tuple}()
				end
				push!(waiting[tile_id], instruction)
			end
		elseif operator == "finalize_cluster"
			response_queue_to_cluster_controller = instruction[4]
			break	
		else
			throw("Undefined operator("*operator*") is received.")
		end
	end
	
	finalize_success_response = ("finalize_success", 0, 0, 0)
	put!(response_queue_to_cluster_controller, finalize_success_response)
	println("Data Directory on ", hostname, " terminates.")	
end

end # expr_do_data_directory
eval(expr_do_data_directory)

function data_directory_do(data_directory::DataDirectory)
	hostname = get_hostname(data_directory)
	process_id = get_process_id(data_directory)
	data_request_queue = get_data_request_queue(data_directory)
	
	@fetchfrom process_id eval(expr_do_data_directory)
	remote_do(do_data_directory, process_id, data_request_queue, hostname) 
end

end # if !isdefined(:DataDirectory)
