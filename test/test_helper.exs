ExUnit.start()


defmodule Tds.TestHelper do
  require Logger

  defmacro query_multiset(stat, params, opts \\ []) do
    quote do
      case Tds.Connection.query(var!(context)[:pid], unquote(stat),
                                     unquote(params), unquote(opts)) do
        {:ok, results} when is_list(results) -> Enum.map(results, fn %{rows: rows} -> rows end)
        {:error, %Tds.Error{} = err} -> err
      end
    end
  end

  defmacro query(stat, params, opts \\ []) do
    quote do
      case query_multiset(unquote(stat), unquote(params), unquote(opts)) do
        [] -> :ok
        [[] | _] -> :ok
        [h | _] -> h
        err -> err
      end
    end
  end

  defmacro proc(proc, params, opts \\ []) do
    quote do
      case Tds.Connection.proc(var!(context)[:pid], unquote(proc),
                                     unquote(params), unquote(opts)) do
        {:ok, %Tds.Result{rows: nil}} -> :ok
        {:ok, %Tds.Result{rows: []}} -> :ok
        {:ok, %Tds.Result{rows: rows}} -> rows
        {:error, %Tds.Error{} = err} -> err
      end
    end
  end
end
