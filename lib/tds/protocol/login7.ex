defmodule Tds.Protocol.Login7 do
  @moduledoc """
  Login7 message definition

  See: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-tds/773a62b6-ee89-4c02-9e5e-344882630aac
  """

  import Tds.Utils

  @packet_header 0x10
  ## Packet Size
  @tds_pack_data_size 4088
  @tds_pack_header_size 8
  @tds_pack_size @tds_pack_header_size + @tds_pack_data_size
  @default_tds_version <<0x04, 0x00, 0x00, 0x74>>

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
    :option_flags_1,
    :option_flags_2,
    :type_flags,
    :option_flags_3,
    :client_time_zone,
    :client_language_code_id,
    :username,
    :password,
    :servername,
    :app_name,
    :hostname,
    :database
  ]

  def encode(opts) do
    {:ok, hostname} = :inet.gethostname()

    login = %__MODULE__{
      tds_version: @default_tds_version,
      packet_size: <<@tds_pack_size::little-size(4)-unit(8)>>,
      hostname: to_string(hostname),
      app_name: Keyword.get(opts, :app_name, default_app_name()),
      client_version: <<0x04, 0x00, 0x00, 0x07>>,
      client_pid: <<0x00, 0x10, 0x00, 0x00>>,
      connection_id: <<0x00::size(32)>>,
      option_flags_1: <<0x00>>,
      option_flags_2: <<0x00>>,
      type_flags: <<0x00>>,
      option_flags_3: <<0x00>>,
      client_time_zone: <<0xE0, 0x01, 0x00, 0x00>>,
      client_language_code_id: <<0x09, 0x04, 0x00, 0x00>>,
      username: opts[:username],
      password: opts[:password],
      servername: opts[:hostname],
      database: Keyword.get(opts, :database, "")
    }

    login_a =
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

    offset_start = byte_size(login_a) + 4
    username = to_little_ucs2(login.username)

    password =
      login.password
      |> to_little_ucs2()
      |> encode_tdspassword()

    servername = to_little_ucs2(login.servername)
    app_name = to_little_ucs2(login.app_name)
    hostname = to_little_ucs2(login.hostname)

    clt_int_name = to_little_ucs2("ODBC")
    database = to_little_ucs2(login.database)

    login_data =
      hostname <>
        username <>
        password <>
        app_name <>
        servername <>
        clt_int_name <>
        database

    curr_offset = offset_start + 58
    ibHostName = <<curr_offset::little-size(16)>>
    cchHostName = <<String.length(login.hostname)::little-size(16)>>
    curr_offset = curr_offset + byte_size(hostname)

    ibUserName = <<curr_offset::little-size(16)>>
    cchUserName = <<String.length(login.username)::little-size(16)>>
    curr_offset = curr_offset + byte_size(username)

    ibPassword = <<curr_offset::little-size(16)>>
    cchPassword = <<String.length(login.password)::little-size(16)>>
    curr_offset = curr_offset + byte_size(password)

    ibAppName = <<curr_offset::little-size(16)>>
    cchAppName = <<String.length(login.app_name)::little-size(16)>>
    curr_offset = curr_offset + byte_size(app_name)

    ibServerName = <<curr_offset::little-size(16)>>
    cchServerName = <<String.length(login.servername)::little-size(16)>>
    curr_offset = curr_offset + byte_size(servername)

    ibUnused = <<0::size(16)>>
    cbUnused = <<0::size(16)>>

    ibCltIntName = <<curr_offset::little-size(16)>>
    cchCltIntName = <<4::little-size(16)>>
    curr_offset = curr_offset + 4 * 2

    ibLanguage = <<0::size(16)>>
    cchLanguage = <<0::size(16)>>

    ibDatabase = <<curr_offset::little-size(16)>>

    cchDatabase =
      if login.database == "" do
        <<0xAC>>
      else
        <<String.length(login.database)::little-size(16)>>
      end

    clientID = <<0::size(48)>>

    ibSSPI = <<0::size(16)>>
    cbSSPI = <<0::size(16)>>

    ibAtchDBFile = <<0::size(16)>>
    cchAtchDBFile = <<0::size(16)>>

    ibChangePassword = <<0::size(16)>>
    cchChangePassword = <<0::size(16)>>

    cbSSPILong = <<0::size(32)>>

    offset =
      ibHostName <>
        cchHostName <>
        ibUserName <>
        cchUserName <>
        ibPassword <>
        cchPassword <>
        ibAppName <>
        cchAppName <>
        ibServerName <>
        cchServerName <>
        ibUnused <>
        cbUnused <>
        ibCltIntName <>
        cchCltIntName <>
        ibLanguage <>
        cchLanguage <>
        ibDatabase <>
        cchDatabase <>
        clientID <>
        ibSSPI <>
        cbSSPI <>
        ibAtchDBFile <>
        cchAtchDBFile <> ibChangePassword <> cchChangePassword <> cbSSPILong

    login7 = login_a <> offset <> login_data

    login7_len = byte_size(login7) + 4
    data = <<login7_len::little-size(32)>> <> login7
    Tds.Messages.encode_packets(0x10, data)
  end

  defp encode_tdspassword(list) do
    for <<b::4, a::4 <- list>> do
      <<c>> = <<a::size(4), b::size(4)>>
      Bitwise.bxor(c, 0xA5)
    end
    |> Enum.map_join(&<<&1>>)
  end

  defp default_app_name, do: Node.self() |> Atom.to_string()
end
