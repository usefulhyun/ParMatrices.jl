include("parmatrices.jl")

init_cluster()

mat = ones(36000, 36000)
pmat1 = ParMatrix(mat)
pmat2 = ParMatrix(mat)
pmat3 = pmat1 * pmat2

#show_dependency_graph_in_cluster()

get_value(pmat3)

finalize_cluster()


#mat = mat + mat
BLAS.set_num_threads(16)
@time mat = mat * mat
println(mat[1,1])
