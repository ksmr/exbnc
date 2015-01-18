defmodule BNC.Parser do
	alias BNC.Message, as: Message

	def parse(line) do
		case String.split(line) do
			[<< ":" , prefix :: binary>> | [cmd | args]] ->
				%Message{raw: line, prefix: prefix, cmd: cmd, args: parse_args(args) ++ []}
			[cmd | args] ->
				%Message{raw: line, cmd: cmd, args: parse_args(args)}
		end
	end

	defp parse_args(list) do
		case list do
			[] -> []
			[<< ?:, word :: binary>> | rest] -> [List.foldr([word | rest], "", fn(x,y) -> unless y == "", do: x <> " " <> y, else: x end)]
			[head | tail] -> [head | parse_args(tail)]
		end
	end
end
