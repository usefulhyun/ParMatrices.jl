type ClientDataManager
	process_id::Int
	instruction_queue::RemoteChannel
	function ClientDataManager()
		process_id = addprocs(1, restrict=false)[1]
		instruction_queue = RemoteChannel(process_id)
		return new(process_id, instruction_queue) 
	end
end

get_process_id(client_data_manager::ClientDataManager) = client_data_manager.process_id
get_instruction_queue(client_data_manager::ClientDataManager) = client_data_manager.instruction_queue

expr_do_client_data_manager = quote
function do_client_data_manager(instruction_queue::RemoteChannel)
	matrices = Dict{Int, Matrix{Float64}}() 
	while true
		operator, source, destination = take!(instruction_queue)	
		if operator == "input"
			matrix = source
			parmatrix_id = destination 
			println("input ", parmatrix_id)
			matrix = Matrix{Float64}(matrix) 
			matrices[parmatrix_id] = matrix
		elseif operator == "request"
			parmatrix_id, row_begin, row_end, col_begin, col_end = source
			respond_queue, key = destination
			matrix = matrices[parmatrix_id][row_begin:row_end, col_begin:col_end]
			instruction = ("input", matrix, key)
			put!(respond_queue, instruction)
		elseif operator == "terminate"
			break
		end
	end
end
end # expr_do_client_data_manager
eval(expr_do_client_data_manager)

function client_data_manager_do(client_data_manager::ClientDataManager)
	process_id = get_process_id(client_data_manager)
	instruction_queue = get_instruction_queue(client_data_manager)
	@fetchfrom process_id eval(expr_do_client_data_manager)	
	remote_do(do_client_data_manager, process_id, instruction_queue)	
end

