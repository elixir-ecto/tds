defmodule Tds.Protocol.Header do
  import Tds.BinaryUtils
  import Bitwise

  @messages [
    {1, :sql_batch, true},
    {2, :login, true},
    {3, :rpc, true},
    {4, :result, true},
    {6, :attention, false},
    {7, :bulk_data, true},
    {8, :federation_token, true},
    {14, :tm_request, true},
    {16, :login7, true},
    {17, :sspi, true},
    {18, :pre_login, true}
  ]

  @type pkg_header_type ::
          :sql_batch
          | :login
          | :rpc
          | :result
          | :attention
          | :bulk_data
          | :federation_token
          | :tm_request
          | :login7
          | :sspi
          | :pre_login

  @typedoc """
  Header flag that should tell if package data that header preceding is end of
  TDS message or not.

  * `:eom` - End of message (EOM). The packet is the last packet in the whole
    request/response.
  * `normal` - Normal message, means that there is more packages comming after
    the one that header is preceding.
  """
  @type msg_send_status :: :normal | :eom
  @typedoc """
  (Client to SQL server only) Reset this connection before processing event.
  Only set for event types Batch, RPC, or Transaction Manager request
  """
  @type pkg_process :: :process | :ignore
  @typedoc """
  (Client to SQL server only) Reset the connection before processing event but
  do not modify the transaction state (the state will remain the same before and after the reset).
  """
  @type conn_reset :: :no_reset | :conn_reset | :conn_reset_skip_tran

  @typedoc """
  Tuple that holds decoded package header status flags.
  """
  @type pkg_header_status ::
          {msg_send_status, pkg_process, conn_reset}

  @typedoc """
  Decoded TDS package header
  """
  @type t :: %__MODULE__{
          type: pkg_header_type,
          status: pkg_header_status,
          length: any,
          spid: any,
          package: any,
          window: any,
          has_data?: any
        }

  defstruct [
    :type,
    :status,
    :length,
    :spid,
    :package,
    :window,
    has_data?: false
  ]

  @spec decode(<<_::64>>) :: t | {:error, any}
  def decode(
        <<type::int8(), status::int8(), length::int16(), spid::int16(), package::int8(),
          window::int8()>>
      ) do
    with {^type, pkg_header_type, has_data} <- decode_type(type) do
      {:ok,
       struct!(__MODULE__,
         type: pkg_header_type,
         status: decode_status(status),
         length: length - 8,
         spid: spid,
         package: package,
         window: window,
         has_data: has_data
       )}
    else
      {:error, _} = e -> e
    end
  end

  defp decode_type(type) when is_integer(type) do
    List.keyfind(
      @messages,
      type,
      0,
      {:error, Tds.Error.exception("TDS received unknown message type `#{type}`")}
    )
  end

  defp decode_status(status) do
    snd_status = if(0x01 == (status &&& 0x01), do: :eom, else: :normal)
    msg_ignore = if(0x02 == (status &&& 0x02), do: :ignore)

    conn_reset =
      cond do
        0x08 == (status &&& 0x08) -> :conn_reset
        0x10 == (status &&& 0x10) -> :conn_reset_skip_tran
        true -> :no_reset
      end

    {snd_status, msg_ignore, conn_reset}
  end

  # defp encode_type(pkg_header_type) when pkg_header_type in @pkg_header_types do
  #   List.keyfind(
  #     @messages,
  #     pkg_header_type,
  #     1,
  #     {:error,
  #      "[Protocol Error]: Unable to encode Message Type `#{pkg_header_type}`. " <>
  #        "It is unknown message type."}
  #   )
  # end
end
