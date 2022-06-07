defmodule Tds.Protocol.Login7 do
  @moduledoc """
  Login7 message definition

  See: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-tds/773a62b6-ee89-4c02-9e5e-344882630aac
  """
  alias Tds.Encoding.UCS2
  import Tds.BinaryUtils

  @packet_header 0x10
  ## Packet Size
  @tds_pack_header_size 8
  @tds_pack_data_size 4088
  @tds_pack_size @tds_pack_header_size + @tds_pack_data_size
  @max_supported_tds_version <<0x04, 0x00, 0x00, 0x74>>
  @default_client_version <<0x04, 0x00, 0x00, 0x07>>
  @client_pid <<0x00, 0x10, 0x00, 0x00>>
  # SQL_DFLT
  @sql_type <<0x00>>
  @options <<0x00>>
  @clt_int_name "ODBC"
  @default_app_name "Elixir TDS"
  # EN-US
  @language_code_id <<0x09, 0x04, 0x00, 0x00>>

  defstruct [
    # Highest TDS version used by the client
    :tds_version,
    # The packet size being requested by the client
    :packet_size,
    # The version of the interface library (for example, ODBC or OLEDB) being used by the client.
    :client_version,
    # The process ID of the client application.
    :client_pid,
    # The connection ID of the primary Server. Used when connecting to an "Always Up" backup server.
    :connection_id,
    # Options (currently not used)
    :option_flags_1,
    # More options (also not used)
    :option_flags_2,
    # The SQL type sent to the client
    :type_flags,
    # More options (also not used)
    :option_flags_3,
    # This field is not used and can be set to zero.
    :client_time_zone,
    # The language code identifier (LCID) value for the client collation.
    # If ClientLCID is specified, the specified collation is set as the session collation.
    :client_language_code_id,
    # Client username
    :username,
    # Client password
    :password,
    # Server name
    :servername,
    # Application name
    :app_name,
    # Hostname of the SQL server
    :hostname,
    # Database to use (defaults to user database)
    :database
  ]

  def new(opts) do
    # gethostname/0 always succeeds
    {:ok, hostname} = :inet.gethostname()

    %__MODULE__{
      tds_version: @max_supported_tds_version,
      packet_size: <<@tds_pack_size::little-size(4)-unit(8)>>,
      hostname: to_string(hostname),
      app_name: Keyword.get(opts, :app_name, @default_app_name),
      client_version: @default_client_version,
      client_pid: pid!(),
      connection_id: <<0x00::size(32)>>,
      option_flags_1: @options,
      option_flags_2: @options,
      type_flags: @sql_type,
      option_flags_3: @options,
      client_time_zone: <<0x0, 0x0, 0x0, 0x0>>,
      client_language_code_id: @language_code_id,
      username: opts[:username],
      password: opts[:password],
      servername: opts[:hostname],
      database: Keyword.get(opts, :database, "")
    }
  end

  def encode(%__MODULE__{} = login) do
    # Fixed login configuration
    fixed_login = fixed_login(login)
    {variable_login, offsets} = encode_variable_login(login, byte_size(fixed_login) + 62)

    login7 = fixed_login <> offsets <> variable_login
    login7_len = byte_size(login7) + 4
    data = <<login7_len::little-size(32)>> <> login7

    Tds.Messages.encode_packets(@packet_header, data)
  end

  defp fixed_login(login) do
    login.tds_version <>
      login.packet_size <>
      login.client_version <>
      login.client_pid <>
      login.connection_id <>
      login.option_flags_1 <>
      login.option_flags_2 <>
      login.type_flags <>
      login.option_flags_3 <>
      login.client_time_zone <>
      login.client_language_code_id
  end

  defp encode_variable_login(login, start_offset) do
    current_offset = start_offset

    # Hostname
    offsets = <<current_offset::ushort(), String.length(login.hostname)::ushort()>>
    hostname = UCS2.from_string(login.hostname)
    variable_login = hostname
    current_offset = current_offset + byte_size(hostname)

    # Username
    offsets = offsets <> <<current_offset::ushort(), String.length(login.username)::ushort()>>
    username = UCS2.from_string(login.username)
    variable_login = variable_login <> username
    current_offset = current_offset + byte_size(username)

    # Password
    offsets = offsets <> <<current_offset::ushort(), String.length(login.password)::ushort()>>
    password = UCS2.from_string(login.password)
    variable_login = variable_login <> encode_tds_password(password)
    current_offset = current_offset + byte_size(password)

    # App Name
    offsets = offsets <> <<current_offset::ushort(), String.length(login.app_name)::ushort()>>
    app_name = UCS2.from_string(login.app_name)
    variable_login = variable_login <> app_name
    current_offset = current_offset + byte_size(app_name)

    # Servername
    offsets = offsets <> <<current_offset::ushort(), String.length(login.servername)::ushort()>>
    servername = UCS2.from_string(login.servername)
    variable_login = variable_login <> servername
    current_offset = current_offset + byte_size(servername)

    # Unused
    offsets = offsets <> <<0::ushort(), 0::ushort()>>

    # Client Int Name
    variable_login = variable_login <> UCS2.from_string(@clt_int_name)
    offsets = offsets <> <<current_offset::ushort(), 4::ushort()>>
    current_offset = current_offset + 8

    # Language
    offsets = offsets <> <<0::ushort(), 0::ushort()>>

    # Database
    variable_login = variable_login <> UCS2.from_string(login.database)

    database =
      if login.database == "" do
        0xAC
      else
        String.length(login.database)
      end

    offsets = offsets <> <<current_offset::ushort(), database::ushort()>>

    # Client ID
    offsets = offsets <> <<0::sixbyte()>>

    # SSPI
    offsets = offsets <> <<0::ushort(), 0::ushort()>>

    # Attach DB File
    offsets = offsets <> <<0::ushort(), 0::ushort()>>

    # Change password?
    offsets = offsets <> <<0::ushort(), 0::ushort()>>

    # SSPI Long
    offsets = offsets <> <<0::dword()>>

    {variable_login, offsets}
  end

  defp encode_tds_password(list) do
    for <<b::4, a::4 <- list>> do
      <<c>> = <<a::size(4), b::size(4)>>
      Bitwise.bxor(c, 0xA5)
    end
    |> Enum.map_join(&<<&1>>)
  end

  # Return the current pid
  # If that fails return a "default" pid
  defp pid! do
    value =
      self()
      |> :erlang.pid_to_list()
      |> to_string()
      |> String.split(".")
      |> Enum.at(1)
      |> String.to_integer()

    <<value::dword()>>
  rescue
    _ -> @client_pid
  end
end
