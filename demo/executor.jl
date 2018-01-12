include("tiled_dependency_graph.jl")

if !isdefined(:expr_function_execute)

expr_function_execute = quote

function dfs(tile_id::Int, tiled_dependency_graph::TiledDependencyGraph,
			 visited::Dict{Int, Bool}, sequence::Vector{Int})
	if get_operator(tiled_dependency_graph, tile_id) == "input"
		return nothing
	end
	
	operands = get_operands(tiled_dependency_graph, tile_id)	
	for next_tile_id = operands
		if next_tile_id != 0 && !haskey(visited, next_tile_id) 
			visited[next_tile_id] = true
			dfs(next_tile_id, tiled_dependency_graph, visited, sequence) 
			push!(sequence, next_tile_id)
		end
	end
	return nothing
end

function execute(tiled_dependency_graph::TiledDependencyGraph,
				 parmatrix_id::Int, input_matrices::Dict{Int, Matrix{Float64}},
				 instruction_queues_to_computation_units::Dict{Int, RemoteChannel},
				 data_directory_queue::RemoteChannel,
				 response_queue_to_client::RemoteChannel)

	tile_ids = get_tile_ids(tiled_dependency_graph, parmatrix_id)	
	tile_ids_of_result = Vector{Int}()
	sequence = Vector{Int}()
	visited = Dict{Int, Bool}()
	for next_tile_id = tile_ids
		visited[next_tile_id] = true
		dfs(next_tile_id, tiled_dependency_graph, visited, sequence) 
		push!(sequence, next_tile_id)
	end
	#=
	println("Execution sequence: ")
	for tile_id = sequence
		print("TileID(", tile_id, ") ")
	end 
	=#
	instruction_queues = Vector{RemoteChannel}()
	for instruction_queue = values(instruction_queues_to_computation_units)
		push!(instruction_queues, instruction_queue)
	end
	num_of_instruction_queues = length(instruction_queues)

	queue_id = 1
		
	count = 1
	for tile_id = sequence 
		tiled_lazymatrix = get_tiled_lazymatrix(tiled_dependency_graph, tile_id)
		operator = get_operator(tiled_lazymatrix)
		operands = get_operands(tiled_lazymatrix)
		input_matrix = 0
		
		if operator == "input"
			parmatrix_id = operands[1]
			row = operands[2]
			col = operands[3]
			tile_size = operands[4]
			row_end = tile_size*row
			row_begin = row_end - tile_size + 1
			col_end = tile_size*col
			col_begin = col_end - tile_size + 1

			input_matrix = input_matrices[parmatrix_id][row_begin:row_end, col_begin:col_end]
			input_matrix = Matrix{Float64}(input_matrix)
		end
		instruction = (operator, tile_id, operands, input_matrix)
	
		@async put!(instruction_queues[queue_id], instruction)
		queue_id += 1
		if queue_id > num_of_instruction_queues
			queue_id = 1
		end
		println(count, queue_id)
		count += 1
	end

	receiving_queue = RemoteChannel(myid())
	ans = 0
	for tile_id = tile_ids
		remote_get_instruction = ("remote_get", tile_id, receiving_queue, myid())
		put!(data_directory_queue, remote_get_instruction)
		response = take!(receiving_queue)
		@assert response[2] == tile_id
		ans = response[3]
	end
	
	ans	
end # function execute

end # expr_function_execute
eval(expr_function_execute)

end # if !isdefined(:expr_function_execute)


