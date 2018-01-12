#expr_computation_ode = quote

include("node_memory.jl")
include("computation_unit.jl")

type ComputationNode
	hostname::String
	node_memory::NodeMemory
	computation_units::Vector{ComputationUnit}

	function ComputationNode(hostname::String, configuration::Vector{Int}, 
							 data_request_queue_to_data_directory::RemoteChannel)
		
		node_memory = NodeMemory(hostname, data_request_queue_to_data_directory)
		data_request_queue_to_node_memory = get_data_request_queue(node_memory) 
		computation_units = Vector{ComputationUnit}()
		for num_of_threads = configuration
			computation_unit = ComputationUnit(hostname, num_of_threads, 
											   data_request_queue_to_node_memory)
			push!(computation_units, computation_unit)
		end
		println("ComputationNode(", hostname, ") is created.")

		return new(hostname, node_memory, computation_units)
	end
end

get_node_memory(computation_node::ComputationNode) = computation_node.node_memory
get_computation_units(computation_node::ComputationNode) = computation_node.computation_units
get_data_request_queue(computation_node::ComputationNode) = get_data_request_queue(get_node_memory(computation_node))

function computation_node_do(computation_node::ComputationNode)
	node_memory = get_node_memory(computation_node)
	node_memory_do(node_memory) 
	
	computation_units = get_computation_units(computation_node)
	for computation_unit = computation_units
		computation_unit_do(computation_unit)
	end
end


