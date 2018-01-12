include("dependency_graph.jl")

if !isdefined(:expr_type_tiled_dependency_graph)
expr_type_tiled_dependency_graph = quote

let 
	last_tile_id::Int= 0 
	global get_new_tile_id() = (last_tile_id += 1)
end

immutable TiledLazyMatrix
	tile_id::Int
	operator::String
	operands::Tuple{Int, Int, Int, Int}
	TiledLazyMatrix(operator::String, 
					operands::Tuple{Int, Int, Int, Int}) = new(get_new_tile_id(),
															   operator, operands)
end 

get_operator(tiled_lazymatrix::TiledLazyMatrix) = tiled_lazymatrix.operator
get_tile_id(tiled_lazymatrix::TiledLazyMatrix) = tiled_lazymatrix.tile_id
get_operands(tiled_lazymatrix::TiledLazyMatrix) = tiled_lazymatrix.operands

type TiledDependencyGraph
	tiled_lazymatrices::Dict{Int, TiledLazyMatrix}
	tile_ids::Dict{Int, Matrix{Int}} 
	tile_size::Int

	TiledDependencyGraph(tile_size::Int) = new(Dict{Int, TiledLazyMatrix}(), 
											   Dict{Int, Matrix{Int}}(), tile_size)
end

get_operator(tiled_dependency_graph::TiledDependencyGraph, tile_id) = get_operator(get_tiled_lazymatrix(tiled_dependency_graph, tile_id))

get_tile_size(tiled_dependency_graph::TiledDependencyGraph) = tiled_dependency_graph.tile_size
get_tiled_lazymatrices(tiled_dependency_graph::TiledDependencyGraph) = tiled_dependency_graph.tiled_lazymatrices
get_tiled_lazymatrix(tiled_dependency_graph::TiledDependencyGraph, tile_id::Int) = tiled_dependency_graph.tiled_lazymatrices[tile_id]
get_tile_ids(tiled_dependency_graph::TiledDependencyGraph, parmatrix_id::Int) = tiled_dependency_graph.tile_ids[parmatrix_id]
get_tile_id(tiled_dependency_graph::TiledDependencyGraph, parmatrix_id::Int, row::Int, col::Int) = tiled_dependency_graph.tile_ids[parmatrix_id][row, col]

has_tiles(tiled_dependency_graph::TiledDependencyGraph, parmatrix_id::Int) = haskey(tiled_dependency_graph.tile_ids, parmatrix_id)
get_operands(tiled_dependency_graph::TiledDependencyGraph, tile_id::Int) = get_operands(get_tiled_lazymatrix(tiled_dependency_graph, tile_id))


function show_matches(tiled_dependency_graph::TiledDependencyGraph)
	tile_ids = tiled_dependency_graph.tile_ids
	println("ParMatrixID to TiledID")
	for parmatrix_id = keys(tile_ids)
		println("ParMatrixID(", parmatrix_id, ")")
		dims = size(tile_ids[parmatrix_id])
		for row=1:dims[1]
			for col=1:dims[2]
				print("TileID(", tile_ids[parmatrix_id][row, col], ") ")
			end
			println()
		end
	end
end


function show_dependency_graph(tiled_dependency_graph::TiledDependencyGraph)
	tiled_lazymatrices = get_tiled_lazymatrices(tiled_dependency_graph)
	println("Tiled Dependency Graph:")
	for tiled_lazymatrix = values(tiled_lazymatrices)
		tile_id = get_tile_id(tiled_lazymatrix)
		print("TileID(", tile_id, ") => ")

		operator = get_operator(tiled_lazymatrix)
		operands = get_operands(tiled_lazymatrix)

		if operator == "input"
			println("ParMatrixID(", operands[1], ")[",
					operands[2], ", ", operands[3], "].")

		elseif operator == "matrix-matrix addition"
			print("TileID(", operands[1], ") + ")
			println("TileID(", operands[2], ").")
		elseif operator == "matrix-matrix multiplication"	
			print("TileID(", operands[1], ") * ")
			println("TileID(", operands[2], ").")
		else
			throw("Unknown operator is received.")
		end
	end
end


