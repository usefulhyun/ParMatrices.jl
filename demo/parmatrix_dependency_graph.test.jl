

include("parmatrix_dependency_graph.jl")

parmatrix_dependency_graph = ParMatrixDependencyGraph()
parmatrix_operation = ParMatrixOperation(Input, 1, (1000,1000), Client) 
add_parmatrix_operation!(parmatrix_dependency_graph, parmatrix_operation)

show_graph(parmatrix_dependency_graph)






