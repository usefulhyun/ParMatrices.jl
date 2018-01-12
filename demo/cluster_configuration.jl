
include("cluster.jl")

let 
	last_parmatrix_id = 0
	global new_parmatrix_id() = (last_parmatrix_id += 1)

	host_manager = HostManager("elc3.cs.yonsei.ac.kr")
	
	#elc3 = Host("elc3.cs.yonsei.ac.kr", [14, 14])
	elc4 = Host("elc3.cs.yonsei.ac.kr", [7, 7, 7, 7])

	#add_host!(host_manager, elc3)
	add_host!(host_manager, elc4)

	cluster = Cluster(host_manager)
		
	instruction_queue_to_cluster = get_instruction_queue(cluster)
	global send_instruction_to_cluster(instruction) =  put!(instruction_queue_to_cluster, instruction)
	
	response_queue_from_cluster = get_response_queue_to_client(cluster)
	global receiving_response_from_cluster() = take!(response_queue_from_cluster)

	global init_cluster
	function init_cluster() 
		cluster_do(cluster)
		response = receiving_response_from_cluster()
		@assert response[1] == "init_success"
		println("Initializing Cluster completed successfully.")
	end 

	global finalize_cluster
	function finalize_cluster()
		finalizing_instruction = ("finalize_cluster", 0, 0, 0)
		send_instruction_to_cluster(finalizing_instruction)
		response = receiving_response_from_cluster()
		@assert response[1] == "finalize_success"
		println("Finalizing Cluster completed.")
	end	
end




