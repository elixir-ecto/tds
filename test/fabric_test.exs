Code.require_file("support/fake_tds_server.exs", __DIR__)

defmodule FabricTest do
  # Microsoft Fabric warehouses answer PRELOGIN with ENCRYPT_REQ and an INSTOPT
  # option, and their gateway routes the login to a `host\instance` backend.
  use ExUnit.Case, async: false

  alias Tds.Encoding.UCS2
  alias Tds.FakeServer
  alias Tds.Protocol.Prelogin

  @moduletag :capture_log

  # PRELOGIN response captured from a Fabric warehouse: VERSION, ENCRYPTION
  # (ENCRYPT_REQ), INSTOPT (0x00, instance matches), MARS and FEDAUTHREQUIRED
  @fabric_prelogin Base.decode16!(
                     "00001A00060100200001020021000104002200010600230001FF0C001788000003000001"
                   )

  defp tls_opts(port) do
    [
      hostname: "127.0.0.1",
      port: port,
      username: "u",
      password: "p",
      ssl: true,
      ssl_opts: [verify: :verify_none]
    ]
  end

  # PRELOGIN options as [{token, data}], terminator excluded
  defp prelogin_options(data), do: prelogin_options(data, data)

  defp prelogin_options(<<0xFF, _::binary>>, _data), do: []

  defp prelogin_options(<<token, offset::16, length::16, rest::binary>>, data),
    do: [{token, binary_part(data, offset, length)} | prelogin_options(rest, data)]

  # LOGIN7 ServerName: its offset and length (in characters) follow the fixed
  # 36 bytes and the HostName, UserName, Password and AppName pairs
  defp login7_server_name(login7) do
    <<_::binary-52, offset::little-16, length::little-16, _::binary>> = login7
    login7 |> binary_part(offset, length * 2) |> UCS2.to_string()
  end

  describe "PRELOGIN response" do
    test "a server that requires encryption gets a TLS connection" do
      {_server, port} = FakeServer.start(tls: true, prelogin_reply: @fabric_prelogin)

      assert {:ok, _state} = Tds.Protocol.connect(tls_opts(port))
    end

    test "INSTOPT is read as the instance check, not as the encryption level" do
      s = %Tds.Protocol{opts: [ssl: true]}

      # ENCRYPTION ON, then INSTOPT 0x00 (instance matches)
      matching = <<0x01, 11::16, 1::16, 0x02, 12::16, 1::16, 0xFF, 0x01, 0x00>>
      assert {:encrypt, _} = Prelogin.decode(matching, s)

      # INSTOPT 0x01: the server is not the instance the client asked for
      other = <<0x01, 11::16, 1::16, 0x02, 12::16, 1::16, 0xFF, 0x01, 0x01>>

      assert {:disconnect, %Tds.Error{message: "Connection terminated" <> _}, _} =
               Prelogin.decode(other, s)
    end

    test "a server that requires encryption is refused when the client turned it off" do
      s = %Tds.Protocol{opts: [ssl: false]}

      assert {:disconnect, %Tds.Error{message: "Server does not allow" <> _}, _} =
               Prelogin.decode(@fabric_prelogin, s)
    end
  end

  describe "PRELOGIN request" do
    test "carries a TRACEID with new connection and activity ids for every connection" do
      encode = fn ->
        <<_header::binary-8, data::binary>> =
          [ssl: true] |> Prelogin.encode() |> IO.iodata_to_binary()

        data |> prelogin_options() |> List.keyfind(0x05, 0)
      end

      assert {0x05, <<conn_id::binary-16, activity_id::binary-16, 0::32>>} = encode.()
      assert {0x05, <<other_conn_id::binary-16, other_activity_id::binary-16, 0::32>>} = encode.()
      assert conn_id != other_conn_id
      assert activity_id != other_activity_id
    end
  end

  describe "gateway redirect" do
    test "the routed LOGIN7 names the routed instance as ServerName" do
      {_target, target_port} = FakeServer.start(tls: true)

      {_gateway, gateway_port} =
        FakeServer.start(tls: true, redirect: target_port, route_instance: "TRKYbackend")

      assert {:ok, _state} = Tds.Protocol.connect(tls_opts(gateway_port))

      assert_received {:login7, gateway_login7}
      assert_received {:login7, routed_login7}
      assert login7_server_name(gateway_login7) == "127.0.0.1"
      assert login7_server_name(routed_login7) == "127.0.0.1\\TRKYbackend"
    end

    test "a route without an instance keeps the host as ServerName" do
      {_target, target_port} = FakeServer.start(tls: true)
      {_gateway, gateway_port} = FakeServer.start(tls: true, redirect: target_port)

      assert {:ok, _state} = Tds.Protocol.connect(tls_opts(gateway_port))

      assert_received {:login7, _gateway_login7}
      assert_received {:login7, routed_login7}
      assert login7_server_name(routed_login7) == "127.0.0.1"
    end

    test "both legs send a TRACEID" do
      {_target, target_port} = FakeServer.start(tls: true)
      {_gateway, gateway_port} = FakeServer.start(tls: true, redirect: target_port)

      assert {:ok, _state} = Tds.Protocol.connect(tls_opts(gateway_port))

      for _leg <- 1..2 do
        assert_received {:prelogin, prelogin}
        assert {0x05, <<_::binary-36>>} = prelogin |> prelogin_options() |> List.keyfind(0x05, 0)
      end
    end
  end
end
