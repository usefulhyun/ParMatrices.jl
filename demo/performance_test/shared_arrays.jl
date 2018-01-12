



send_pid = addprocs(["elc4.cs.yonsei.ac.kr"])[1]
recv_pid = addprocs(["elc4.cs.yonsei.ac.kr"])[1]


@everywhere function do_send(send::RemoteChannel, recv::RemoteChannel, terminal::RemoteChannel)

	for sz=[500,1000,1500,2000,4000,6000,8000]
		times_sharedmatrix = Vector{Float64}()
		times_matrix = Vector{Float64}()

		for _=1:20
			sa = SharedMatrix{Float64}( rand(sz,sz) ) 
			t = @elapsed begin
				put!(send, sa) 
				take!(recv)
			end
			push!(times_sharedmatrix, t)
		end
		
		for _=1:20
			sa = rand(sz,sz)
			t = @elapsed begin
				put!(send, sa) 
				take!(recv)
			end
			push!(times_matrix, t)
		end

		@printf("%d\t%.6f\t%.6f\n", sz, minimum(times_matrix), minimum(times_sharedmatrix))
	end 

	put!(send, 0)
	put!(terminal, 0)
end

@everywhere function do_echo(recv::RemoteChannel, send::RemoteChannel)

	while true
		data = take!(recv)
		if data == 0
			break
		end
		put!(send, data)
	end
end

send_channel = RemoteChannel(send_pid)
recv_channel = RemoteChannel(recv_pid)
terminal_channel = RemoteChannel(myid())
remote_do( do_send, send_pid, send_channel, recv_channel, terminal_channel)
remote_do( do_echo, send_pid, send_channel, recv_channel)
take!(terminal_channel)
