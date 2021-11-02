defmodule Tds.Protocol.Login7 do
  @moduledoc """
  Login7 message definition

  See: https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-tds/773a62b6-ee89-4c02-9e5e-344882630aac
  """
  alias Tds.UCS2

  @packet_header 0x10
  ## Packet Size
  @tds_pack_header_size 8
  @tds_pack_data_size 4088
  @tds_pack_size @tds_pack_header_size + @tds_pack_data_size
  @default_tds_version <<0x04, 0x00, 0x00, 0x74>>
  @clt_int_name "ODBC"

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

    # Fixed login configuration
    login_a = get_login_a(login)
    # Dynamic login configuration (username, password, ...)
    login_data = get_login_data(login)
    # Offsets and length for dynamic login configuration
    offsets = get_offsets(login, byte_size(login_a) + 62)

    login7 = login_a <> offsets <> login_data
    login7_len = byte_size(login7) + 4
    data = <<login7_len::little-size(32)>> <> login7

    Tds.Messages.encode_packets(@packet_header, data)
  end

  defp get_login_a(login) do
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

  defp get_login_data(login) do
    username = UCS2.from_string(login.username)

    password =
      login.password
      |> UCS2.from_string()
      |> encode_tds_password()

    servername = UCS2.from_string(login.servername)
    app_name = UCS2.from_string(login.app_name)
    hostname = UCS2.from_string(login.hostname)

    clt_int_name = UCS2.from_string(@clt_int_name)
    database = UCS2.from_string(login.database)

    hostname <>
      username <>
      password <>
      app_name <>
      servername <>
      clt_int_name <>
      database
  end

  defp get_offsets(login, curr_offset) do
    {curr_offset, user_params} =
      [login.hostname, login.username, login.password, login.app_name, login.servername]
      |> Enum.reduce({curr_offset, <<>>}, fn elem, {offset, acc} ->
        {offset + byte_size(UCS2.from_string(elem)),
         acc <> <<offset::little-size(16)>> <> <<String.length(elem)::little-size(16)>>}
      end)

    ib_unused = <<0::size(16)>>
    cb_unused = <<0::size(16)>>

    ib_clt_int_name = <<curr_offset::little-size(16)>>
    cch_clt_int_name = <<4::little-size(16)>>
    curr_offset = curr_offset + 4 * 2

    ib_language = <<0::size(16)>>
    cch_language = <<0::size(16)>>

    ib_database = <<curr_offset::little-size(16)>>

    cch_database =
      if login.database == "" do
        <<0xAC>>
      else
        <<String.length(login.database)::little-size(16)>>
      end

    client_id = <<0::size(48)>>

    ib_sspi = <<0::size(16)>>
    cb_sspi = <<0::size(16)>>

    ib_atch_db_file = <<0::size(16)>>
    cch_atch_db_file = <<0::size(16)>>

    ib_change_password = <<0::size(16)>>
    cch_change_password = <<0::size(16)>>

    cb_sspi_long = <<0::size(32)>>

    user_params <>
      ib_unused <>
      cb_unused <>
      ib_clt_int_name <>
      cch_clt_int_name <>
      ib_language <>
      cch_language <>
      ib_database <>
      cch_database <>
      client_id <>
      ib_sspi <>
      cb_sspi <>
      ib_atch_db_file <>
      cch_atch_db_file <>
      ib_change_password <>
      cch_change_password <>
      cb_sspi_long
  end

  defp encode_tds_password(list) do
    for <<b::4, a::4 <- list>> do
      <<c>> = <<a::size(4), b::size(4)>>
      Bitwise.bxor(c, 0xA5)
    end
    |> Enum.map_join(&<<&1>>)
  end

  defp default_app_name, do: "Elixir TDS"
end
