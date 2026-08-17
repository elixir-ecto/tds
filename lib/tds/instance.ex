defmodule Tds.Instance do
  @moduledoc false

  @default_browser_port 1434
  @default_timeout 3_000

  @type resolution ::
          {:ok, :inet.port_number()}
          | {:fallback, :inet.port_number(), Tds.Error.t()}
          | {:error, Tds.Error.t()}

  @spec resolve_port(Keyword.t()) :: resolution()
  def resolve_port(opts) do
    case resolve(opts) do
      {:ok, port} ->
        {:ok, port}

      {:error, %Tds.Error{} = instance_error} ->
        case fallback_port(opts) do
          {:ok, port} -> {:fallback, port, instance_error}
          :none -> {:error, instance_error}
          {:error, %Tds.Error{} = fallback_error} -> {:error, fallback_error}
        end
    end
  end

  @spec resolve(Keyword.t()) :: {:ok, :inet.port_number()} | {:error, Tds.Error.t()}
  def resolve(opts) do
    udp_module = Keyword.get(opts, :instance_udp_module, :gen_udp)

    with {:ok, instance} <- instance_name(opts),
         {:ok, timeout} <- instance_timeout(opts),
         {:ok, browser_port} <- browser_port(opts),
         {:ok, socket} <- open_socket(udp_module) do
      try do
        resolve_on_socket(udp_module, socket, opts, browser_port, timeout, instance)
      after
        close_socket(udp_module, socket)
      end
    end
  end

  defp resolve_on_socket(udp_module, socket, opts, browser_port, timeout, instance) do
    host = Keyword.fetch!(opts, :hostname)
    host = if is_binary(host), do: String.to_charlist(host), else: host

    with :ok <- send_query(udp_module, socket, host, browser_port),
         {:ok, message} <- receive_response(udp_module, socket, timeout),
         {:ok, port} <- parse_response(message, browser_port, instance) do
      {:ok, port}
    end
  rescue
    exception -> error("SQL Server Browser lookup failed: #{Exception.message(exception)}")
  catch
    kind, reason -> error("SQL Server Browser lookup failed: #{inspect({kind, reason})}")
  end

  defp open_socket(udp_module) do
    case guarded_call(fn ->
           udp_module.open(0, [:binary, {:active, false}, {:reuseaddr, true}])
         end) do
      {:ok, {:ok, socket}} -> {:ok, socket}
      {:ok, {:error, reason}} -> error("udp open failed: #{inspect(reason)}")
      {:ok, other} -> error("udp open returned an unexpected result: #{inspect(other)}")
      {:error, reason} -> error("udp open failed: #{inspect(reason)}")
    end
  end

  defp send_query(udp_module, socket, host, browser_port) do
    case guarded_call(fn -> udp_module.send(socket, host, browser_port, <<3>>) end) do
      {:ok, :ok} ->
        :ok

      {:ok, {:error, reason}} ->
        error("SQL Server Browser send failed: #{inspect(reason)}")

      {:ok, other} ->
        error("SQL Server Browser send returned an unexpected result: #{inspect(other)}")

      {:error, reason} ->
        error("SQL Server Browser send failed: #{inspect(reason)}")
    end
  end

  defp receive_response(udp_module, socket, timeout) do
    case guarded_call(fn -> udp_module.recv(socket, 0, timeout) end) do
      {:ok, {:ok, message}} ->
        {:ok, message}

      {:ok, {:error, :timeout}} ->
        error("SQL Server Browser instance lookup timed out after #{timeout}ms")

      {:ok, {:error, reason}} ->
        error("SQL Server Browser receive failed: #{inspect(reason)}")

      {:ok, other} ->
        error("SQL Server Browser receive returned an unexpected result: #{inspect(other)}")

      {:error, reason} ->
        error("SQL Server Browser receive failed: #{inspect(reason)}")
    end
  end

  defp close_socket(udp_module, socket) do
    _ = guarded_call(fn -> udp_module.close(socket) end)
    :ok
  end

  defp parse_response(
         {_address, source_port, <<5, declared_length::little-16, data::binary>>},
         source_port,
         instance
       )
       when declared_length == byte_size(data) do
    parse_instances(data, instance)
  end

  defp parse_response(_message, _browser_port, _instance) do
    error("SQL Server Browser returned a malformed response")
  end

  defp parse_instances(data, instance) do
    if String.valid?(data) do
      servers =
        data
        |> String.trim_trailing(<<0>>)
        |> String.split(";;", trim: true)
        |> Enum.reduce([], fn record, servers ->
          case parse_server(record) do
            {:ok, server} -> [server | servers]
            :error -> servers
          end
        end)

      find_instance(servers, instance)
    else
      error("SQL Server Browser returned a malformed response")
    end
  end

  defp parse_server(record) do
    fields = String.split(record, ";", trim: false)

    if fields != [] and rem(length(fields), 2) == 0 do
      fields
      |> Enum.chunk_every(2)
      |> Enum.reduce_while({:ok, %{}}, fn
        [key, value], {:ok, server} ->
          key = key |> String.trim() |> String.downcase()

          if key == "" do
            {:halt, :error}
          else
            {:cont, {:ok, Map.put(server, key, String.trim(value))}}
          end

        _fields, _server ->
          {:halt, :error}
      end)
    else
      :error
    end
  end

  defp find_instance([], _instance) do
    error("SQL Server Browser returned a malformed response")
  end

  defp find_instance(servers, instance) do
    instance = String.downcase(instance)

    case Enum.find(servers, fn server ->
           case Map.get(server, "instancename") do
             name when is_binary(name) -> String.downcase(name) == instance
             _other -> false
           end
         end) do
      nil ->
        error("Instance #{instance} not found")

      server ->
        normalize_port(Map.get(server, "tcp"), "SQL Server Browser tcp port")
    end
  end

  defp instance_name(opts) do
    case Keyword.get(opts, :instance) do
      instance when is_binary(instance) ->
        case String.trim(instance) do
          "" -> error("SQL Server instance name must not be empty")
          instance -> {:ok, instance}
        end

      instance when is_list(instance) ->
        instance_name(instance: List.to_string(instance))

      instance ->
        error("SQL Server instance name is invalid: #{inspect(instance)}")
    end
  rescue
    _exception -> error("SQL Server instance name is invalid")
  end

  defp instance_timeout(opts) do
    case Keyword.get(opts, :instance_timeout, @default_timeout) do
      timeout when is_integer(timeout) and timeout >= 0 -> {:ok, timeout}
      timeout -> error("SQL Server Browser timeout is invalid: #{inspect(timeout)}")
    end
  end

  defp browser_port(opts) do
    opts
    |> Keyword.get(:instance_browser_port, @default_browser_port)
    |> normalize_port("SQL Server Browser port")
  end

  defp fallback_port(opts) do
    case Keyword.fetch(opts, :port) do
      {:ok, port} ->
        normalize_port(port, "SQL Server fallback port")

      :error ->
        case System.get_env("MSSQLPORT") do
          nil -> :none
          port -> normalize_port(port, "SQL Server fallback port")
        end
    end
  end

  defp normalize_port(port, _label) when is_integer(port) and port in 1..65_535 do
    {:ok, port}
  end

  defp normalize_port(port, label) when is_binary(port) do
    case Integer.parse(String.trim(port)) do
      {port, ""} when port in 1..65_535 -> {:ok, port}
      _other -> error("#{label} is invalid: #{inspect(port)}")
    end
  end

  defp normalize_port(port, label) do
    error("#{label} is invalid: #{inspect(port)}")
  end

  defp guarded_call(fun) do
    {:ok, fun.()}
  rescue
    exception -> {:error, {:exception, exception}}
  catch
    kind, reason -> {:error, {kind, reason}}
  end

  defp error(message), do: {:error, %Tds.Error{message: message}}
end
