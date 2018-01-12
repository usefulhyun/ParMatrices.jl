if !isdefined(:expr_type_dependency_graph)

expr_type_dependency_graph = quote

const null_operand = (0, 0, 0, 0)

immutable LazyMatrix
	operator::String
	parmatrix_id::Int
	dimensions::Tuple{Int, Int}
	operands::Tuple{Int, Int, Int, Int}
	LazyMatrix(operator::String, parmatrix_id::Int, dimensions::Tuple{Int, Int},
			   operands::Tuple{Int, Int, Int, Int} = null_operand) = new(operator, parmatrix_id,
																		 dimensions, operands)
end

get_operator(lazymatrix::LazyMatrix) = lazymatrix.operator
get_parmatrix_id(lazymatrix::LazyMatrix) = lazymatrix.parmatrix_id
get_operands(lazymatrix::LazyMatrix) = lazymatrix.operands
get_dimensions(lazymatrix::LazyMatrix) = lazymatrix.dimensions


type DependencyGraph
	lazymatrices::Dict{Int, LazyMatrix}
	DependencyGraph() = new(Dict{Int, LazyMatrix}())
end

get_lazymatrices(dependency_graph::DependencyGraph) = dependency_graph.lazymatrices
get_lazymatrix(dependency_graph::DependencyGraph, parmatrix_id::Int) = dependency_graph.lazymatrices[parmatrix_id]
get_dimensions(dependency_graph::DependencyGraph, parmatrix_id::Int) = get_dimensions(get_lazymatrix(dependency_graph, parmatrix_id))
get_operator(dependency_graph::DependencyGraph, parmatrix_id::Int) = get_operator(get_lazymatrix(dependency_graph, parmatrix_id))
get_operands(dependency_graph::DependencyGraph, parmatrix_id::Int) = get_operands(get_lazymatrix(dependency_graph, parmatrix_id))



function add!(dependency_graph::DependencyGraph, lazymatrix::LazyMatrix)
	lazymatrices = get_lazymatrices(dependency_graph)
	parmatrix_id = get_parmatrix_id(lazymatrix)
	lazymatrices[parmatrix_id] = lazymatrix
	nothing
end

function show_dependency_graph(dependency_graph::DependencyGraph)
	lazymatrices = get_lazymatrices(dependency_graph)

	println("Dependency Graph:")
	for lazymatrix = values(lazymatrices)
		parmatrix_id = get_parmatrix_id(lazymatrix)
		print("ParMatrixID(", parmatrix_id, ") => ")
	
		operator = get_operator(lazymatrix)
		operands = get_operands(lazymatrix)
		if operator == "input"
			println("Input")
		elseif operator == "matrix-matrix addition"
			print("ParMatrixID(", operands[1], "), ")
			println("ParMatrixID(", operands[2], ").")
		elseif operator == "matrix-matrix multiplication"
			print("ParMatrixID(", operands[1], "), ")
			println("ParMatrixID(", operands[2], ").")
		else
			throw("Unknown operator is received.")
		end
	end
end

end # expr_type_dependency_graph
eval(expr_type_dependency_graph)

end # !isdefined(:expr_type_dependency_graph)
