defmodule Tds.Encoding.Latin1 do
  @moduledoc """
  Default encoding for Tds
  """

  @spec encode(binary, String.t()) :: binary
  def encode(str, "utf-16le") when is_binary(str) do
    case :unicode.characters_to_binary(str, :unicode, {:utf16, :little}) do
      utf16 when is_bitstring(utf16) ->
        utf16

      _ ->
        error = ~s(failed to convert string "#{inspect(str)}" to ucs2 binary)
        raise Tds.Error, error
    end
  end

  def encode(str, "windows-1252") when is_binary(str) do
    case :unicode.characters_to_binary(str, :unicode, :latin1) do
      utf16 when is_bitstring(utf16) ->
        utf16

      _ ->
        error = ~s(failed to convert string "#{inspect(str)}" to latin1 binary)
        raise Tds.Error, error
    end
  end

  def encode(str, encoding) when is_binary(str) do
    raise Tds.Error,
          "You are using default `Tds.Encoding.Latin1` but you are trying to " +
            "encode a string with an unsupported encoding. " +
            "Please set `:text_encoder`  in your config.exs to a module supports `#{encoding}`."
  end

  def decode(binary, "utf-16le") when is_binary(binary) do
    :unicode.characters_to_binary(binary, {:utf16, :little})
  end

  def decode(binary, _) when is_binary(binary) do
    binary
  end
end
