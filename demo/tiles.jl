type TiledMatrix
	tiles::Matrix{SharedMatrix{Float64}}

	function TiledMatrix(matrix::Matrix{Float64}, tile_size::Int)
		dims = size(matrix)
		nrows = Int(ceil(dims[1]/tile_size))
		ncols = Int(ceil(dims[2]/tile_size))

		tiles = Matrix{SharedMatrix{Float64}}(nrows, ncols)
		

		for r=1:nrows
			row_end = r*tile_size
			row_begin = row_end - tile_size + 1
			if row_end > dims[1]
				row_end = dims[1]
			end
			for c=1:ncols
				col_end = c*tile_size
				col_begin = col_end - tile_size + 1
				if col_end > dims[2]
					col_end = dims[2]
				end
				tiles[r,c] = zeros(tile_size, tile_size)

				tiles[r,c][1:row_end-row_begin+1, 1:col_end-col_begin+1] = matrix[row_begin:row_end,col_begin:col_end]
			end
		end
		
		return new(tiles)
	end
end


function gemm(left::TiledMatrix, right::TiledMatrix, result::TiledMatrix)
	m, k = size(left.tiles)
	n = size(right.tiles, 2)
	tile_size = size( left.tiles[1,1] , 1)

	for r = 1:m
		for c = 1:n
			for m = 1:k
				result.tiles[r,c][1:tile_size,1:tile_size] += left.tiles[r,m]*right.tiles[m,c] 
			end
		end
	end
	nothing
end

@everywhere BLAS.set_num_threads(1)

for sz = 500:500:10000
#for tile_sz = 500:500:1000
tile_sz =Int(ceil(sz/3))

m = rand(sz,sz)
z = zeros(sz,sz)
tm = TiledMatrix(m, tile_sz)
res = TiledMatrix(z, tile_sz)

tile_times = Vector{Float64}()
times = Vector{Float64}()
for _=1:20
	gc()
	push!(tile_times, @elapsed gemm(tm, tm, res))
	gc()
	push!(times, @elapsed m*m)
end
G = 10^9
operations = 2*sz*sz*sz/G

@printf("%d\t%d\t%.6f\t%.6f\n", sz, tile_sz, operations/minimum(tile_times), operations/minimum(times) )
end
