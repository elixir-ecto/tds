defmodule TdsIssuesTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  @tag timeout: 50000

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    {:ok, pid} = Tds.start_link(opts)

    {:ok, [pid: pid]}
  end

  @tag :manual
  test "issue 33: Sending Float with more than 9 characters should not fail",
       context do
    query("DROP TABLE hades_sealed_cfdis", [])

    query(
      """
      CREATE TABLE hades_sealed_cfdis(
        [id] int identity(1,1) not null primary key,
        [total] float(53),
        [inserted_at] datetime,
        [updated_at] datetime
      )
      """,
      []
    )

    f = fn val ->
      res =
        query(
          """
          INSERT INTO hades_sealed_cfdis ([total] ,[inserted_at], [updated_at])
          VALUES (@1,@2,@3)
          """,
          [
            %Tds.Parameter{name: "@1", value: val, type: :float},
            %Tds.Parameter{
              name: "@2",
              value: {{2016, 12, 20}, {23, 59, 23, 0}}
            },
            %Tds.Parameter{name: "@3", value: {{2016, 12, 20}, {23, 59, 23, 0}}}
          ]
        )

      assert :ok == res

      assert [[val]] ==
               IO.inspect(
                 query(
                   """
                   SELECT [total] FROM hades_sealed_cfdis
                   WHERE id in (select max(id) from hades_sealed_cfdis)
                   """,
                   []
                 )
               )
    end

    Enum.flat_map(1..17, &[1 / &1, -1 / &1])
    |> Enum.each(f)

    query("DROP TABLE hades_sealed_cfdis", [])
  end
end
