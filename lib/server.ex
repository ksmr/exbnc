defmodule BNC.Server do
	use GenServer

	alias BNC.Transport, as: Transport

	defmodule State do
		defstruct port: 6667,
		          client: nil,
							listen_socket: nil,
							ssl?: false
	end

	def init(opts) do
		port = Keyword.get(opts, :port, 6667)
		client = Keyword.get(opts, :client, nil)
		ssl = Keyword.get(opts, :ssl, false)
		if client == nil do
			{:stop, "No client specified, can't work!"}
		else
			state = %State{ssl?: ssl, port: port, client: client}
			case Transport.listen(state, port) do
				{:ok, socket} ->
					{:ok, %State{listen_socket: socket}}
				{:error, reason} ->
					{:stop, "ERROR, couldn't listen on port " <> port <> ": " <> reason}
			end
		end
	end

	def terminate(reason, state) do
		Transport.close(state, listen_socket)
		:ok
	end
		
end
