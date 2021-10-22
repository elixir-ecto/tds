defmodule SSLTest do
  @moduledoc false
  use ExUnit.Case, async: false

  import Tds.TestHelper

  describe "test ssl connection" do
    setup do
      opts = Application.fetch_env!(:tds, :opts)
      opts = Keyword.put_new(opts, :ssl, true)

      {:ok, pid} = Tds.start_link(opts)
      {:ok, [pid: pid]}
    end

    test "open new ssl connection to database", context do
      assert [["TRUE"]] ==
               query("SELECT encrypt_option FROM sys.dm_exec_connections")
    end
  end

  describe "test non-ssl connect" do
    setup do
      opts = Application.fetch_env!(:tds, :opts)
      opts = Keyword.put_new(opts, :ssl, false)

      {:ok, pid} = Tds.start_link(opts)
      {:ok, [pid: pid]}
    end

    test "open new ssl connection to database", context do
      assert [["FALSE"]] ==
               query("SELECT encrypt_option FROM sys.dm_exec_connections")
    end
  end
end
