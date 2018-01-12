if !isdefined(:Constants) 

isdefined(:Null) || const Null::Int = 0


isdefined(:Hostname) || const Hostname = String

isdefined(:ParMatrixID) || const ParMatrixID = Int
isdefined(:TileID) || const TileID = Int 
isdefined(:Operator) || const Operator = Int
isdefined(:Dimensions) || const Dimensions = Tuple{Int, Int}



isdefined(:Teminate) || const Terminate 10000
isdefined(:Input) || const Input = 10001
isdefined(:MatrixMatrixAddition) = const MatrixMatrixAddition = 10002
isdefined(:MatrixMatrixMultiplication) || const MatrixMatrixMultiplication = 10002

isdefined(:Client) || const Client = (0, 0, 0, 0)


include("operands.jl")

end
