function matmul(left::SharedMatrix{Float64}, right::SharedMatrix{Float64}, 
				process_ids::Vector{Int}, tile_size::Int, num_threads::Int = 1)
	
	left_dims = size(left)
	right_dims = size(right)
	
	left_dims[2] == right_dims[1] || throw("Dimensions mismatch")

	result = SharedMatrix{Float64}(left_dims[1], right_dims[2])	

	tile_dims = (Int(ceil(left_dims[1]/tile_size)), Int(ceil(right_dims[2]/tile_size)))
	
	mid = left_dims[2]/tile_size

	@sync for row=1:tile_dims[1]
		row_end = row*tile_size 
		row_begin = row_end - tile_size + 1
		if row_end > left_dims[1]
			row_end = left_dims[1]
		end
		for col=1:tile_dims[2]
			col_end = col*tile_size
			col_begin = col_end - tile_size + 1
			if col_end > right_dims[2]
				col_end = right_dims[2]
			end
			@async begin
			@fetch matmul(left, right, result,
				   row_begin:row_end, 1:left_dims[2],
				   1:right_dims[1], col_begin:col_end,
				   row_begin:row_end, col_begin:col_end,
				   num_threads)
			end
		end
	end
	
	
	return result
end

expr_matmul = quote

function matmul(left::SharedMatrix{Float64}, right::SharedMatrix{Float64},
				result::SharedMatrix{Float64},
				left_row_range::UnitRange{Int64}, left_col_range::UnitRange{Int64},
				right_row_range::UnitRange{Int64}, right_col_range::UnitRange{Int64},
				res_row_range::UnitRange{Int64}, res_col_range::UnitRange{Int64},
				num_threads::Int = 1)
	BLAS.set_num_threads(num_threads)
	result[res_row_range, res_col_range] = left[left_row_range, left_col_range] * right[right_row_range, right_col_range]
	return nothing
end

end # expr_matmul 
eval(expr_matmul)

pids = Vector{Int}()

addprocs(4)
#=
push!(pids, addprocs(["elc3.cs.yonsei.ac.kr"])[1])
push!(pids, addprocs(["elc3.cs.yonsei.ac.kr"])[1])
push!(pids, addprocs(["elc3.cs.yonsei.ac.kr"])[1])
push!(pids, addprocs(["elc3.cs.yonsei.ac.kr"])[1])
=#

@fetchfrom 2 eval(expr_matmul)
@fetchfrom 3 eval(expr_matmul)
@fetchfrom 4 eval(expr_matmul)
@fetchfrom 5 eval(expr_matmul)



#=
mat = SharedMatrix{Float64}(rand(5,5))
println( mat * mat )
println( matmul(mat, mat, pids, 2, 16) )
=#





for sz=10000:5000:25000

	times = Vector{Float64}()
	BLAS.set_num_threads(16)
	for _=1:10
		mat = rand(sz,sz)
		push!(times, @elapsed mat*mat)
	end
	@printf("%d\t%.6f\n", sz, minimum(times))
	
	i = 1
	tile_sz = Int(ceil(sz/i))
	
	while i <= 8 && tile_sz >= 500

		times = Vector{Float64}()
		for _=1:10
			gc()
			mat = SharedMatrix{Float64}(zeros(sz, sz))
			push!(times, @elapsed matmul(mat, mat, pids, tile_sz, 7))
		end
		@printf("%d\t%d\t%.6f\n", sz, tile_sz, minimum(times))
		
		i += 1
		tile_sz = Int(ceil(sz/i))
	end
end

