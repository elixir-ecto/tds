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
               inspect(
                 query(
                   """
                   SELECT [total] FROM hades_sealed_cfdis
                   WHERE id in (select max(id) from hades_sealed_cfdis)
                   """,
                   []
                 )
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
      -- interfering with SELECT statements.
      SET NOCOUNT ON;
    
        -- Insert statements for procedure here
      select id, name from dummy_tbl where id = @filterId
    END
    """
    query(create_table, [])
    query(create_procedure, [])
    assert [[1, "Elixir"]] == query(
      "exec RetrieveDummyValues @filterId",
      [
        %Tds.Parameter{name: "@filterId", value: 1}
      ])
    query("""
    IF EXISTS(SELECT * FROM sys.objects where name ='RetrieveDummyValues' and type ='P') DROP PROCEDURE [dbo].[RetrieveDummyValues];
    IF OBJECT_ID('[dbo].[dummy_tbl]', 'U') IS NOT NULL DROP TABLE [dbo].[dummy_tbl];
    """, [])
  end
end
