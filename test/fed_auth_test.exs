defmodule Tds.FedAuthTest do
  @moduledoc """
  Opt-in integration test for federated authentication (Security Token
  library) against an Azure SQL Database.

  This test is tagged `:manual` (excluded by default). To run it, set
  `SQL_ACCESS_TOKEN` and `SQL_HOSTNAME` to an Azure SQL server and run:

      SQL_ACCESS_TOKEN=... SQL_HOSTNAME=myserver.database.windows.net \
        mix test test/fed_auth_test.exs --only manual

  The access token can be obtained, for example, with a client credentials
  flow against `https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token`
  using the scope `https://database.windows.net/.default`.
  """

  use ExUnit.Case, async: false

  @moduletag :manual

  test "connects using an access token (Security Token library)" do
    token = System.get_env("SQL_ACCESS_TOKEN")

    if is_nil(token) do
      flunk("Set SQL_ACCESS_TOKEN and SQL_HOSTNAME to run this test")
    end

    opts = [
      hostname: System.get_env("SQL_HOSTNAME") || "127.0.0.1",
      database: System.get_env("SQL_DATABASE") || "test",
      access_token: token,
      ssl: :required,
      ssl_opts: [verify: :verify_none],
      show_sensitive_data_on_connection_error: true
    ]

    assert {:ok, pid} = Tds.start_link(opts)

    assert {:ok, %Tds.Result{rows: [["pong"]]}} =
             Tds.query(pid, "SELECT 'pong' as [msg]", [])
  end
end
