defmodule Tds.TransactionTest do
  use ExUnit.Case, async: true
  # import ExUnit.CaptureLog
  import Tds.TestHelper

  setup context do
    transactions =
      case context[:mode] do
        :transaction -> :strict
        :savepoint   -> :naive
      end

    opts = [
      database: "test",
      username: "sa",
      password: "some!Password",
      transactions: transactions,
      idle: :active,
      backoff_type: :stop,
      prepare: context[:prepare] || :named
    ]
    {:ok, pid} = Tds.start_link(opts)
    {:ok, [pid: pid]}
  end

  @tag mode: :transaction
  test "connection works after failure during commit transaction", context do
    assert transaction(fn(conn) ->
      assert {:error, %Tds.Error{mssql: %{class: 14, number: 2627}}} =
        Tds.query(conn, "insert into uniques values (1), (1);", [])
      assert {:ok, %Tds.Result{columns: [""], num_rows: 1, rows: ['*']}} =
        Tds.query(conn, "SELECT 42", [])
      :hi
    end) == :hi
    assert [[42]] = query("SELECT 42", [])
  end

  @tag mode: :transaction
  test "connection works after failure during rollback transaction", context do
    assert transaction(fn(conn) ->
      assert {:error, %Tds.Error{mssql: %{class: 14, number: 2627}}} =
        Tds.query(conn, "insert into uniques values (1), (1);", [])
      assert {:ok, %Tds.Result{columns: [""], num_rows: 1, rows: ['*']}} =
        Tds.query(conn, "SELECT 42", [])
        Tds.rollback(conn, :oops)
    end) == {:error, :oops}
    assert [[42]] = query("SELECT 42", [])
  end

  # NOTE: Below case will not work in MSSQL server since it do not care about
  # nested transactions, it is allowed!!! But, DBConnection excpests this behaviour,
  # which is actual issue in MSSQL. What TDS library has to handle, is that
  # ROLLBACK or COMMIT is only sent once to MSSQL server, so this makes
  # that Tds will behave like this, instead, Tds library should allow only single

  # @tag mode: :transaction
  # test "query begin returns error", context do
  #   Process.flag(:trap_exit, true)

  #   capture_log fn ->
  #     assert (%Tds.Error{message: "unexpected mssql status: transaction"} = err) =
  #       query("BEGIN TRANSACTION", [])

  #     pid = context[:pid]
  #     assert_receive {:EXIT, ^pid, {:shutdown, ^err}}
  #   end
  # end

  # @tag mode: :transaction
  # test "idle status during transaction returns error and disconnects", context do
  #   Process.flag(:trap_exit, true)

  #   assert transaction(fn(conn) ->
  #     capture_log fn ->
  #       assert {:error, %Tds.Error{message: "unexpected mssql status: idle"} = err} =
  #         Tds.query(conn, "ROLLBACK TRANSACTION", [])

  #       pid = context[:pid]
  #       assert_receive {:EXIT, ^pid, {:shutdown, ^err}}
  #     end
  #     :hi
  #   end) == {:error, :rollback}
  # end

  # @tag mode: :transaction
  # test "checkout when in transaction disconnects", context do
  #   Process.flag(:trap_exit, true)

  #   pid = context[:pid]
  #   :sys.replace_state(pid,
  #     fn(%{mod_state: %{state: state} = mod} = conn) ->
  #       %{conn | mod_state: %{mod | state: %{state | transaction: :started}}}
  #     end)
  #   capture_log fn ->
  #     assert {{:shutdown,
  #         %Tds.Error{message: "unexpected tds status: transaction"} = err}, _} =
  #       catch_exit(query("SELECT 42", []))

  #     assert_receive {:EXIT, ^pid, {:shutdown, ^err}}
  #   end
  # end

  # @tag mode: :transaction
  # test "ping when transaction state mismatch disconnects" do
  #   Process.flag(:trap_exit, true)

  #   opts = [ database: "test", username: "sa", password: "some!Password",
  #            transactions: :strict, idle_timeout: 10, backoff_type: :stop ]
  #   {:ok, pid} = Tds.start_link(opts)

  #   capture_log fn ->
  #     :sys.replace_state(pid,
  #       fn(%{mod_state: %{state: state} = mod} = conn) ->
  #         %{conn | mod_state: %{mod | state: %{state | transaction: :started}}}
  #       end)
  #     assert_receive {:EXIT, ^pid, {:shutdown,
  #         %Tds.Error{message: "unexpected mssql status: transaction"}}}
  #   end
  # end

  # @tag mode: :transaction
  # @tag prepare: :unnamed
  # test "transaction commits with unnamed queries", context do
  #   assert transaction(fn(conn) ->
  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end) == {:ok, :hi}
  #   assert query("SELECT 42", []) == [[42]]
  # end

  # @tag mode: :transaction
  # @tag prepare: :unnamed
  # test "transaction rolls back with unnamed queries", context do
  #   assert transaction(fn(conn) ->
  #     Tds.rollback(conn, :oops)
  #   end) == {:error, :oops}
  #   assert query("SELECT 42", []) == [[42]]
  # end

  # @tag mode: :savepoint
  # test "savepoint transaction releases savepoint", context do
  #   :ok = query("BEGIN TRANSACTION", [])
  #   assert transaction(fn(conn) ->
  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end, [mode: :savepoint]) == {:ok, :hi}
  #   assert [[42]] = query("SELECT 42", [])
  #   # todo: set save point error codes
  #   assert %Tds.Error{mssql: %{.....}} =
  #     query("SAVE TRANSACTION mssql_savepoint", [])
  #   assert :ok = query("ROLLBACK TRANSACTION", [])
  # end

  # @tag mode: :savepoint
  # test "savepoint transaction rolls back to savepoint and releases", context do
  #   assert :ok = query("BEGIN TRANSACTION", [])
  #   assert transaction(fn(conn) ->
  #     # unique index violation
  #     assert {:error, %Tds.Error{mssql: %{class: 14, number: 2627}}} =
  #       Tds.query(conn, "insert into uniques values (1), (1);", [])
  #       Tds.rollback(conn, :oops)
  #   end, [mode: :savepoint]) == {:error, :oops}
  #   assert [[42]] = query("SELECT 42", [])
  #   # todo: set error code for invalid save point
  #   assert %Tds.Error{mssql: %{....}} =
  #     query("SAVE TRANSACTION mssql_savepoint", [])
  #   assert :ok = query("ROLLBACK TRANSACTION", [])
  # end

  # @tag mode: :savepoint
  # @tag prepare: :unnamed
  # test "savepoint transaction releases with unnamed queries", context do
  #   assert :ok = query("BEGIN TRANSACTION", [])
  #   assert transaction(fn(conn) ->
  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end, [mode: :savepoint]) == {:ok, :hi}
  #   assert [[42]] = query("SELECT 42", [])
  #   assert %Tds.Error{mssql: %{code: :invalid_savepoint_specification}} =
  #     query("RELEASE SAVEPOINT postgrex_savepoint", [])
  #   assert :ok = query("ROLLBACK TRANSACTION", [])
  # end

  # @tag mode: :savepoint
  # @tag prepare: :unnamed
  # test "savepoint transaction rolls back and releases with unnamed queries", context do
  #   assert :ok = query("BEGIN", [])
  #   assert transaction(fn(conn) ->
  #     Tds.rollback(conn, :oops)
  #   end, [mode: :savepoint]) == {:error, :oops}
  #   assert [[42]] = query("SELECT 42", [])
  #   assert %Tds.Error{mssql: %{code: :invalid_savepoint_specification}} =
  #     query("RELEASE SAVEPOINT postgrex_savepoint", [])
  #   assert :ok = query("ROLLBACK", [])
  # end

  # @tag mode: :savepoint
  # test "savepoint transaction rollbacks on failed", context do
  #   assert :ok = query("BEGIN", [])
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #       Tds.query(conn, "insert into uniques values (1), (1);", [], [])

  #     assert {:error, %Tds.Error{mssql: %{code: :in_failed_sql_transaction}}} =
  #       Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end, [mode: :savepoint]) == {:ok, :hi}
  #   assert [[42]] = query("SELECT 42", [])
  #   assert :ok = query("ROLLBACK", [])
  # end

  # @tag mode: :savepoint
  # @tag prepare: :unnamed
  # test "savepoint transaction rollbacks on failed with unnamed queries", context do
  #   assert :ok = query("BEGIN", [])
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #       Tds.query(conn, "insert into uniques values (1), (1);", [], [])
  #     :hi
  #   end, [mode: :savepoint]) == {:ok, :hi}
  #   assert [[42]] = query("SELECT 42", [])
  #   assert :ok = query("ROLLBACK", [])
  # end

  # @tag mode: :transaction
  # test "transaction works after failure in savepoint query parsing state", context do
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #     Tds.query(conn, "insert into uniques values (1), (1);", [], [mode: :savepoint])

  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end) == {:ok, :hi}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # test "savepoint query releases savepoint in transaction", context do
  #   assert transaction(fn(conn) ->
  #     assert {:ok, %Tds.Result{rows: [[42]]}} =
  #       Tds.query(conn, "SELECT 42", [], [mode: :savepoint])

  #     assert {:error, %Tds.Error{mssql: %{code: :invalid_savepoint_specification}}} =
  #       Tds.query(conn, "RELEASE SAVEPOINT postgrex_query", [])
  #     Tds.rollback(conn, :oops)
  #   end) == {:error, :oops}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # test "savepoint query does not rollback on savepoint error", context do
  #   assert transaction(fn(conn) ->
  #     assert {:ok, _} = Tds.query(conn, "SAVEPOINT postgrex_query", [])

  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #       Tds.query(conn, "INSERT INTO uniques VALUES (1), (1)", [])

  #     assert {:error, %Tds.Error{mssql: %{code: :in_failed_sql_transaction}}} =
  #       Tds.query(conn, "SELECT 42", [], [mode: :savepoint])

  #     assert {:error, %Tds.Error{mssql: %{code: :in_failed_sql_transaction}}} =
  #       Tds.query(conn, "SELECT 42", [])

  #     Tds.rollback(conn, :oops)
  #   end) == {:error, :oops}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # test "savepoint query handles release savepoint error", context do
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :invalid_savepoint_specification}}} =
  #       Tds.query(conn, "RELEASE SAVEPOINT postgrex_query", [], [mode: :savepoint])

  #     assert {:error, %Tds.Error{mssql: %{code: :in_failed_sql_transaction}}} =
  #       Tds.query(conn, "SELECT 42", [])
  #     Tds.rollback(conn, :oops)
  #   end) == {:error, :oops}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # test "savepoint query rolls back and releases savepoint in transaction", context do
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #       Tds.query(conn, "insert into uniques values (1), (1);", [], [mode: :savepoint])

  #     assert {:error, %Tds.Error{mssql: %{code: :invalid_savepoint_specification}}} =
  #       Tds.query(conn, "RELEASE SAVEPOINT postgrex_query", [])
  #     Tds.rollback(conn, :oops)
  #   end) == {:error, :oops}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # @tag prepare: :unnamed
  # test "unnamed savepoint query releases savepoint in transaction", context do
  #   assert transaction(fn(conn) ->
  #     assert {:ok, %Tds.Result{rows: [[42]]}} =
  #       Tds.query(conn, "SELECT 42", [], [mode: :savepoint])

  #     assert {:error, %Tds.Error{mssql: %{code: :invalid_savepoint_specification}}} =
  #       Tds.query(conn, "RELEASE SAVEPOINT postgrex_query", [])
  #     Tds.rollback(conn, :oops)
  #   end) == {:error, :oops}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # test "unnamed savepoint query rolls back and releases savepoint in transaction", context do
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #       Tds.query(conn, "insert into uniques values (1), (1);", [], [mode: :savepoint])

  #     assert {:error, %Tds.Error{mssql: %{code: :invalid_savepoint_specification}}} =
  #       Tds.query(conn, "RELEASE SAVEPOINT postgrex_query", [])
  #     Tds.rollback(conn, :oops)
  #   end) == {:error, :oops}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # test "transaction works after failure in savepoint query binding state", context do
  #   assert transaction(fn(conn) ->
  #     statement = "insert into uniques values (CAST($1::text AS int))"
  #     assert {:error, %Tds.Error{mssql: %{code: :invalid_text_representation}}} =
  #       Tds.query(conn, statement, ["invalid"], [mode: :savepoint])

  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end) == {:ok, :hi}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # test "transaction works after failure in savepoint query executing state", context do
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #       Tds.query(conn, "insert into uniques values (1), (1);", [], [mode: :savepoint])

  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end) == {:ok, :hi}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # @tag prepare: :unnamed
  # test "transaction works after failure in unammed savepoint query parsing state", context do
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #     Tds.query(conn, "insert into uniques values (1), (1);", [], [mode: :savepoint])

  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end) == {:ok, :hi}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # @tag prepare: :unnamed
  # test "transaction works after failure in unnamed savepoint query binding state", context do
  #   assert transaction(fn(conn) ->
  #     statement = "insert into uniques values (CAST($1::text AS int))"
  #     assert {:error, %Tds.Error{mssql: %{code: :invalid_text_representation}}} =
  #       Tds.query(conn, statement, ["invalid"], [mode: :savepoint])

  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end) == {:ok, :hi}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :transaction
  # @tag prepare: :unnamed
  # test "transaction works after failure in unnamed savepoint query executing state", context do
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #       Tds.query(conn, "insert into uniques values (1), (1);", [], [mode: :savepoint])

  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end) == {:ok, :hi}

  #   assert [[42]] = query("SELECT 42", [])
  # end

  # @tag mode: :savepoint
  # test "savepoint transaction works after failure in savepoint query parsing state", context do
  #   assert :ok = query("BEGIN", [])
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #     Tds.query(conn, "insert into uniques values (1), (1);", [], [mode: :savepoint])

  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end, [mode: :savepoint]) == {:ok, :hi}

  #   assert [[42]] = query("SELECT 42", [])
  #   assert :ok = query("ROLLBACK", [])
  # end

  # @tag mode: :savepoint
  # test "savepoint transaction works after failure in savepoint query binding state", context do
  #   assert :ok = query("BEGIN", [])
  #   assert transaction(fn(conn) ->
  #     statement = "insert into uniques values (CAST($1::text AS int))"
  #     assert {:error, %Tds.Error{mssql: %{code: :invalid_text_representation}}} =
  #       Tds.query(conn, statement, ["invalid"], [mode: :savepoint])

  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end, [mode: :savepoint]) == {:ok, :hi}

  #   assert [[42]] = query("SELECT 42", [])
  #   assert :ok = query("ROLLBACK", [])
  # end

  # @tag mode: :savepoint
  # test "savepoint transaction works after failure in savepoint query executing state", context do
  #   assert :ok = query("BEGIN", [])
  #   assert transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{mssql: %{code: :unique_violation}}} =
  #       Tds.query(conn, "insert into uniques values (1), (1);", [], [mode: :savepoint])

  #     assert {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])
  #     :hi
  #   end, [mode: :savepoint]) == {:ok, :hi}

  #   assert [[42]] = query("SELECT 42", [])
  #   assert :ok = query("ROLLBACK", [])
  # end

  # @tag mode: :transaction
  # test "COPY FROM STDIN with copy_data: false, mode: :savepoint returns error", context do
  #   transaction(fn(conn) ->
  #     assert {:error, %Tds.Error{}} =
  #       Tds.query(conn, "COPY uniques FROM STDIN", [], [mode: :savepoint])
  #     assert %Tds.Result{rows: [[42]]} = Tds.query!(conn, "SELECT 42", [])
  #   end)
  # end

end
