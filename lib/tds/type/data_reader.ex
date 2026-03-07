defmodule Tds.Type.DataReader do
  @moduledoc """
  Reads type-specific value bytes from the TDS token stream.

  Handles six framing strategies. All strategies sever sub-binary
  references via `:binary.copy/1` or `IO.iodata_to_binary/1` to
  prevent packet buffer memory leaks.
  """

  @spec read(strategy :: term(), binary()) ::
          {nil | binary(), rest :: binary()}

  # Fixed-length: size known from type metadata
  def read({:fixed, length}, binary) do
    <<value::binary-size(length), rest::binary>> = binary
    {:binary.copy(value), rest}
  end

  # Bytelen: 1-byte length prefix, 0x00 = NULL
  def read(:bytelen, <<0x00, rest::binary>>), do: {nil, rest}

  def read(:bytelen, <<size::unsigned-8, data::binary-size(size), rest::binary>>),
    do: {:binary.copy(data), rest}

  # Shortlen: 2-byte LE length prefix, 0xFFFF = NULL
  def read(:shortlen, <<0xFF, 0xFF, rest::binary>>), do: {nil, rest}

  def read(:shortlen, <<size::little-unsigned-16, data::binary-size(size), rest::binary>>),
    do: {:binary.copy(data), rest}

  # Longlen: text_ptr + timestamp + 4-byte length, 0x00 = NULL
  def read(:longlen, <<0x00, rest::binary>>), do: {nil, rest}

  def read(
        :longlen,
        <<
          ptr_size::unsigned-8,
          _ptr::binary-size(ptr_size),
          _timestamp::unsigned-64,
          size::little-signed-32,
          data::binary-size(size),
          rest::binary
        >>
      ),
      do: {:binary.copy(data), rest}

  # Variant: 4-byte LE length prefix, 0x00000000 = NULL
  def read(:variant, <<0::little-unsigned-32, rest::binary>>),
    do: {nil, rest}

  def read(:variant, <<size::little-unsigned-32, data::binary-size(size), rest::binary>>),
    do: {:binary.copy(data), rest}

  # PLP: 8-byte NULL marker or chunked data
  def read(
        :plp,
        <<
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          rest::binary
        >>
      ),
      do: {nil, rest}

  def read(:plp, <<_total::little-unsigned-64, rest::binary>>) do
    {chunks, rest} = read_plp_chunks(rest, [])
    data = :lists.reverse(chunks) |> IO.iodata_to_binary()
    {data, rest}
  end

  defp read_plp_chunks(<<0::little-unsigned-32, rest::binary>>, acc),
    do: {acc, rest}

  defp read_plp_chunks(
         <<size::little-unsigned-32, chunk::binary-size(size), rest::binary>>,
         acc
       ),
       do: read_plp_chunks(rest, [:binary.copy(chunk) | acc])
end