function add_tiles!(tiled_dependency_graph::TiledDependencyGraph, 
					dependency_graph::DependencyGraph,
					parmatrix_id::Int)

	if !has_tiles(tiled_dependency_graph, parmatrix_id)
		tile_size = get_tile_size(tiled_dependency_graph)
		dimensions = get_dimensions(dependency_graph, parmatrix_id)
		num_of_tile_rows = Int(ceil(dimensions[1]/tile_size))
		num_of_tile_cols = Int(ceil(dimensions[2]/tile_size))

		operator = get_operator(dependency_graph, parmatrix_id)
		tile_ids = Matrix{Int}(num_of_tile_rows, num_of_tile_cols)
		
		if operator == "input"
			for row=1:num_of_tile_rows
				for col=1:num_of_tile_cols
					operands = (parmatrix_id, row, col, tile_size)

					tiled_lazymatrix = TiledLazyMatrix(operator, operands)
					tile_id = get_tile_id(tiled_lazymatrix)
					tiled_dependency_graph.tiled_lazymatrices[tile_id] = tiled_lazymatrix
					tile_ids[row, col] = tile_id
				end
			end
		elseif operator == "matrix-matrix addition"
			parmatrix_id_of_left_operand = get_operands(dependency_graph, parmatrix_id)[1]
			parmatrix_id_of_right_operand = get_operands(dependency_graph, parmatrix_id)[2]
			add_tiles!(tiled_dependency_graph, dependency_graph, parmatrix_id_of_left_operand)
			add_tiles!(tiled_dependency_graph, dependency_graph, parmatrix_id_of_right_operand)
					
			for row=1:num_of_tile_rows
				for col=1:num_of_tile_cols
					tile_id_of_left_operand = get_tile_id(tiled_dependency_graph, 
														  parmatrix_id_of_left_operand, 
														  row, col)
					tile_id_of_right_operand = get_tile_id(tiled_dependency_graph,
														   parmatrix_id_of_right_operand,
														   row, col)
					operands = (tile_id_of_left_operand, tile_id_of_right_operand, 0, 0)
					
					tiled_lazymatrix = TiledLazyMatrix(operator, operands)
					tile_id = get_tile_id(tiled_lazymatrix)
					tiled_dependency_graph.tiled_lazymatrices[tile_id] = tiled_lazymatrix
					tile_ids[row, col] = tile_id
				end
			end
		elseif operator == "matrix-matrix multiplication"
			parmatrix_id_of_left_operand = get_operands(dependency_graph, parmatrix_id)[1]
			parmatrix_id_of_right_operand = get_operands(dependency_graph, parmatrix_id)[2]

			num_of_mid = Int(ceil(get_dimensions(dependency_graph, parmatrix_id_of_left_operand)[2]/tile_size))
			
			add_tiles!(tiled_dependency_graph, dependency_graph, parmatrix_id_of_left_operand)
			add_tiles!(tiled_dependency_graph, dependency_graph, parmatrix_id_of_right_operand)
				

			for row=1:num_of_tile_rows
				for col=1:num_of_tile_cols
					tile_id_of_left_operand = get_tile_id(tiled_dependency_graph, 
														  parmatrix_id_of_left_operand, 
														  row, 1)
					tile_id_of_right_operand = get_tile_id(tiled_dependency_graph,
														   parmatrix_id_of_right_operand,
														   1, col)
					operands = (tile_id_of_left_operand, tile_id_of_right_operand, 0, 0)
					tiled_lazymatrix = TiledLazyMatrix(operator, operands)
					tile_id = get_tile_id(tiled_lazymatrix)
					tiled_dependency_graph.tiled_lazymatrices[tile_id] = tiled_lazymatrix

					for k=2:num_of_mid	
						tile_id_of_left_operand = get_tile_id(tiled_dependency_graph, 
															  parmatrix_id_of_left_operand, 
															  row, k)
						tile_id_of_right_operand = get_tile_id(tiled_dependency_graph,
															   parmatrix_id_of_right_operand,
															   k, col)
						operands = (tile_id_of_left_operand, tile_id_of_right_operand, 0, 0)
						multiplied_tiled_lazymatrix = TiledLazyMatrix(operator, operands)
						multiplied_tile_id = get_tile_id(multiplied_tiled_lazymatrix)
						tiled_dependency_graph.tiled_lazymatrices[multiplied_tile_id] = multiplied_tiled_lazymatrix 
						operands = (tile_id, multiplied_tile_id, 0, 0)
						tiled_lazymatrix = TiledLazyMatrix("matrix-matrix addition", operands)
						tile_id = get_tile_id(tiled_lazymatrix)
						tiled_dependency_graph.tiled_lazymatrices[tile_id] = tiled_lazymatrix	
					end
					tile_ids[row, col] = tile_id
				end
			end
		else
			throw("Unknown operator is received.")
		end
		tiled_dependency_graph.tile_ids[parmatrix_id] = tile_ids
		
	end
	nothing 
end

end # expr_type_tiled_dependency_graph 
eval(expr_type_tiled_dependency_graph)

end # if !isdefined(:expr_tile_dependency_graph)





