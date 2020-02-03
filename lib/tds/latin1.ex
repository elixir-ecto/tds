defmodule Tds.Latin1 do
  @moduledoc false

  def encode(str, "utf-16le") do
    with utf16 when is_bitstring(utf16) <-
           :unicode.characters_to_binary(
             str,
             :unicode,
             {:utf16, :little}
           ) do
      utf16
    else
      _ ->
        error = ~s(failed to convert string "#{inspect(str)}" to ucs2 binary)
        raise Tds.Error, error
    end
  end

  def encode(str, "windows-1252") do
    with utf16 when is_bitstring(utf16) <-
           :unicode.characters_to_binary(
             str,
             :unicode,
             :latin1
           ) do
      utf16
    else
      _ ->
        error = ~s(failed to convert string "#{inspect(str)}" to latin1 binary)
        raise Tds.Error, error
    end
  end

  def decode(binary, "utf-16le") do
    :binary.bin_to_list(binary)
    |> Enum.reject(&(&1 == 0))
    |> to_string()
  end

  def decode(binary, _) do
    binary
  end
end
