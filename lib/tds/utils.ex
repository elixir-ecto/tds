defmodule Tds.Utils do
  @moduledoc """
  Utility functions for Tds
  """
  alias Tds.Encoding.Latin1

  @doc """
  Encodes given string to given codepage using configured encoder.
  Defaults to Tds.Encoding.Latin1 if none is configured
  """
  def encode_chars(string, to_codepage) do
    Application.get_env(:tds, :text_encoder, Latin1)
    |> apply(:encode, [string, to_codepage])
  end

  def decode_chars(binary, from_codepage) when is_binary(binary) do
    Application.get_env(:tds, :text_encoder, Latin1)
    |> apply(:decode, [binary, from_codepage])
  end

  @doc false
  def use_elixir_calendar_types(value),
    do: Process.put(:use_elixir_calendar_types, value)

  @doc false
  def use_elixir_calendar_types?,
    do: Process.get(:use_elixir_calendar_types, false)
end
