
include("dependency_graphs.jl")

parmatrix_dependency_graph = ParMatrixDependencyGraph()

parmatrix1 = ParMatrixOperation(Input, 1, (1000, 1000), (0, 0, 0, 0))
parmatrix2 = ParMatrixOperation(Input, 2, (1000, 1000), (0, 0, 0, 0))
parmatrix3 = ParMatrixOperation(Gemm, 3, (1000, 1000), (1, 2, 0, 0))


add_parmatrix_operation!( parmatrix_dependency_graph, parmatrix1)
add_parmatrix_operation!( parmatrix_dependency_graph, parmatrix2)
add_parmatrix_operation!( parmatrix_dependency_graph, parmatrix3)

show_graph(parmatrix_dependency_graph)

tiled_dependency_graph = TiledDependencyGraph(500)
add_tiles!(tiled_dependency_graph, parmatrix_dependency_graph, 3)

show_graph(tiled_dependency_graph)





