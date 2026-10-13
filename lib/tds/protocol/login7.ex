defmodule Tds.Protocol.Login7 do
  @moduledoc """
  Login7 message definition

  See: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-tds/773a62b6-ee89-4c02-9e5e-344882630aac
  """
  alias Tds.Encoding.UCS2
  import Tds.BinaryUtils
  require Bitwise

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
  # OptionFlags3 fExtension bit, set when the message contains an
  # extension block (MS-TDS 2.2.6.5)
  @f_extension 0x10
  # FeatureExt FEDAUTH, Security Token library (MS-TDS 2.2.6.5)
  # The Options byte is bFedAuthLibrary (bits 1-3) << 1 | fFedAuthEcho (bit 0)
  @fed_auth_feature_id 0x02
  @fed_auth_security_token_library 0x01
  @fed_auth_echo 0x01
  @feature_ext_terminator 0xFF

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
    # Federated authentication (Security Token library), access token
    # sent inside the FEDAUTH FeatureExt block
    :fed_auth_token,
    # Must mirror the FEDAUTHREQUIRED option from the server PRELOGIN response
    :fed_auth_echo,
    # Nonce echoed back when fed_auth_echo is set
    :nonce
  ]

  def new(opts) do
    # gethostname/0 always succeeds
    {:ok, hostname} = :inet.gethostname()

    token = opts[:access_token]
    fed_auth = is_binary(token) and token != ""

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
      option_flags_3: if(fed_auth, do: <<@f_extension>>, else: @options),
      client_time_zone: <<0x0, 0x0, 0x0, 0x0>>,
      client_language_code_id: @language_code_id,
      username: if(fed_auth, do: "", else: opts[:username]),
      password: if(fed_auth, do: "", else: opts[:password]),
      servername: opts[:hostname],
      database: Keyword.get(opts, :database, ""),
      fed_auth_token: if(fed_auth, do: token, else: nil),
      fed_auth_echo: fed_auth and opts[:fed_auth_required] == true,
      nonce: opts[:nonce]
    }
  end

  def encode(%__MODULE__{} = login) do
    # Fixed login configuration
    fixed_login = fixed_login(login)
    {variable_login, offsets} = encode_variable_login(login, byte_size(fixed_login) + 62)

    tail =
      if fed_auth?(login) do
        base_size = byte_size(fixed_login) + byte_size(offsets) + byte_size(variable_login)
        variable_login <> encode_fed_auth_extension(login, base_size)
      else
        variable_login
      end

    login7 = fixed_login <> offsets <> tail
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

    # Unused / ibExtension + cbExtension
    offsets =
      if fed_auth?(login) do
        database_data = UCS2.from_string(login.database)
        # The extension block follows the rest of the variable data
        ib_extension = current_offset + 8 + byte_size(database_data)
        offsets <> <<ib_extension::ushort(), 4::ushort()>>
      else
        offsets <> <<0::ushort(), 0::ushort()>>
      end

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

  defp fed_auth?(%__MODULE__{fed_auth_token: token})
       when is_binary(token) and token != "",
       do: true

  defp fed_auth?(_login), do: false

  # LOGIN7 extension block (MS-TDS 2.2.6.5): a DWORD ibFeatureExtLong that
  # points to the FeatureExt block which follows it.
  # base_size is relative to the end of the LOGIN7 Length field: add 4 bytes
  # for the Length field itself and 4 for the ibFeatureExtLong DWORD to get
  # the absolute message offset of the FeatureExt block.
  defp encode_fed_auth_extension(login, base_size) do
    feature_data = encode_fed_auth_feature_data(login)
    ib_feature_ext = base_size + 8

    <<ib_feature_ext::little-size(32)>> <>
      <<@fed_auth_feature_id, byte_size(feature_data)::little-size(32), feature_data::binary,
        @feature_ext_terminator>>
  end

  # FEDAUTH FeatureExt data for the Security Token library (MS-TDS 2.2.6.5)
  # options + FedAuthToken + [Nonce]
  #
  # Options byte layout: bFedAuthLibrary occupies bits 1-3 (Security Token
  # library = 0x01, shifted left by 1) and fFedAuthEcho is bit 0.
  # FedAuthToken is encodeed as UTF-16EL (UCS-2), matching the Unicode String
  # encoding used elsewhere in LOGIN7, with TokenLength set to its UTF-16LE
  # by length
  defp encode_fed_auth_feature_data(%__MODULE__{
         fed_auth_token: token,
         fed_auth_echo: echo,
         nonce: nonce
       }) do
    library_bits = Bitwise.bsl(@fed_auth_security_token_library, 1)

    options =
      if echo,
        do: Bitwise.bor(library_bits, @fed_auth_echo),
        else: library_bits

    nonce = if echo and is_binary(nonce), do: nonce, else: <<>>

    token_bin = UCS2.from_string(token)

    <<options>> <> <<byte_size(token_bin)::little-size(32)>> <> token_bin <> nonce
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
