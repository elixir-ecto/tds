Code.require_file("support/fake_tds_server.exs", __DIR__)

defmodule MaxResponseBytesTest do
  use ExUnit.Case, async: true

  alias Tds.FakeServer

  @query %Tds.Query{statement: "SELECT 1"}

  defp connect(script, opts) do
    {_server, port} = FakeServer.start(script: script)

    Tds.Protocol.connect(
      [hostname: "127.0.0.1", port: port, username: "u", password: "p", ssl: false] ++ opts
    )
  end

  defp junk, do: FakeServer.packet(0, <<0::size(4000)-unit(8)>>)

  test "a response under the limit decodes normally" do
    <<first::binary-5, rest::binary>> = FakeServer.done()
    script = [{:reply, [FakeServer.packet(0, first), FakeServer.packet(1, rest)]}]
    {:ok, s} = connect(script, max_response_bytes: 100)

    assert {:ok, _query, %Tds.Result{num_rows: 5}, _s} =
             Tds.Protocol.handle_execute(@query, [], [], s)
  end

  test "without the option a large response is read in full" do
    {:ok, s} = connect([{:reply, [junk(), junk(), FakeServer.packet(1, FakeServer.done())]}], [])

    # the padding is not a valid token stream, so decoding fails once it
    # has all been buffered
    assert {:error, %RuntimeError{message: "Unsupported Token code" <> _}, _s} =
             Tds.Protocol.handle_execute(@query, [], [], s)
  end

  test "a response over the limit stops reading and closes the connection" do
    script = [{:reply, [junk(), junk(), junk(), FakeServer.packet(1, FakeServer.done())]}]
    {:ok, s} = connect(script, max_response_bytes: 6_000)

    assert {:disconnect,
            %Tds.ResponseTooLargeError{
              limit: 6_000,
              received: received,
              message: "response exceeded max_response_bytes (limit 6000 bytes)"
            }, _s} = Tds.Protocol.handle_execute(@query, [], [], s)

    assert received > 6_000
    {:gen_tcp, sock} = s.sock
    assert {:error, _closed} = :inet.peername(sock)
    assert_receive {:server_done, {:error, :closed}}
  end

  test "the limit does not apply to PRELOGIN, LOGIN7 or the connection SET batch" do
    # every login response is longer than 10 bytes
    {:ok, s} =
      connect([{:reply, [FakeServer.packet(1, FakeServer.done())]}], max_response_bytes: 10)

    assert {:disconnect, %Tds.ResponseTooLargeError{limit: 10}, _s} =
             Tds.Protocol.handle_execute(@query, [], [], s)
  end

  describe "Tds.start_link/1" do
    test "rejects anything but a positive integer or nil" do
      for value <- [0, -1, 1.5, "10", :infinity] do
        assert_raise ArgumentError, ~r/max_response_bytes/, fn ->
          Tds.start_link(max_response_bytes: value)
        end
      end
    end

    @tag :capture_log
    test "accepts nil" do
      {_server, port} = FakeServer.start(script: [])

      assert {:ok, _pool} =
               Tds.start_link(
                 hostname: "127.0.0.1",
                 port: port,
                 username: "u",
                 password: "p",
                 ssl: false,
                 max_response_bytes: nil,
                 backoff_type: :stop,
                 pool_size: 1
               )
    end
  end

  describe "through Tds.query/3" do
    defp start_pool(script) do
      {_server, port} = FakeServer.start(script: script)

      {:ok, pid} =
        Tds.start_link(
          hostname: "127.0.0.1",
          port: port,
          username: "u",
          password: "p",
          ssl: false,
          execution_mode: :executesql,
          max_response_bytes: 6_000,
          backoff_type: :stop,
          pool_size: 1
        )

      pid
    end

    @tag :capture_log
    test "a response under the limit returns the result" do
      pid = start_pool([{:reply, [FakeServer.packet(1, FakeServer.done())]}])

      assert {:ok, %Tds.Result{num_rows: 5}} = Tds.query(pid, "SELECT 1", [])
    end

    @tag :capture_log
    test "a response over the limit returns ResponseTooLargeError and closes the connection" do
      pid =
        start_pool([{:reply, [junk(), junk(), junk(), FakeServer.packet(1, FakeServer.done())]}])

      assert {:error,
              %Tds.ResponseTooLargeError{
                limit: 6_000,
                received: received,
                message: "response exceeded max_response_bytes (limit 6000 bytes)"
              }} = Tds.query(pid, "SELECT 1", [])

      assert received > 6_000
      assert_receive {:server_done, {:error, :closed}}
    end
  end
end
