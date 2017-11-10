defmodule TvpTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true
  alias Tds.Parameter

  @tag timeout: 50000

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    {:ok, pid} = Tds.start_link(opts)

    {:ok, [pid: pid]}
  end

  test "TVP in stored proc", context do
    assert :ok = query("BEGIN TRY DROP PROCEDURE __tvpTest DROP TYPE TvpTestType END TRY BEGIN CATCH END CATCH", [])
    assert :ok = query("""
      CREATE TYPE TvpTestType AS TABLE (
        d int
      );
    """, [])
    assert :ok = query("""
    CREATE PROCEDURE __tvpTest (@tvp TvpTestType readonly)
      AS BEGIN
        select * from @tvp
      END
    """, [])

    params = [
      %Parameter{name: "@tvp", value: %{name: "TvpTestType", columns: [%Parameter{name: "d", type: :integer, value: nil}], rows: [[1]]}, type: :tvp}
    ]

    assert [[1]] = proc("__tvpTest", params)
  end
end
