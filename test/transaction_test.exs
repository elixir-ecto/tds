defmodule Tds.TransactionTest do
  use ExUnit.Case, async: true
  # import ExUnit.CaptureLog
  import Tds.TestHelper

  setup context do
    transactions =
      case context[:mode] do
        :transaction -> :strict
        :savepoint -> :naive
      end

    opts = [
      transactions: transactions,
      isolation_level: :snapshot,
      idle: :active,
      backoff_type: :stop,
      prepare: context[:prepare] || :named
    ]

    opts =
      Application.get_env(:tds, :opts)
      |> Keyword.merge(opts)

    {:ok, pid} = Tds.start_link(opts)
    {:ok, pid2} = Tds.start_link(opts)
    {:ok, [pid: pid, pid2: pid2]}
  end

  @tag mode: :transaction
  @tag :transaction
  test "connection works after failure during commit transaction", context do
    assert transaction(fn conn ->
             assert {:error, %Tds.Error{mssql: %{class: 14, number: 2627}}} =
                      Tds.query(
                        conn,
                        "insert into uniques values (1), (1);",
                        []
                      )

             #  assert {:error, %Tds.Error{mssql: %{class: 16, number: 3971}}} =
             assert {:ok, %Tds.Result{columns: [""], num_rows: 1, rows: ['*']}} =
                      Tds.query(conn, "SELECT 42", [])

             :hi
           end) == {:error, :rollback}

    assert [[42]] = query("SELECT 42", [])
    assert [[0]] = query("SELECT COUNT(*) FROM uniques", [])
  end

  @tag mode: :transaction
  @tag :transaction
  test "connection works after failure during rollback transaction", context do
    assert transaction(fn conn ->
             Tds.query(conn, "insert into uniques values (1), (2);", [])

             assert {:error, %Tds.Error{mssql: %{class: 14, number: 2627}}} =
                      Tds.query(
                        conn,
                        "insert into uniques values (3), (3);",
                        []
                      )

             #  assert {:error, %Tds.Error{mssql: %{class: 16, number: 3971}}} =
             assert {:ok, %Tds.Result{columns: [""], num_rows: 1, rows: ['*']}} =
                      Tds.query(conn, "SELECT 42", [])

             Tds.rollback(conn, :oops)
           end) == {:error, :oops}

    assert [[42]] = query("SELECT 42", [])
  end

  @tag mode: :transaction
  @tag :transaction
  @tag :transaction_status
  test "transaction shows correct transaction status", context do
    pid = context[:pid]
    opts = [mode: :transaction]

    assert DBConnection.status(pid, opts) == :idle
    assert query("SELECT 42", []) == [[42]]
    assert DBConnection.status(pid, opts) == :idle

    assert DBConnection.transaction(
             pid,
             fn conn ->
               assert DBConnection.status(conn, opts) == :transaction

               assert {:error, %Tds.Error{mssql: %{class: 14, number: 2627}}} =
                        Tds.query(
                          conn,
                          "insert into uniques values (1), (1);",
                          [],
                          opts
                        )

               assert DBConnection.status(conn, opts) == :error

               # assert {:error, %Tds.Error{mssql: %{class: 16, number: 3971}}} =
               assert {:ok, %Tds.Result{columns: [""], num_rows: 1, rows: ['*']}} =
                        Tds.query(conn, "SELECT 42", [], opts)

               assert DBConnection.status(conn, opts) == :error
             end,
             opts
           ) == {:error, :rollback}

    assert DBConnection.status(pid, opts) == :idle
    assert query("SELECT 42", []) == [[42]]
    assert DBConnection.status(pid) == :idle
  end

  @tag mode: :transaction
  @tag :transaction
  test "should set transaction isolation level", context do
    :ok = query("CREATE TABLE TranIsolation (num INT)", [])

    #    opts = Application.get_env(:tds, :opts)
    #    {:ok, conn} = Tds.start_link(opts)
    #    {:ok, conn2} = Tds.start_link(opts)
    conn = context[:pid]
    conn2 = context[:pid2]

    pid = self()

    new_pid =
      spawn_link(fn ->
        Tds.transaction(
          conn2,
          fn conn2 ->
            Tds.query!(conn2, "insert into TranIsolation values (1)", [])
            assert %{rows: [[1]]} = Tds.query!(conn2, "select num from TranIsolation", [])
            send(pid, :in_transaction)

            receive do
              :commit -> :ok
            after
              5000 -> raise "timout"
            end
          end,
          isolation_level: :snapshot
        )

        send(pid, :committed)
      end)

    receive do
      :in_transaction -> :ok
    after
      5000 -> raise "timeout"
    end

    assert {:ok, %{rows: []}} =
             Tds.transaction(
               conn,
               fn conn ->
                 assert %{rows: []} = Tds.query!(conn, "select num from TranIsolation", [])
               end,
               isolation_level: :snapshot
             )

    send(new_pid, :commit)

    receive do
      :committed -> :ok
    after
      5000 -> raise "timeout"
    end

    assert %{rows: [[1]]} = Tds.query!(conn, "select num from TranIsolation", [])
  end
end
