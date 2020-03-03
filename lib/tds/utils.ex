defmodule Tds.Utils do
  @moduledoc false
  require Logger

  def to_hex_list(x) when is_list(x) do
    Enum.map(x, &Base.encode16(<<&1>>))
  end

  def to_hex_list(x) when is_binary(x) do
    x
    |> :erlang.binary_to_list()
    |> to_hex_list()
  end

  def to_hex_string(x) when is_binary(x) do
    x
    |> to_hex_list()
    |> to_hex_string()
  end

  def to_hex_string(x) when is_list(x) do
    Enum.join(x, " ")
  end

  def to_little_ucs2(str) when is_list(str) do
    str
    |> IO.iodata_to_binary()
    |> to_little_ucs2()
  end

  def to_little_ucs2(str) do
    encode_chars(str, "utf-16le")
  end

  def ucs2_to_utf(s) do
    decode_chars(s, "utf-16le")
  end

  def encode_chars(string, to_codepage) do
    Application.get_env(:tds, :text_encoder, Tds.Latin1)
    |> apply(:encode, [string, to_codepage])
  end

  def decode_chars(binary, from_codepage) do
    Application.get_env(:tds, :text_encoder, Tds.Latin1)
    |> apply(:decode, [binary, from_codepage])
  end

  def to_boolean(<<1>>) do
    true
  end

  def to_boolean(<<0>>) do
    false
  end

  def error(error, _s) do
    {:error, error}
  end

  def to_decimal(float), do: Decimal.from_float(float)

  @doc false
  def use_elixir_calendar_types(value),
    do: Process.put(:use_elixir_calendar_types, value)

  @doc false
  def use_elixir_calendar_types?,
    do: Process.get(:use_elixir_calendar_types, false)
end
