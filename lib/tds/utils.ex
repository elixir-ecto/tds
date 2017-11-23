defmodule Tds.Utils do
  require Logger
  #alias Tds.Connection

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

#  Connection.next is undefined
 # def ready(%{queue: queue} = s) do
 #   queue =
 #     case :queue.out(queue) do
 #     {{:value, {_, _, ref}}, q} ->
 #       Process.demonitor(ref)
 #       q
 #     {:empty, q} ->
 #       q
 #   end
 #   Connection.next(%{s | statement: "", queue: queue, state: :ready})
 # end

  # def pow10(num,0), do: num
  # def pow10(num,pow) when pow > 0 do
  #   pow10(10*num, pow - 1)
  # end

  # def pow10(num,pow) when pow < 0 do
  #   pow10(num/10, pow + 1)
  # end

  # def pow(_, 0), do: 1
  # def pow(a, 1), do: a

  # def pow(a, n) when rem(n, 2) === 0 do
  #   tmp = pow(a, div(n, 2))
  #   tmp * tmp
  # end

  # def pow(a, n) do
  #   a * pow(a, n-1)
  # end
end
