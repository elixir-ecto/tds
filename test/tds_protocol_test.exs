defmodule TdsProtocolTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  @tag timeout: 50_000
  @moduletag :capture_log

  setup do
    opts = opts()
    {:ok, state} = Tds.Protocol.connect(opts)
    {:ok, [state: state]}
  end

  describe "given query execution mode" do
    test "handle_prepare should call sp_prepare", %{state: state} do
      assert state != nil
      assert state.opts[:execution_mode] == nil

      query = %Tds.Query{
        statement: "SELECT @1 as column1",
        handle: nil
      }

      params = [%Tds.Parameter{name: "@1", value: "test"}]

      {:ok, query, state} = Tds.Protocol.handle_prepare(query, [parameters: params], state)
      assert state.state == :executing
      # this is assigned by sql server to output parameter of sp_prepare
      assert query.handle > 0

      assert :ok == Tds.Protocol.disconnect("test", state)
    end

    test "handle_prepare should call sp_executesql", %{state: state} do
      assert state != nil
      assert state.opts[:execution_mode] == nil

      query = %Tds.Query{
        statement: "SELECT @1 as column1",
        handle: nil
      }

      params = [%Tds.Parameter{name: "@1", value: "test"}]

      {:ok, query, state} =
        Tds.Protocol.handle_prepare(
          query,
          [parameters: params, execution_mode: :executesql],
          state
        )

      assert state.state == :executing
      # in this case, sp_executesql does not return a handle so it should be nil
      assert query.handle == nil

      assert :ok == Tds.Protocol.disconnect("test", state)
    end
  end
end
