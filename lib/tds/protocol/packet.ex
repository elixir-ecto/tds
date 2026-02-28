defmodule Tds.Protocol.Packet do
  @moduledoc """
  TDS packet framing: encode payloads into TDS packets and
  decode packet headers.

  TDS packets are at most 4096 bytes: an 8-byte header followed
  by up to 4088 bytes of data. Messages larger than 4088 bytes
  are split across multiple packets with incrementing packet IDs.
  """

  import Tds.Protocol.Constants

  @status_more 0x00
  @status_eom 0x01

  @type header :: %{
          type: byte(),
          status: byte(),
          length: pos_integer(),
          spid: non_neg_integer(),
          packet_id: byte(),
          window: byte()
        }

  @doc """
  Encode a payload into one or more TDS packets.

  Returns a list of iodata, one entry per packet. Each entry
  contains an 8-byte TDS header followed by up to 4088 bytes
  of payload data.

  Packet IDs start at 1 and wrap at 256 per the TDS spec.
  """
  @spec encode(byte(), binary()) :: [iodata()]
  def encode(type, payload) when is_binary(payload) do
    do_encode(type, payload, 1)
  end

  defp do_encode(_type, <<>>, _id), do: []

  defp do_encode(
         type,
         <<chunk::binary-size(packet_size(:max_data_size)), rest::binary>>,
         id
       ) do
    status =
      if byte_size(rest) > 0, do: @status_more, else: @status_eom

    [
      build_packet(type, chunk, id, status)
      | do_encode(type, rest, rem(id + 1, 256))
    ]
  end

  defp do_encode(type, chunk, id) when is_binary(chunk) do
    [build_packet(type, chunk, id, @status_eom)]
  end

  defp build_packet(type, data, id, status) do
    length = byte_size(data) + packet_size(:header_size)
    [<<type, status, length::16-big, 0::16, id, 0>>, data]
  end

  @doc """
  Parse an 8-byte TDS packet header from a binary.

  Returns `{:ok, header, rest}` where `rest` is the remaining
  bytes after the header, or `{:error, :incomplete_header}` if
  the binary is shorter than 8 bytes.
  """
  @spec decode_header(binary()) ::
          {:ok, header(), binary()} | {:error, :incomplete_header}
  def decode_header(<<
        type,
        status,
        length::16-big,
        spid::16-little,
        packet_id,
        window,
        rest::binary
      >>) do
    header = %{
      type: type,
      status: status,
      length: length,
      spid: spid,
      packet_id: packet_id,
      window: window
    }

    {:ok, header, rest}
  end

  def decode_header(_), do: {:error, :incomplete_header}
end
