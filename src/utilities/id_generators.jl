""" 
	This module provides a type and function that is used
	to generate unique integer id in increasing order from 1. 
"""
module IDGenerators

type IDGenerator
	last_id::Int
	IdGenerator() = new(0)
end


function generate_unique_id(id_generator::IDGenerator)
	id_generator.last_id += 1
	new_id::Int = id_generator.last_id
	return new_id
end
		
export IDGenertor
export generate_unique_id

end # module IDGenerators
