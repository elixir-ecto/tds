defmodule LostConnectionTest do
  use ExUnit.Case, async: true

  alias Tds.Protocol

  @moduletag :capture_log

  # The answer to a request: one packet, end of message, holding a DONE token.
  @done <<0x04, 0x01, 21::16, 0::16, 1, 0, 0xFD, 0::little-16, 0::little-16, 0::little-64>>

  setup do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(listen)

    {:ok, sock} =
      :gen_tcp.connect({127, 0, 0, 1}, port, packet: :raw, mode: :binary, active: false)

    {:ok, server} = :gen_tcp.accept(listen)
    state = %Protocol{sock: {:gen_tcp, sock}, opts: []}

    {:ok, state: state, sock: sock, server: server}
  end

  describe "a request that cannot be sent" do
    setup %{sock: sock} do
      :ok = :gen_tcp.close(sock)
    end

    test "handle_prepare disconnects", %{state: state} do
      query = %Tds.Query{statement: "SELECT 1"}

      assert {:disconnect, %Tds.Error{message: message}, %Protocol{}} =
               Protocol.handle_prepare(query, [parameters: []], state)

      assert message =~ "failed to send"
    end

    test "handle_execute disconnects", %{state: state} do
      query = %Tds.Query{statement: "SELECT 1"}

      assert {:disconnect, %Tds.Error{}, %Protocol{}} =
               Protocol.handle_execute(query, [], [], state)
    end

    test "handle_execute with parameters disconnects", %{state: state} do
      query = %Tds.Query{statement: "SELECT @1"}
      params = [%Tds.Parameter{name: "@1", value: 1}]

      assert {:disconnect, %Tds.Error{}, %Protocol{}} =
               Protocol.handle_execute(query, params, [], state)
    end

    test "handle_close disconnects", %{state: state} do
      query = %Tds.Query{statement: "SELECT 1", handle: 1}

      assert {:disconnect, %Tds.Error{}, %Protocol{}} =
               Protocol.handle_close(query, [], state)
    end

    test "handle_begin, handle_commit and handle_rollback disconnect", %{state: state} do
      assert {:disconnect, %Tds.Error{}, %Protocol{}} = Protocol.handle_begin([], state)

      started = %{state | transaction: :started}
      assert {:disconnect, %Tds.Error{}, %Protocol{}} = Protocol.handle_commit([], started)
      assert {:disconnect, %Tds.Error{}, %Protocol{}} = Protocol.handle_rollback([], started)
    end

    test "ping disconnects with the error of the send", %{state: state} do
      assert {:disconnect, %Tds.Error{message: message}, %Protocol{}} = Protocol.ping(state)
      assert message =~ "failed to send"
    end

    test "disconnect closes the connection", %{state: state} do
      assert {:disconnect, error, state} = Protocol.ping(state)
      assert :ok = Protocol.disconnect(error, state)
    end
  end

  describe "a connection lost before the answer" do
    setup %{server: server} do
      # The server takes the request and is gone without answering it.
      Task.async(fn ->
        {:ok, _request} = :gen_tcp.recv(server, 0)
        :ok = :gen_tcp.close(server)
      end)

      :ok
    end

    test "handle_prepare disconnects", %{state: state} do
      query = %Tds.Query{statement: "SELECT 1"}

      assert {:disconnect, %Tds.Error{}, %Protocol{}} =
               Protocol.handle_prepare(query, [parameters: []], state)
    end

    test "handle_begin disconnects", %{state: state} do
      assert {:disconnect, %Tds.Error{}, %Protocol{}} = Protocol.handle_begin([], state)
    end
  end

  describe "a connection lost while unpreparing the statement" do
    test "handle_execute disconnects", %{state: state, server: server} do
      # The server answers the execution and is then gone.
      task =
        Task.async(fn ->
          {:ok, _request} = :gen_tcp.recv(server, 0)
          :ok = :gen_tcp.send(server, @done)
          :ok = :gen_tcp.close(server)
        end)

      query = %Tds.Query{statement: "SELECT 1", handle: 1}

      assert {:disconnect, _error, %Protocol{}} = Protocol.handle_execute(query, [], [], state)

      Task.await(task)
    end
  end
end
