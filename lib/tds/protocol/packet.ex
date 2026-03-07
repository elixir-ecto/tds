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

  @type sock ::
          {module(), :gen_tcp.socket() | :ssl.sslsocket()}

  @default_max_payload_size 200 * 1024 * 1024

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

  # ---------------------------------------------------------------------------
  # Reassembly
  # ---------------------------------------------------------------------------

  @doc """
  Read and reassemble a complete TDS message from the socket.

  Reads one or more TDS packets, validates packet ID ordering,
  strips headers, and concatenates the data payloads.

  Returns `{:ok, type, payload}` on success.

  ## Options

    * `:max_payload_size` - maximum allowed payload in bytes
      (default: 200 MB)
  """
  @spec reassemble(sock(), keyword()) ::
          {:ok, byte(), binary()} | {:error, term()}
  def reassemble(sock, opts \\ []) do
    max =
      Keyword.get(
        opts,
        :max_payload_size,
        @default_max_payload_size
      )

    do_reassemble(sock, <<>>, nil, [], 0, nil, max)
  end

  defp do_reassemble(
         {mod, port} = sock,
         pending,
         pkt_type,
         buf,
         total,
         expected_id,
         max
       ) do
    case mod.recv(port, 0) do
      {:ok, data} ->
        process_packets(
          sock,
          pending <> data,
          pkt_type,
          buf,
          total,
          expected_id,
          max
        )

      {:error, reason} ->
        {:error, {:recv_failed, reason}}
    end
  end

  defp process_packets(
         sock,
         data,
         pkt_type,
         buf,
         total,
         expected_id,
         max
       ) do
    case decode_header(data) do
      {:error, :incomplete_header} ->
        do_reassemble(
          sock,
          data,
          pkt_type,
          buf,
          total,
          expected_id,
          max
        )

      {:ok, header, rest} ->
        case validate_packet_id(expected_id, header.packet_id) do
          :ok ->
            type = pkt_type || header.type
            data_len = header.length - packet_size(:header_size)

            extract_and_continue(
              sock,
              rest,
              type,
              buf,
              total,
              header,
              data_len,
              max
            )

          {:error, _} = err ->
            err
        end
    end
  end

  defp extract_and_continue(
         sock,
         rest,
         pkt_type,
         buf,
         total,
         header,
         data_len,
         max
       ) do
    case collect_chunk(sock, rest, data_len) do
      {:ok, chunk, tail} ->
        new_total = total + byte_size(chunk)

        if new_total > max do
          {:error, {:payload_too_large, new_total, max}}
        else
          next_id = rem(header.packet_id + 1, 256)

          finish_or_continue(
            sock,
            tail,
            pkt_type,
            [chunk | buf],
            new_total,
            header.status,
            next_id,
            max
          )
        end

      {:error, _} = err ->
        err
    end
  end

  defp collect_chunk(sock, available, needed) do
    available_len = byte_size(available)

    if available_len >= needed do
      <<chunk::binary-size(needed), tail::binary>> = available
      {:ok, chunk, tail}
    else
      {mod, port} = sock
      remaining = needed - available_len

      case mod.recv(port, remaining) do
        {:ok, more} ->
          combined = available <> more
          <<chunk::binary-size(needed), tail::binary>> = combined
          {:ok, chunk, tail}

        {:error, reason} ->
          {:error, {:recv_failed, reason}}
      end
    end
  end

  defp finish_or_continue(
         _sock,
         _tail,
         pkt_type,
         buf,
         _total,
         @status_eom,
         _next_id,
         _max
       ) do
    payload = buf |> Enum.reverse() |> IO.iodata_to_binary()
    {:ok, pkt_type, payload}
  end

  defp finish_or_continue(
         sock,
         tail,
         pkt_type,
         buf,
         total,
         @status_more,
         next_id,
         max
       ) do
    if byte_size(tail) > 0 do
      process_packets(
        sock,
        tail,
        pkt_type,
        buf,
        total,
        next_id,
        max
      )
    else
      do_reassemble(
        sock,
        <<>>,
        pkt_type,
        buf,
        total,
        next_id,
        max
      )
    end
  end

  defp validate_packet_id(nil, _actual), do: :ok
  defp validate_packet_id(expected, expected), do: :ok

  defp validate_packet_id(expected, actual) do
    {:error, {:out_of_order, expected: expected, got: actual}}
  end
end
