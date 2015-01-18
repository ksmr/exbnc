defmodule Transport do
	def connect(%{ssl?: ssl?}, host, port, opts \\ []) do
		defopts = [:binary,
							 {:packet, :line},
							 {:keepalive, true}]
		if ssl? do
			:ssl.connect(host, port, defopts ++ opts)
		else
			:gen_tcp.connect(host, port, defopts ++ opts)
		end
	end

	def listen(%{ssl?: ssl?}, port, opts \\ []) do
		defopts = [:binary,
							 {:packet, :line},
							 {:keepalive, true}]

		if ssl? do
			:ssl.listen(port, defopts ++ opts)
		else
			:gen_tcp.listen(port, defopts ++ opts)
		end
	end

	def accept(%{ssl?: ssl?}, socket) do
		if ssl? do
			:ssl.ssl_accept(socket)
		else
			:gen_tcp.accept(socket)
		end
	end
	
	def send(state, data) do
		if state.ssl? do
			:ssl.send(state.socket, data)
		else
			:gen_tcp.send(state.socket, data)
			end
	end
	
	def close(state) do
		if state.ssl? do
			:ssl.close(state.socket)
		else
			:gen_tcp.close(state.socket)
		end
	end
end
