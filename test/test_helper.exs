ExUnit.start()

defmodule Tds.TestHelper do
  require Logger
  defmacro query(stat, params, opts \\ []) do
    quote do
      case Tds.query(var!(context)[:pid], unquote(stat),
                                     unquote(params), unquote(opts)) do
        {:ok, %Tds.Result{rows: nil}} -> :ok
        {:ok, %Tds.Result{rows: []}} -> :ok
        {:ok, %Tds.Result{rows: rows}} -> rows
        {:error, %Tds.Error{} = err} -> err
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
