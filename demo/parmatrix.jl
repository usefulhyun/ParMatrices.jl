#=
	new_parmatrix_id()
	send_instruction_to_cluster(instruction::Tuple)
	receiving_response_from_cluster()
=#
if !isdefined(:ParMatrix)

const null_operand = (0, 0, 0, 0)


type ParMatrix
	parmatrix_id::Int
	operator::String
	dimensions::Tuple{Int, Int}
	operands::Tuple{Int, Int, Int, Int}

	ParMatrix(operator::String, dimensions::Tuple{Int, Int}, 
			  operands::Tuple{Int, Int, Int, Int}) = new(new_parmatrix_id(), operator,
														 dimensions, operands)
end

get_parmatrix_id(parmatrix::ParMatrix) = parmatrix.parmatrix_id
get_operator(parmatrix::ParMatrix) = parmatrix.operator
get_dimensions(parmatrix::ParMatrix) = parmatrix.dimensions

import Base.size
size(parmatrix::ParMatrix) = get_dimensions(parmatrix)

# Constructor of ParMatrix from Input matrix
function ParMatrix(matrix::Matrix{Float64})
	
	operator = "input"
	dimensions = size(matrix)

	parmatrix = ParMatrix(operator, dimensions, null_operand)
	parmatrix_id = get_parmatrix_id(parmatrix)
	
	instruction = (operator, parmatrix_id, dimensions, null_operand)
	send_instruction_to_cluster(instruction)
	send_instruction_to_cluster(matrix)
	return parmatrix
end


import Base.+
function +(left::ParMatrix, right::ParMatrix)
	operator = "matrix-matrix addition"

	left_dimensions = get_dimensions(left)
	right_dimensions = get_dimensions(right)	
	left_dimensions == right_dimensions || throw("Dimension does not match.")
	
	dimensions = left_dimensions # dimensions

	left_parmatrix_id = get_parmatrix_id(left) 
	right_parmatrix_id = get_parmatrix_id(right)

	parmatrix_ids_of_operands = (left_parmatrix_id, right_parmatrix_id, 0, 0) # operands

	parmatrix = ParMatrix(operator, dimensions, parmatrix_ids_of_operands) 
	parmatrix_id = get_parmatrix_id(parmatrix)
	
	instruction = (operator, parmatrix_id, dimensions, parmatrix_ids_of_operands)
	send_instruction_to_cluster(instruction)

	return parmatrix
end


import Base.*
function *(left::ParMatrix, right::ParMatrix)
	operator = "matrix-matrix multiplication"
	left_dimensions = size(left)
	right_dimensions = size(right)
	left_dimensions[2] == right_dimensions[1] || throw("Dimension does not match.")
	
	dimensions = (left_dimensions[1], right_dimensions[2]) # dimensions

	parmatrix_id_of_left = get_parmatrix_id(left)
	parmatrix_id_of_right = get_parmatrix_id(right)
	parmatrix_ids_of_operands = (parmatrix_id_of_left, parmatrix_id_of_right, 0, 0) # operands
	parmatrix = ParMatrix(operator, dimensions, parmatrix_ids_of_operands)
	parmatrix_id = get_parmatrix_id(parmatrix)

	instruction = (operator, parmatrix_id, dimensions, parmatrix_ids_of_operands)
	send_instruction_to_cluster(instruction)

	return parmatrix
end


function get_value(parmatrix::ParMatrix)
	
	operator = "getvalue"
	parmatrix_id = get_parmatrix_id(parmatrix)
	instruction = (operator, parmatrix_id, 0, 0)
	send_instruction_to_cluster(instruction)

	response = receiving_response_from_cluster()
	@assert response[1] == "done"
	println(response[4][1, 1])
	nothing
end


function show_dependency_graph_in_cluster()
	instruction = ("show_dependency_graph", 0, 0, )
	send_instruction_to_cluster(instruction)
	response = receiving_response_from_cluster()
	@assert response[1] == "done"
	nothing
end


end # if !isdefined(:ParMatrix)
