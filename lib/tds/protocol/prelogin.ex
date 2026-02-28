defmodule Tds.Protocol.Prelogin do
  @moduledoc """
  Prelogin message definition

  See: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-tds/60f56408-0188-4cd5-8b90-25c6f2423868
  """
  alias Tds.Protocol.Packet
  import Tds.Protocol.Binary
  import Tds.Protocol.Constants
  require Logger

  @type state :: Tds.Protocol.t()
  @type packet_data :: iodata()

  @type response ::
          {:ok, state()}
          | {:error, Exception.t() | atom(), state()}

  defstruct version: nil,
            encryption: <<0x00>>,
            instance: true,
            thread_id: nil,
            mars: false,
            trace_id: nil,
            fed_auth_required: false,
            nonce_opt: nil

  @type t :: %__MODULE__{
          version: tuple(),
          encryption: <<_::8>>,
          instance: boolean(),
          mars: boolean()
        }

  # Packet type, prelogin token types, and encryption flags are now
  # sourced from Tds.Protocol.Constants via import above.

  @version Mix.Project.config()[:version]
           |> String.split(".")
           |> Enum.map(&(Integer.parse(&1, 10) |> elem(0)))

  @spec encode(maybe_improper_list()) :: [binary(), ...]
  def encode(opts) do
    stream = [
      {prelogin_token_type(:version), get_version()},
      encode_encryption(opts),
      # when instance id check is sent, encryption is not negotiated
      # encode_instance(opts),
      encode_thread_id(opts),
      encode_mars(opts),
      encode_fed_auth_required(opts)
    ]

    start_offset = 5 * Enum.count(stream) + 1

    {iodata, _} =
      stream
      |> Enum.reduce({[[], prelogin_token_type(:terminator), []], start_offset}, fn
        {token, option_data}, {[options, term, data], offset} ->
          data_length = byte_size(option_data)

          options = [
            options,
            <<token, offset::ushort(:big), data_length::ushort(:big)>>
          ]

          data = [data, option_data]
          {[options, term, data], offset + data_length}
      end)

    data = IO.iodata_to_binary(iodata)
    Packet.encode(packet_type(:prelogin), data)
  end

  defp get_version do
    @version
    |> case do
      [major, minor, build] ->
        <<build::ushort(), minor, major, 0x00, 0x00>>

      [major, minor] ->
        <<0x00, 0x00, minor, major, 0x00, 0x00>>

      _ ->
        # probably PRE-release
        <<0x01, 0x00, 0, 1, 0x00, 0x00>>
    end
  end

  # TODO: Add support for client certificates
  defp encode_encryption(opts) do
    data =
      case ssl?(opts) do
        :on ->
          <<encryption(:on)::byte()>>

        :not_supported ->
          <<encryption(:not_supported)::byte()>>

        :required ->
          <<encryption(:required)::byte()>>

        :off ->
          # TODO: Support ssl: :off
          # This requires that the LOGIN7 message is send encrypted, but
          # the other packages are send unencrypted over the wire.
          raise ArgumentError, ~s("ssl: :off" is currently not supported)

        # <<encryption(:off)::byte>>

        value ->
          raise ArgumentError, "invalid value for :ssl: #{inspect(value)}"
      end

    {prelogin_token_type(:encryption), data}
  end

  # defp encode_instance(opts) do
  #   # not working for some reason
  #   instance = Keyword.get(opts, :instance)

  #   if is_nil(instance) do
  #     {@instopt_token, <<0x00>>}
  #   else
  #     {@instopt_token, instance <> <<0x00>>}
  #   end
  # end

  defp encode_thread_id(_opts) do
    pid_serial =
      self()
      |> inspect()
      |> String.split(".")
      |> Enum.at(1)
      |> Integer.parse()
      |> elem(0)

    {prelogin_token_type(:thread_id), <<pid_serial::ulong(:big)>>}
  end

  defp encode_mars(_opts) do
    {prelogin_token_type(:mars), <<0x00>>}
  end

  defp encode_fed_auth_required(_opts) do
    {prelogin_token_type(:fed_auth_required), <<0x01>>}
  end

  # DECODE
  @spec decode(iodata(), state()) ::
          {:encrypt, state()}
          | {:login, state()}
          | {:disconnect, Tds.Error.t(), state()}
  def decode(packet_data, %{opts: opts} = s) do
    {:ok, %{encryption: encryption, instance: instance}} =
      packet_data
      |> IO.iodata_to_binary()
      |> decode_tokens([], s)

    case {ssl?(opts), encryption, instance} do
      {_, _, false} ->
        msg = "Connection terminated, connected instance is not '#{instance}'!"
        disconnect(msg, s)

      # Encryption is off. Allowed server response is :off or :not_supported
      {:off, enc, _} when enc in [<<encryption(:off)>>, <<encryption(:not_supported)>>] ->
        {:login, s}

      # TODO: Encryption is off but server has encryption on. Should upgrade.
      {:off, <<encryption(:required)>>, _} ->
        disconnect("Server does not allow the requested encryption level.", s)

      # Encryption is not supported. The server needs to respond with :not_supported
      {:not_supported, <<encryption(:not_supported)>>, _} ->
        {:login, s}

      # Encryption is on. The server needs to respond with :on
      {:on, <<encryption(:on)>>, _} ->
        {:encrypt, s}

      # Encryption is required. The server needs to respond with :on
      {:required, <<encryption(:on)>>, _} ->
        {:encrypt, s}

      {_, _, _} ->
        disconnect("Server does not allow the requested encryption level.", s)
    end
  end

  defp decode_tokens(
         <<prelogin_token_type(:version), offset::ushort(:big), length::ushort(:big),
           tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:version, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<prelogin_token_type(:encryption), offset::ushort(:big), length::ushort(:big),
           tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:encryption, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<prelogin_token_type(:instopt), offset::ushort(:big), length::ushort(:big),
           tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:instance, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<prelogin_token_type(:thread_id), offset::ushort(:big), length::ushort(:big),
           tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:thread_id, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<prelogin_token_type(:mars), offset::ushort(:big), length::ushort(:big), tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:mars, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<prelogin_token_type(:fed_auth_required), offset::ushort(:big), length::ushort(:big),
           tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:fed_auth_required, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<prelogin_token_type(:nonce_opt), offset::ushort(:big), length::ushort(:big),
           tail::binary>>,
         tokens,
         s
       ) do
    tokens = [{:nonce_opt, offset, length} | tokens]
    decode_tokens(tail, tokens, s)
  end

  defp decode_tokens(
         <<prelogin_token_type(:terminator), tail::binary>>,
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

      # :thread_id ->
      # :mars ->
      # :fed_auth_required ->
      # :nonce_opt ->
      _ ->
        decode_data(tokens, tail, m)
    end
  end

  defp disconnect(message, s) do
    {:disconnect, Tds.Error.exception(message), s}
  end

  defp ssl?(opts) do
    case opts[:ssl] do
      nil ->
        :not_supported

      true ->
        :required

      false ->
        :not_supported

      other ->
        other
    end
  end
end
