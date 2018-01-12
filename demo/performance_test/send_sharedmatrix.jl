elc3_pid = addprocs(3, restrict=false)[1]
elc4_pids = addprocs([("elc4.cs.yonsei.ac.kr",3)])
elc4_1_pid = elc4_pids[1]
elc4_2_pid = elc4_pids[2]
elc4_3_pid = elc4_pids[3]

client_to_elc3 = RemoteChannel(elc3_pid)
elc3_to_elc4_1 = RemoteChannel(elc4_1_pid) 
elc4_1_to_elc4_2 = RemoteChannel(elc4_2_pid) 
elc4_2_to_elc4_3 = RemoteChannel(elc4_3_pid)
elc4_3_to_client = RemoteChannel(2)

@everywhere function do_work(recv::RemoteChannel, send::RemoteChannel)
	while true
		data = take!(recv)
		if !(myid() in procs(data))
			data = sdata(data)
			data = SharedMatrix{Float64}(data)
		end
		#println(typeof(data))
		println(procs(data))
		t = @elapsed put!(send, data)
		println(t, "\t", myid())
	end
end


remote_do(do_work, elc3_pid, client_to_elc3, elc3_to_elc4_1)
remote_do(do_work, elc4_1_pid, elc3_to_elc4_1, elc4_1_to_elc4_2)
remote_do(do_work, elc4_2_pid, elc4_1_to_elc4_2, elc4_2_to_elc4_3)
remote_do(do_work, elc4_3_pid, elc4_2_to_elc4_3, elc4_3_to_client)

sa = SharedMatrix{Float64}( rand(2000, 2000) )
put!(client_to_elc3, sa)
#put!(client_to_elc3, sa)
#put!(client_to_elc3, sa)
#put!(client_to_elc3, sa)
#data = take!(elc4_2_to_client)
#data = take!(elc4_2_to_client)
#data = take!(elc4_2_to_client)
data = take!(elc4_3_to_client)

println("Two")
sleep(10)
put!(client_to_elc3, sa)
data = take!(elc4_3_to_client)


sleep(10)
println("Three")
put!(client_to_elc3, sa)
data = take!(elc4_3_to_client)
