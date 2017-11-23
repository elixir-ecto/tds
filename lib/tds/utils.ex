defmodule Tds.Utils do
  require Logger

  def to_hex_list(x) when is_list(x) do
    Enum.map x, &( Base.encode16(<<&1>>))
  end

  def to_hex_list(x) when is_binary(x)  do
    :erlang.binary_to_list(x)
      |> to_hex_list
  end

  def to_hex_string(x) when is_binary(x) do
    to_hex_list(x)
      |> to_hex_string
  end

  def to_hex_string(x) when is_list(x) do
    Enum.join x, " "
  end

  def to_little_ucs2(str) do
    with utf16 when is_bitstring(utf16) <-
      :unicode.characters_to_binary(str, :unicode, {:utf16, :little})
    do
      utf16
    else
      _ -> raise Tds.Error, ~s(failed to covert string "#{inspect(str)}" to ucs2 binary)
    end
    
  end

  def ucs2_to_utf(s) do
    :binary.bin_to_list(s) |> Enum.reject(&(&1 == 0)) |> to_string
  end

  def to_boolean(<<1>>) do
    true
  end

  def to_boolean(<<0>>) do
    false
  end

  def error(error, s) do
    reply(error, s)
    {:error, error}
  end

  def reply(reply, %{queue: queue}) do
    case :queue.out(queue) do
      {{:value, {_command, from, _ref}}, _queue} ->
        GenServer.reply(from, reply)
        true
      {:empty, _queue} ->
        false
    end
  end

  def reply(reply, {_, _} = from) do
    GenServer.reply(from, reply)
    true
  end
end
