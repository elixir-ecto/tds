defmodule TvpTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true
  alias Tds.Parameter
  alias Tds.Column

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
        a int,
        b uniqueidentifier,
        c varchar(100),
        d varbinary(max)
      );
    """, [])

    assert :ok = query("""
    CREATE PROCEDURE __tvpTest (@tvp TvpTestType readonly)
      AS BEGIN
        select * from @tvp
      END
    """, [])

    rows = [1, <<158, 3, 157, 56, 133, 56, 73, 67, 128, 121, 126, 204, 115, 227, 162, 157>>, "foo", "{\"foo\":\"bar\",\"baz\":\"biz\"}"]
    params = [
      %Parameter{
        name: "@tvp",
        value: %{
          name: "TvpTestType",
          columns: [
            %Column{name: "a", type: :int},
            %Column{name: "b", type: :uuid},
            %Column{name: "c", type: :varchar},
            %Column{name: "d", type: :varbinary},
          ],
          rows: [rows]
        },
        type: :tvp
      }
    ]

    assert [^rows] = proc("__tvpTest", params)
  end
end
