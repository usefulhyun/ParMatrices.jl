
if !isdefined(:Instruction)

isdefined(:ID) || const ID = Int
isdefined(:Operands) || const Operands = NTuple{4, Int}
immutable Instruction
	operator::Operator
	id::ID
	operands::Operands
end






end # !isdefined(:Instruction)
