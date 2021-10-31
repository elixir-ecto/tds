defmodule SSLTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Tds.TestHelper

  describe "test ssl connection" do
    setup do
      opts = Keyword.put(opts(), :ssl, :required)

      {:ok, pid} = Tds.start_link(opts)
      {:ok, [pid: pid]}
    end

    test "open new ssl connection to database", context do
      assert ["TRUE"] ==
               query("SELECT encrypt_option FROM sys.dm_exec_connections") |> List.last()
    end
  end

  describe "test non-ssl connect" do
    setup do
      opts = Keyword.put(opts(), :ssl, :not_supported)

      {:ok, pid} = Tds.start_link(opts)
      {:ok, [pid: pid]}
    end

    test "open new ssl connection to database", context do
      assert ["FALSE"] ==
               query("SELECT encrypt_option FROM sys.dm_exec_connections") |> List.last()
    end
  end
end
