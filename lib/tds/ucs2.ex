defmodule Tds.UCS2 do
  @moduledoc """
  Converting UTF-8 strings into UCS-2 (UTF16 Little Endian) strings
  used by the MSSQL Database
  """
  alias Tds.Utils

  @ucs2_charset "utf-16le"

  @doc """
  Converts a UTF-8 string into UCS-2
  """
  @spec from_string(binary | list) :: binary
  def from_string(list) when is_list(list) do
    list
    |> IO.iodata_to_binary()
    |> Utils.encode_chars(@ucs2_charset)
  end

  def from_string(string) when is_binary(string) do
    Utils.encode_chars(string, @ucs2_charset)
  end

  @doc """
  Converts a UCS-2 string into UTF-8
  """
  @spec to_string(binary) :: binary
  def to_string(string) when is_binary(string) do
    Utils.decode_chars(string, @ucs2_charset)
  end
end
