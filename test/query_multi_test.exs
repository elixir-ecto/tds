defmodule QueryMultiTest do
  import Tds.TestHelper
  require Logger
  use ExUnit.Case, async: true

  @tag timeout: 50000

  setup do
    opts = Application.fetch_env!(:tds, :opts)
    {:ok, pid} = Tds.start_link(opts)

    {:ok, [pid: pid]}
  end

  test "should return resultset even if single batch is in sql statement",
       context do
    assert [%Tds.Result{rows: [[1]]}] = query_multi("select 1 as col_name")
  end

  test "should return resultset and and reset back to single result", context do
    assert [%Tds.Result{rows: [[1]]}, %Tds.Result{rows: [[2]]}] =
             query_multi("select 1 as r1c1; select 2 as r2c1;")

    assert [[1]] = query("select 1 as c1")
  end

  test "should execute multiple batches", context do
    assert :ok =
             query("""
             create table #temp_multi (
               id int identity(1,1) primary key,
               txt nvarchar(200)
             )
             """)

    assert [
             %Tds.Result{columns: nil, num_rows: 4, rows: nil},
             %Tds.Result{columns: ["inserted"], num_rows: 1, rows: [[4]]},
             %Tds.Result{columns: ["id"], num_rows: 2, rows: [[1], [3]]},
             %Tds.Result{columns: ["id"], num_rows: 2, rows: [[2], [4]]},
             %Tds.Result{columns: nil, num_rows: 4, rows: nil}
           ] =
             query_multi("""
             insert into #temp_multi values ('a1'), ('b1'), ('a2'), ('b2')

             select @@ROWCOUNT as [inserted]

             select id from #temp_multi where txt like 'a%'

             select id from #temp_multi where txt like 'b%'

             insert into #temp_multi values ('a1'), ('b1'), ('a2'), ('b2')
             """)
  end

  test "should report error like any other function e.g. Tds.query/4", context do
    # below is used macro, actual result is {:error, %Tds.Error{}} =...
    assert %Tds.Error{} = query_multi("select * from non_existing_table")
  end
end
