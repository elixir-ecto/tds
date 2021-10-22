defmodule Tds.Protocol.Prelogin do
  @moduledoc """
  Prelogin message definition

  See: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-tds/60f56408-0188-4cd5-8b90-25c6f2423868
  """
  import Tds.Protocol.Grammar
  require Logger

  @type state :: Tds.Protocol.t()
  @type packet_data :: iodata()

  @type response ::
          {:ok, state()}
          | {:error, Exception.t() | atom(), state()}

  defstruct version: nil,
            encryption: <<0x00>>,
            instance: true,
            threadid: nil,
            mars: false,
            fedauth: false,
            nonceopt: nil

  @type t :: %__MODULE__{
          version: tuple(),
          encryption: <<_::8>>,
          instance: boolean(),
          mars: boolean()
        }

  @packet_header 0x12

  @version_token 0x00
  @encryption_token 0x01
  @instopt_token 0x02
  @threadid_token 0x03
  @mars_token 0x04
  @fedauth_token 0x06
  @nonceopt_token 0x07
  @termintator_token 0xFF

  # ENCODE

  @spec encode(maybe_improper_list()) :: [binary(), ...]
  def encode(opts) do
    stream = [
      encode_version(opts),
      encode_encryption(opts),
      # when instance id check is sent, encryption is not negotiated
      # encode_instance(opts),
      encode_threadid(opts),
      encode_mars(opts),
      encode_fedauth(opts)
    ]

    start_offset = 5 * Enum.count(stream) + 1

    {iodata, _} =
      stream
      |> Enum.reduce({[[], @termintator_token, []], start_offset}, fn
        {token, option_data}, {[options, term, data], offset} ->
          data_length = byte_size(option_data)

          options = [
            options,
            <<token, offset::ushort(), data_length::ushort()>>
          ]

          data = [data, option_data]
          {[options, term, data], offset + data_length}
      end)

    data = IO.iodata_to_binary(iodata)
    Tds.Messages.encode_packets(@packet_header, data)
  end

  defp encode_version(_opts) do
    data =
      Application.spec(:tds)
      |> Keyword.get(:vsn)
      |> to_string()
      |> String.split(".")
      |> Enum.map(&(Integer.parse(&1, 10) |> elem(0)))
      |> case do
        [major, minor, build] ->
          <<build::little-ushort, minor, major, 0x00, 0x00>>

        [major, minor] ->
          <<0x00, 0x00, minor, major, 0x00, 0x00>>

        _ ->
          # probably PRE-release
          <<0x01, 0x00, 0, 1, 0x00, 0x00>>
      end

    {@version_token, data}
  end

  defp encode_encryption(opts) do
    data =
      if Keyword.get(opts, :ssl, false),
        do: <<0x01::byte>>,
        else: <<0x02::byte>>

    {@encryption_token, data}
  end

  defp encode_instance(opts) do
    # not working for some reason
    instance = Keyword.get(opts, :instance)

    if is_nil(instance) do
      {@instopt_token, <<0x00>>}
    else
      {@instopt_token, instance <> <<0x00>>}
    end
  end

  defp encode_threadid(_opts) do
    pid_serial =
      self()
      |> inspect()
      |> String.split(".")
      |> Enum.at(1)
      |> Integer.parse()
      |> elem(0)

    {@threadid_token, <<pid_serial::ulong()>>}
  end

  defp encode_mars(_opts) do
    {@mars_token, <<0x00>>}
  end

  defp encode_fedauth(_opts) do
    {@fedauth_token, <<0x01>>}
  end

  # DECODE
  @spec decode(iodata(), state()) ::
          {:encrypt, state()}
          | {:login, state()}
          | {:disconnect, Tds.Error.t(), state()}
  def decode(packet_data, %{opts: opts} = s) do
    ecrypt = Keyword.get(opts, :ssl, false)

    {:ok, %{encryption: encryption, instance: instance}} =
      packet_data
      |> IO.iodata_to_binary()
      |> decode_tokens([], s)

    case {ecrypt, encryption, instance} do
      {_, _, false} ->
        msg = "Connection terminated, connected instance is not '#{instance}'!"
        disconnect(msg, s)

      {false, enc, _} when enc in [<<0x00>>, <<0x02>>] ->
        {:login, s}

      {false, <<0x03>>, _} ->
        disconnect("Server does not allow the requested encryption level.", s)

      {true, <<0x00>>, _} ->
        disconnect("Server does not allow the requested encryption level.", s)

      {true, <<0x03>>, _} ->
        disconnect("Server does not allow the requested encryption level.", s)

      {_, _, _} ->
        Logger.debug("Upgrading connection to SSL/TSL.")
        {:encrypt, s}
    end
  end

  defp decode_tokens(
         <<@version_token, offset::ushort, length::ushort, tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:version, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<@encryption_token, offset::ushort, length::ushort, tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:encryption, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<@instopt_token, offset::ushort, length::ushort, tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:encryption, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<@threadid_token, offset::ushort, length::ushort, tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:threadid, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<@mars_token, offset::ushort, length::ushort, tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:mars, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<@fedauth_token, offset::ushort, length::ushort, tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:fedauth, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<@nonceopt_token, offset::ushort, length::ushort, tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:nonceopt, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<@termintator_token, tail::binary>>,
         tokens,
         _s
       ) do
    {:ok, decode_data(Enum.reverse(tokens), tail, %__MODULE__{})}
  end

  defp decode_data([], _, result), do: result

  defp decode_data([{key, _, length} | tokens], bin, m) do
    <<data::binary-size(length), tail::binary>> = bin

    case key do
      :version ->
        <<major, minor, patch, trivial, subbuild, _>> = data

        decode_data(
          tokens,
          tail,
          %{m | version: {major, minor, patch, trivial, subbuild}}
        )

      :encryption ->
        decode_data(
          tokens,
          tail,
          %{m | encryption: data}
        )

      :instance ->
        decode_data(
          tokens,
          tail,
          %{m | instance: data == <<0x00>>}
        )

      # :threadid ->
      # :mars ->
      # :fedauth ->
      # :nonceopt ->
      _ ->
        decode_data(tokens, tail, m)
    end
  end

  defp disconnect(message, s) do
    {:disconnect, Tds.Error.exception(message), s}
  end
end
