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
  # OptionFlags3 fExtension: ibExtension points at a FeatureExt block
  @option_flags_3_extension <<0x10>>
  @feature_ext_fedauth 0x02
  @feature_ext_terminator 0xFF
  @fedauth_library_security_token 0x01

  @derive {Inspect, except: [:password, :access_token]}
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
    :database,
    # Entra (Azure AD) access token for FEDAUTH SECURITYTOKEN login
    :access_token,
    # The server's PRELOGIN FEDAUTHREQUIRED answer and NONCE, echoed in FEDAUTH
    fed_auth: %{echo: false, nonce: nil}
  ]

  @doc """
  Builds a LOGIN7 message from connection options.

  With `:access_token` set, the login authenticates with the FEDAUTH
  SECURITYTOKEN feature extension and sends an empty username and password,
  whatever `:username` and `:password` hold. `fed_auth` carries what the
  server's PRELOGIN response said, which that feature echoes.
  """
  def new(opts, fed_auth \\ %{echo: false, nonce: nil}) do
    # gethostname/0 always succeeds
    {:ok, hostname} = :inet.gethostname()

    login = %__MODULE__{
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

    case Keyword.get(opts, :access_token) do
      nil ->
        login

      token ->
        %{
          login
          | username: "",
            password: "",
            option_flags_3: @option_flags_3_extension,
            access_token: token,
            fed_auth: fed_auth
        }
    end
  end

  @doc false
  def feature_ext_fedauth, do: @feature_ext_fedauth

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

    clt_int_name = UCS2.from_string(@clt_int_name)
    database = UCS2.from_string(login.database)

    # Unused, or ibExtension/cbExtension: a DWORD, after the database field,
    # holding the offset of the FeatureExt block that follows it
    extension_at = current_offset + byte_size(clt_int_name) + byte_size(database)

    offsets =
      if login.access_token do
        offsets <> <<extension_at::ushort(), 4::ushort()>>
      else
        offsets <> <<0::ushort(), 0::ushort()>>
      end

    # Client Int Name
    variable_login = variable_login <> clt_int_name
    offsets = offsets <> <<current_offset::ushort(), 4::ushort()>>
    current_offset = current_offset + 8

    # Language
    offsets = offsets <> <<0::ushort(), 0::ushort()>>

    # Database
    variable_login = variable_login <> database

    # The legacy 0xAC length for an empty database would run that field over
    # the extension data after it, so a token login sends a true zero length.
    database_length =
      if login.database == "" and is_nil(login.access_token),
        do: 0xAC,
        else: String.length(login.database)

    offsets = offsets <> <<current_offset::ushort(), database_length::ushort()>>

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

    variable_login =
      if login.access_token do
        variable_login <> <<extension_at + 4::dword()>> <> feature_ext(login)
      else
        variable_login
      end

    {variable_login, offsets}
  end

  defp feature_ext(%{access_token: token, fed_auth: %{echo: echo, nonce: nonce}}) do
    token = UCS2.from_string(token)
    echo = if echo, do: 1, else: 0

    data =
      <<@fedauth_library_security_token::7, echo::1, byte_size(token)::dword()>> <>
        token <> (nonce || <<>>)

    <<@feature_ext_fedauth, byte_size(data)::dword()>> <> data <> <<@feature_ext_terminator>>
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
    System.pid()
    |> Integer.parse()
    |> case do
      {pid, ""} ->
        <<pid::dword()>>

      _ ->
        @client_pid
    end
  end
end
