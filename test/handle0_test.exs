defmodule Handle0Test do
  use ExUnit.Case, async: true

  import Tds.TestHelper

  alias Tds

  @tag timeout: 50000
  @table "foo"

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    {:ok, pid} = Tds.start_link(opts)

    {:ok, [pid: pid]}
  end

  test "Could not find prepared statement with handle 0.",
       %{pid: pid} = context do
    query("DROP TABLE #{@table}", [])

    query(
      """
      CREATE TABLE #{@table}(
        [id] int identity(1,1) not null primary key
      )
      """,
      []
    )

    n = 300

    for _ <- 1..n do
      result =
        Tds.query(pid, "SELECT * FROM #{@table} WHERE id = @id", [
          %Tds.Parameter{name: "@id", value: "7", type: :int}
        ])

      assert {:ok, _} = result
    end

    query("DROP TABLE #{@table}", [])
  end
end
