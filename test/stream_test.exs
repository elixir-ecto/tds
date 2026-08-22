defmodule Tds.StreamTest do
  use ExUnit.Case, async: true
  import Tds.TestHelper

  @moduletag capture_log: true

  setup context do
    opts = [
      isolation_level: :snapshot,
      idle: :active,
      backoff_type: :stop,
      prepare: context[:prepare] || :named
    ]

    opts = Keyword.merge(Tds.TestHelper.opts(), opts)

    {:ok, pid} = Tds.start_link(opts)
    {:ok, [pid: pid]}
  end

  @tag :stream
  test "stream rows from simple query", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_test', 'U') IS NOT NULL DROP TABLE stream_test; CREATE TABLE stream_test (id INT PRIMARY KEY, name NVARCHAR(100));",
        []
      )

    :ok =
      query(
        "INSERT INTO stream_test (id, name) VALUES (1, N'one'), (2, N'two'), (3, N'three'), (4, N'four'), (5, N'five');",
        []
      )

    Tds.transaction(pid, fn conn ->
      stream = Tds.stream(conn, "SELECT id, name FROM stream_test ORDER BY id", [])
      results = Enum.to_list(stream)

      assert length(results) > 0

      all_rows =
        results
        |> Enum.flat_map(fn %Tds.Result{rows: rows} -> rows || [] end)

      assert length(all_rows) == 5
    end)

    :ok = query("DROP TABLE stream_test", [])
  end

  @tag :stream
  test "stream with max_rows chunks results", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_test_max', 'U') IS NOT NULL DROP TABLE stream_test_max; CREATE TABLE stream_test_max (id INT PRIMARY KEY, value INT);",
        []
      )

    values = Enum.map_join(1..10, ", ", fn i -> "(#{i}, #{i * 10})" end)

    :ok = query("INSERT INTO stream_test_max (id, value) VALUES #{values};", [])

    Tds.transaction(pid, fn conn ->
      stream =
        Tds.stream(conn, "SELECT id, value FROM stream_test_max ORDER BY id", [], max_rows: 3)

      results = Enum.to_list(stream)

      assert length(results) >= 1

      all_rows =
        results
        |> Enum.flat_map(fn %Tds.Result{rows: rows} -> rows || [] end)

      assert length(all_rows) == 10
    end)

    :ok = query("DROP TABLE stream_test_max", [])
  end

  @tag :stream
  test "stream with parameterized query", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_test_params', 'U') IS NOT NULL DROP TABLE stream_test_params; CREATE TABLE stream_test_params (id INT PRIMARY KEY, name NVARCHAR(100));",
        []
      )

    :ok =
      query(
        "INSERT INTO stream_test_params (id, name) VALUES (1, N'alice'), (2, N'bob'), (3, N'charlie');",
        []
      )

    Tds.transaction(pid, fn conn ->
      stream =
        Tds.stream(
          conn,
          "SELECT id, name FROM stream_test_params WHERE id > @1 ORDER BY id",
          [%Tds.Parameter{name: "@1", type: :integer, value: 1}]
        )

      results = Enum.to_list(stream)

      all_rows =
        results
        |> Enum.flat_map(fn %Tds.Result{rows: rows} -> rows || [] end)

      assert length(all_rows) == 2
    end)

    :ok = query("DROP TABLE stream_test_params", [])
  end

  @tag :stream
  test "stream empty result set", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_test_empty', 'U') IS NOT NULL DROP TABLE stream_test_empty; CREATE TABLE stream_test_empty (id INT PRIMARY KEY, name NVARCHAR(100));",
        []
      )

    Tds.transaction(pid, fn conn ->
      stream = Tds.stream(conn, "SELECT id, name FROM stream_test_empty", [])
      results = Enum.to_list(stream)

      all_rows =
        results
        |> Enum.flat_map(fn %Tds.Result{rows: rows} -> rows || [] end)

      assert all_rows == []
    end)

    :ok = query("DROP TABLE stream_test_empty", [])
  end

  @tag :stream
  test "stream with DBConnection.stream/4", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_test_dbc', 'U') IS NOT NULL DROP TABLE stream_test_dbc; CREATE TABLE stream_test_dbc (id INT PRIMARY KEY, name NVARCHAR(50));",
        []
      )

    :ok =
      query(
        "INSERT INTO stream_test_dbc (id, name) VALUES (1, N'a'), (2, N'b');",
        []
      )

    Tds.transaction(pid, fn conn ->
      query = %Tds.Query{statement: "SELECT id, name FROM stream_test_dbc ORDER BY id"}
      stream = DBConnection.stream(conn, query, [])
      results = Enum.to_list(stream)

      all_rows =
        results
        |> Enum.flat_map(fn %Tds.Result{rows: rows} -> rows || [] end)

      assert length(all_rows) == 2
    end)

    :ok = query("DROP TABLE stream_test_dbc", [])
  end

  @tag :stream
  test "MAY take part of stream", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_take', 'U') IS NOT NULL DROP TABLE stream_take; CREATE TABLE stream_take (id INT PRIMARY KEY);",
        []
      )

    :ok = query("INSERT INTO stream_take (id) VALUES (1), (2), (3);", [])

    Tds.transaction(pid, fn conn ->
      query = %Tds.Query{statement: "SELECT id FROM stream_take ORDER BY id"}
      stream = DBConnection.stream(conn, query, [], max_rows: 1)

      rows =
        stream
        |> Stream.map(fn %Tds.Result{rows: rows} -> rows end)
        |> Enum.take(1)

      assert rows == [[[1, 1]]]
    end)

    :ok = query("DROP TABLE stream_take", [])
  end

  @tag :stream
  test "stream works after prior query on same connection", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_after_query', 'U') IS NOT NULL DROP TABLE stream_after_query; CREATE TABLE stream_after_query (id INT PRIMARY KEY);",
        []
      )

    :ok = query("INSERT INTO stream_after_query (id) VALUES (1), (2);", [])

    Tds.transaction(pid, fn conn ->
      {:ok, %Tds.Result{rows: [[42]]}} = Tds.query(conn, "SELECT 42", [])

      stream = Tds.stream(conn, "SELECT id FROM stream_after_query ORDER BY id", [])
      results = Enum.to_list(stream)

      all_rows =
        results
        |> Enum.flat_map(fn %Tds.Result{rows: rows} -> rows || [] end)

      assert length(all_rows) == 2
    end)

    :ok = query("DROP TABLE stream_after_query", [])
  end

  @tag :stream
  test "connection works after stream error", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('uniques_stream', 'U') IS NOT NULL DROP TABLE uniques_stream; CREATE TABLE uniques_stream (id INT PRIMARY KEY, CONSTRAINT UIX_uniques_stream_id UNIQUE(id));",
        []
      )

    Tds.transaction(pid, fn conn ->
      stream = Tds.stream(conn, "INSERT INTO uniques_stream (id) VALUES (1), (1)", [])

      assert_raise Tds.Error, fn ->
        Enum.to_list(stream)
      end
    end)

    assert [[42]] = query("SELECT 42", [])

    :ok = query("DROP TABLE uniques_stream", [])
  end

  @tag :stream
  test "prepare, stream and close", context do
    pid = context[:pid]

    Tds.transaction(pid, fn conn ->
      {:ok, query} = Tds.prepare(conn, "SELECT 42")
      stream = DBConnection.stream(conn, query, [])
      results = Enum.to_list(stream)

      data_results = Enum.filter(results, fn %Tds.Result{num_rows: n} -> n > 0 end)
      assert [%Tds.Result{rows: [[42, 1]]}] = data_results

      stream = DBConnection.stream(conn, query, [])
      results2 = Enum.to_list(stream)
      data_results2 = Enum.filter(results2, fn %Tds.Result{num_rows: n} -> n > 0 end)
      assert [%Tds.Result{rows: [[42, 1]]}] = data_results2
    end)
  end

  @tag :stream
  test "stream processes rows lazily in batches", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_lazy', 'U') IS NOT NULL DROP TABLE stream_lazy; CREATE TABLE stream_lazy (id INT PRIMARY KEY, val INT);",
        []
      )

    values = Enum.map_join(1..20, ", ", fn i -> "(#{i}, #{i * 100})" end)
    :ok = query("INSERT INTO stream_lazy (id, val) VALUES #{values};", [])

    Tds.transaction(pid, fn conn ->
      stream =
        Tds.stream(conn, "SELECT id, val FROM stream_lazy ORDER BY id", [], max_rows: 4)

      batches =
        stream
        |> Stream.map(fn %Tds.Result{rows: rows, num_rows: n} -> {rows, n} end)
        |> Enum.to_list()

      data_batches = Enum.filter(batches, fn {_, n} -> n > 0 end)

      assert length(data_batches) == 5

      for {rows, n} <- data_batches do
        assert n == 4
        assert length(rows) == 4
      end

      all_ids =
        data_batches
        |> Enum.flat_map(fn {rows, _} -> Enum.map(rows, fn [id, _val, _rowstat] -> id end) end)

      assert all_ids == Enum.to_list(1..20)
    end)

    :ok = query("DROP TABLE stream_lazy", [])
  end

  @tag :stream
  test "stream processes rows with side effects per batch", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_side_effects', 'U') IS NOT NULL DROP TABLE stream_side_effects; CREATE TABLE stream_side_effects (id INT PRIMARY KEY);",
        []
      )

    :ok = query("INSERT INTO stream_side_effects (id) VALUES (1), (2), (3), (4), (5), (6);", [])

    Tds.transaction(pid, fn conn ->
      stream =
        Tds.stream(conn, "SELECT id FROM stream_side_effects ORDER BY id", [], max_rows: 2)

      {:ok, agent} = Agent.start_link(fn -> [] end)

      stream
      |> Stream.each(fn %Tds.Result{rows: rows, num_rows: n} ->
        if n > 0 do
          ids = Enum.map(rows, fn [id, _rowstat] -> id end)
          Agent.update(agent, fn acc -> acc ++ ids end)
        end
      end)
      |> Stream.run()

      collected_ids = Agent.get(agent, & &1)
      Agent.stop(agent)

      assert collected_ids == [1, 2, 3, 4, 5, 6]
    end)

    :ok = query("DROP TABLE stream_side_effects", [])
  end

  @tag :stream
  test "stream chunks arrive progressively and can be transformed", context do
    pid = context[:pid]

    :ok =
      query(
        "IF OBJECT_ID('stream_transform', 'U') IS NOT NULL DROP TABLE stream_transform; CREATE TABLE stream_transform (id INT PRIMARY KEY, name NVARCHAR(50));",
        []
      )

    :ok =
      query(
        "INSERT INTO stream_transform (id, name) VALUES (1, N'alice'), (2, N'bob'), (3, N'carol'), (4, N'dave'), (5, N'eve'), (6, N'frank');",
        []
      )

    Tds.transaction(pid, fn conn ->
      stream =
        Tds.stream(conn, "SELECT id, name FROM stream_transform ORDER BY id", [], max_rows: 2)

      names =
        stream
        |> Stream.flat_map(fn %Tds.Result{rows: rows, num_rows: n} ->
          if n > 0 do
            Enum.map(rows, fn [id, name, _rowstat] -> {id, name} end)
          else
            []
          end
        end)
        |> Enum.to_list()

      assert names == [
               {1, "alice"},
               {2, "bob"},
               {3, "carol"},
               {4, "dave"},
               {5, "eve"},
               {6, "frank"}
             ]
    end)

    :ok = query("DROP TABLE stream_transform", [])
  end
end
