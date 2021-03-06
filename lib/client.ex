defmodule BNC.Client do
	use GenServer

	alias BNC.Message, as: Message
	alias BNC.Parser, as: Parser
	alias BNC.Transport, as: Transport

	defmodule State do
		defstruct host: "localhost",
		          port: 6667,
							ssl?: false,
							nick: "",
							pass: "",
							user: "",
							name: "",
							channels: [],
							connected?: false,
							socket: nil,
							logged_on?: false,
							event_handlers: []
	end


	## Client API

	def start(opts \\ []) do
		GenServer.start_link(__MODULE__, opts)
	end

	def connect(state, host, port) do
		GenServer.call(state, {:connect, host, port, false})
	end
	
	def connect_ssl(state, host, port) do
		GenServer.call(state, {:connect, host, port, true})
	end

	def logon(state, nick, pass, user, name) do
		GenServer.call(state, {:logon, nick, pass, user, name})
	end
	
	def raw(state, %Message{raw: msg}) do
		GenServer.call(state, {:raw, msg})
	end

	def join(state, channel, passwd \\ "") do
		GenServer.call(state, {:join, channel, passwd})
	end

	def quit(state, msg \\ "") do
		GenServer.call(state, {:quit, msg})
	end

	## GenServer callbacks

	def init(_opts \\ []) do
		{:ok, %State{}}
	end

	def terminate(_reason, state) do
		if state.connected? do
			quit(state)
			Transport.close(state)
		end
		:ok
	end

	def handle_call({:connect, host, port, ssl?}, _from, state) do
		if state.connected? do
			Transport.close(state)
		end
		state = %{state | ssl?: ssl?}
		case Transport.connect(state, host, port, []) do
			{:ok, socket} ->
				state = %{state | socket: socket, host: host, port: port, connected?: true}
				{:reply, :ok, state}
			error ->
				{:reply, error, state}
		end
	end
	
	def handle_call(:is_connected?, _from, state) do
		{:reply, state.connected?, state}
	end

	def handle_call(_msg, _from, %State{connected?: false} = state) do
		{:reply, {:error, :not_connected}, state}
	end

	def handle_call({:logon, nick, pass, user, name}, _from, %State{logged_on?: false} = state) do
		unless pass == ""  do
			Transport.send(state, "PASS " <> pass <> "\r\n")
		end
		Transport.send(state, "NICK " <> nick <> "\r\n")
		Transport.send(state, "USER " <> user <> " 0 * :" <> name <> "\r\n")
		{:reply, :ok, %{state | nick: nick, pass: pass, user: user, name: name, logged_on?: true}}
	end

	def handle_call(:logged_on?, _from, state) do
		{:reply, state.logged_on?, state}
	end

	def handle_call(_msg, _from, %State{logged_on?: false} = state) do
		{:reply, {:error, :not_logged_on}, state}
	end

	# To pass a message forward
	def handle_call({:raw, data}, _from, state) do
		Transport.send(state, data)
		{:reply, :ok, state}
	end

	def handle_call({:join, channel, passwd}, _from, state) do
		unless passwd == "" do
			Transport.send(state, "JOIN " <> channel <> "\r\n")
		else
			Transport.send(state, "JOIN " <> channel <> " " <> passwd <> "\r\n")
		end
		{:reply, :ok, state}
	end

	def handle_call({:privmsg, to, data}, _from, state) do
		Transport.send(state, "PRIVMSG " <> to <> " :" <> data <> "\r\n")
		{:reply, :ok, state}
	end

	def handle_call({:away, msg}, _from, state) do
		if msg == "" do
			Transport.send(state, "AWAY\r\n")
		else
			Transport.send(state, "AWAY :" <> msg <> "\r\n")
		end
		{:reply, :ok, state}
	end

	def handle_call({:ping, server}, _from, state) do
		Transport.send(state, "PING :" <> server <> "\r\n")
		{:reply, :ok, state}
	end

	def handle_call({:pong, server}, _from, state) do
		Transport.send(state, "PONG :" <> server <> "\r\n")
		{:reply, :ok, state}
	end

	def handle_call({:quit, msg}, _from, state) do
		if msg == "" do
			Transport.send(state, "QUIT\r\n")
		else
			Transport.send(state, "QUIT :" <> msg <> "\r\n")
		end
		{:reply, :ok, state}
	end


	## Handle TCP stuff

	def handle_info(:test, state) do
		IO.puts "TEST!!"
		{:noreply, state}
	end

	def handle_info({:tcp, _, data}, state) do
		msg = Parser.parse(data)
		IO.inspect msg.cmd
		case msg.cmd do
			"PING" ->
				IO.inspect msg
				Transport.send(state, "PONG :" <> hd(msg.args) <> "\r\n")
			_ -> 
				send_to_handlers({:ircmsg, msg}, state.event_handlers)
		end
		{:noreply, state}
	end

	## Handle event handlers stopping

	def handle_info({'DOWN', _, _, pid, _}, %State{event_handlers: handlers} = state) do
		{:noreply, %State{state | event_handlers: remove_event_handler(pid, handlers)}}
	end

	## Catchall clause, let's ignore everything not we don't recognise
	def handle_info(msg, state) do
		IO.puts "Received a weird message..."
		IO.inspect msg
		{:noreply, state}
	end

	## Internal stuff

	defp send_to_handlers(data, handlers) do
		Enum.each(handlers, fn({pid, _}) -> send(pid, data) end)
	end
	
	defp add_event_handler(pid, handlers) do
		unless List.keymember?(handlers, pid, 0) do
			ref = Process.monitor(pid)
			[{pid, ref}, handlers]
		else
			handlers
		end
	end
	
	defp remove_event_handler(pid, handlers) do
		case List.keyfind(handlers, pid, 0) do
			{x, ref} ->
				Process.demonitor(ref)
				List.keydelete(handlers, x, 0)
			nil ->
				handlers
		end
	end		
end
