defmodule TdsIssuesTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  @tag timeout: 50_000

  setup do
    {:ok, pid} = Tds.start_link(opts())

    {:ok, [pid: pid]}
  end

  @tag :float
  test "float read and write", context do
    query("DROP TABLE [float_tests]", [])

    :ok =
      query(
        """
          CREATE TABLE [float_tests] (
            [id] int NOT NULL identity(1,1) primary key,
            [float_value] float
          )
        """,
        []
      )

    test_vals = [
      {-1234.1234, <<78, 209, 145, 92, 126, 72, 147, 192>>},
      {-1234.0, <<0, 0, 0, 0, 0, 72, 147, 192>>},
      {-1.0, <<0, 0, 0, 0, 0, 0, 240, 191>>},
      {-0.5, <<0, 0, 0, 0, 0, 0, 224, 191>>},
      {-0.3333333333333333, <<85, 85, 85, 85, 85, 85, 213, 191>>},
      {-0.25, <<0, 0, 0, 0, 0, 0, 208, 191>>},
      {-0.2, <<154, 153, 153, 153, 153, 153, 201, 191>>},
      {0.0, <<0, 0, 0, 0, 0, 0, 0, 0>>},
      {0.0, <<0, 0, 0, 0, 0, 0, 0, 0>>},
      {0.2, <<154, 153, 153, 153, 153, 153, 201, 63>>},
      {0.25, <<0, 0, 0, 0, 0, 0, 208, 63>>},
      {0.3333333333333333, <<85, 85, 85, 85, 85, 85, 213, 63>>},
      {0.5, <<0, 0, 0, 0, 0, 0, 224, 63>>},
      {1.0, <<0, 0, 0, 0, 0, 0, 240, 63>>},
      {1234.0, <<0, 0, 0, 0, 0, 72, 147, 64>>},
      {1234.1234, <<78, 209, 145, 92, 126, 72, 147, 64>>}
    ]

    Enum.each(test_vals, fn {val, _} ->
      :ok = query("INSERT INTO [float_tests] values (#{val})", [])
    end)

    values = Enum.map(test_vals, fn {val, _} -> [val] end)
    assert values == query("SELECT float_value FROM [float_tests]", [])

    Enum.each(values, fn [val] ->
      assert [[val]] == query("SELECT cast(#{val} as float)", [])
    end)

    query("DROP TABLE [float_tests]", [])
  end

  @tag :float
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
               query(
                 """
                 SELECT [total] FROM hades_sealed_cfdis
                 WHERE id in (select max(id) from hades_sealed_cfdis)
                 """,
                 []
               )
    end

    1..17
    |> Enum.flat_map(&[1 / &1, -1 / &1])
    |> Enum.each(f)

    query("DROP TABLE hades_sealed_cfdis", [])
  end

  test "testing stored procedure execution", context do
    create_table = """
    IF EXISTS(SELECT * FROM sys.objects where name ='RetrieveDummyValues' and type ='P') DROP PROCEDURE [dbo].[RetrieveDummyValues];
    IF OBJECT_ID('[dbo].[dummy_tbl]', 'U') IS NOT NULL DROP TABLE [dbo].[dummy_tbl];
    CREATE TABLE [dbo].[dummy_tbl](
      [id] [int] NOT NULL PRIMARY KEY,
      [name] [nvarchar] (52) NOT NULL
    );
    INSERT INTO [dbo].[dummy_tbl]
    VALUES
    (1, 'Elixir'), (2, 'Elm'), (3, 'Sql');
    """

    create_procedure = """
    CREATE PROCEDURE RetrieveDummyValues
      -- Add the parameters for the stored procedure here
      @filterId INT
    AS
    BEGIN
      -- SET NOCOUNT ON added to prevent extra result sets from
      -- interfering with SELECT statements. This is NOT REQURED anymore
      -- rows are counted by message parser until done token appears
      -- SET NOCOUNT ON;

        -- Insert statements for procedure here
      select id, name from dummy_tbl where id = @filterId
    END
    """

    query(create_table, [])
    query(create_procedure, [])

    assert [[1, "Elixir"]] ==
             query("exec RetrieveDummyValues @filterId", [
               %Tds.Parameter{name: "@filterId", value: 1}
             ])

    query(
      """
      IF EXISTS(SELECT * FROM sys.objects where name ='RetrieveDummyValues' and type ='P') DROP PROCEDURE [dbo].[RetrieveDummyValues];
      IF OBJECT_ID('[dbo].[dummy_tbl]', 'U') IS NOT NULL DROP TABLE [dbo].[dummy_tbl];
      """,
      []
    )
  end

  test "should return first error from token stream then auto log the rest of errors", context do
    query("DROP TABLE test_collation1", [])

    query(
      """
      CREATE TABLE test_collation1 (id int NOT NULL identity(1,1) PRIMARY KEY, txt ntext NOT NULL )
      """,
      []
    )

    query(
      """
      INSERT INTO test_collation1 values
        ('missing collation decoder'),
        ('2missing collation decoder')
      """,
      []
    )

    fun = fn ->
      assert %Tds.Error{
               message: _,
               mssql: %{
                 class: 16,
                 line_number: 1,
                 msg_text: "Invalid column name 'b'.",
                 number: 207,
                 proc_name: _,
                 server_name: _,
                 state: 1
               }
             } =
               query(
                 """
                 SELECT TOP (1000) [id] ,[txt], [b]
                 FROM [test].[dbo].[test_collation1]
                 """,
                 []
               )
    end

    # this should be error returned to as result of query execution
    assert not (capture_log(fun) =~ "Invalid column name 'b'")
    # this should be logged in console
    assert capture_log(fun) =~ "Statement(s) could not be prepared"
  end

  test "should interprete correctly colmetadata type_info for text columns", context do
    query("DROP TABLE test_collation", [])

    query(
      """
      CREATE TABLE test_collation (id int NOT NULL identity(1,1) PRIMARY KEY, txt ntext NOT NULL )
      """,
      []
    )

    query(
      """
      INSERT INTO test_collation values
        ('missing collation decoder'),
        ('2missing collation decoder')
      """,
      []
    )

    assert 2 =
             query(
               """
               SELECT TOP (1000) [id] ,[txt]
               FROM [test].[dbo].[test_collation]
               """,
               []
             )
             |> length()
  end
end
