defmodule LoginTest do
  use ExUnit.Case, async: true
  alias Tds.Connection, as: Conn

  test "Login with sql server authentication" do
    opts = [
      hostname: "sqlserver.local",
      username: "mssql",
      password: "mssql",
      database: "test"
    ]

    assert {:ok, pid} = Conn.start_link(opts)
    assert :ok = Conn.stop(pid)

  end
end
