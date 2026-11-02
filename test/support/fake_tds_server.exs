defmodule Tds.FakeServer do
  @moduledoc false
  alias Tds.Encoding.UCS2

  # Just enough of a SQL Server to get a client through PRELOGIN (optionally
  # with TLS, wrapped in PRELOGIN packets like the real thing), LOGIN7 and
  # the connection SET batch, then hand each query to a script.
  #
  # `script` is a list of steps run for each client query, in order:
  #   {:reply, packets} | {:close, packets} | :hang
  # and `login: :close` hangs up after reading LOGIN7, `set_batch: :close`
  # after reading the connection SET batch. `fed_auth_required: 0 | 1` adds
  # FEDAUTHREQUIRED to the PRELOGIN response and `fed_auth_ack: false` leaves
  # the FEDAUTH FEATUREEXTACK out of the login response. `prelogin_reply:`
  # replaces the whole PRELOGIN response with the given option data. The
  # client's PRELOGIN is reported as {:prelogin, data}. `redirect: port` plays
  # an Azure gateway: it routes the client to `route_host` (127.0.0.1 by
  # default), as `host\instance` when `route_instance` is given, on that
  # port and reports whether the client closes the leg (as {:gateway_leg,
  # result}), hanging up itself if the client keeps it open.
  #
  # Pass a list of option lists to serve one connection after another.

  # DONE with the count bit set and 5 rows
  def done, do: <<0xFD, 0x10::little-16, 0xC1::little-16, 5::little-64>>

  def packet(status, data) do
    <<0x04, status, byte_size(data) + 8::16, 0::16, 1, 0>> <> data
  end

  def start(opts) do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    test = self()
    connections = if Keyword.keyword?(opts), do: [opts], else: opts
    server = spawn_link(fn -> Enum.each(connections, &serve(listen, test, &1)) end)
    {server, port}
  end

  defp serve(listen, test, opts) do
    {:ok, sock} = :gen_tcp.accept(listen)
    tls? = Keyword.get(opts, :tls, false)

    # PRELOGIN: VERSION, ENCRYPTION (ON with TLS, NOT_SUP without) and
    # optionally FEDAUTHREQUIRED
    send(test, {:prelogin, recv_message({:gen_tcp, sock})})
    encryption = if tls?, do: 0x01, else: 0x02

    reply =
      Keyword.get_lazy(opts, :prelogin_reply, fn ->
        prelogin(encryption, opts[:fed_auth_required])
      end)

    :ok = :gen_tcp.send(sock, packet(1, reply))

    conn = if tls?, do: {:ssl, tls_handshake(sock, test)}, else: {:gen_tcp, sock}

    login7 = recv_message(conn)
    send(test, {:login7, login7})

    login =
      if port = opts[:redirect], do: {:redirect, port}, else: Keyword.get(opts, :login, :ok)

    case login do
      :close ->
        close(conn)

      {:redirect, port} ->
        route = Keyword.get(opts, :route_host, "127.0.0.1")
        route = if instance = opts[:route_instance], do: route <> "\\" <> instance, else: route
        redirect(conn, route, port, test)

      :ok ->
        # LOGINACK, FEATUREEXTACK (FEDAUTH, no data) and DONE
        featureextack =
          if Keyword.get(opts, :fed_auth_ack, true),
            do: <<0xAE, 0x02, 0::little-32, 0xFF>>,
            else: <<>>

        send_data(conn, packet(1, loginack() <> featureextack <> done()))

        # connection SET statements
        _ = recv_message(conn)

        if opts[:set_batch] == :close do
          close(conn)
        else
          send_data(conn, packet(1, done()))
          run(conn, Keyword.get(opts, :script, []), test)
        end
    end
  end

  defp prelogin(encryption, nil) do
    <<0x00, 11::16, 6::16, 0x01, 17::16, 1::16, 0xFF, 16, 0, 0, 0, 0, 0, encryption>>
  end

  defp prelogin(encryption, fed_auth_required) do
    <<0x00, 16::16, 6::16, 0x01, 22::16, 1::16, 0x06, 23::16, 1::16, 0xFF, 16, 0, 0, 0, 0, 0,
      encryption, fed_auth_required>>
  end

  # LOGINACK with a routing ENVCHANGE to host:port
  defp redirect(conn, host, port, test) do
    host = UCS2.from_string(host)
    routing = <<0x00, port::little-16, div(byte_size(host), 2)::little-16>> <> host
    env = <<0x14, byte_size(routing)::little-16>> <> routing <> <<0, 0>>
    envchange = <<0xE3, byte_size(env)::little-16>> <> env
    send_data(conn, packet(1, loginack() <> envchange <> done()))

    send(test, {:gateway_leg, recv(conn, 0, 500)})
    close(conn)
  end

  defp loginack do
    ack = <<1, 0x74000004::32, 1, ?M, 0, 16, 0, 0, 0>>
    <<0xAD, byte_size(ack)::little-16>> <> ack
  end

  defp run(conn, [], test), do: send(test, {:server_done, recv(conn, 0, 1_000)})

  defp run(conn, [step | script], test) do
    _ = recv_message(conn)

    case step do
      {:reply, packets} ->
        Enum.each(packets, &send_data(conn, &1))
        run(conn, script, test)

      {:close, packets} ->
        Enum.each(packets, &send_data(conn, &1))
        close(conn)

      :hang ->
        send(test, {:server_done, recv(conn, 0, 5_000)})
    end
  end

  # The client's Tds.Tls transport wraps the handshake in PRELOGIN packets;
  # it is symmetric, so the server side can use it as well
  # Reports the client's SNI as {:sni, hostname | :none}
  defp tls_handshake(sock, test) do
    %{server_config: server_config} =
      :public_key.pkix_test_data(%{
        server_chain: %{root: cert_opts(), intermediates: [], peer: cert_opts()},
        client_chain: %{root: cert_opts(), intermediates: [], peer: cert_opts()}
      })

    {:ok, tls} = GenServer.start_link(Tds.Tls, {sock, []})
    :ok = :gen_tcp.controlling_process(sock, tls)

    ssl_opts =
      server_config ++
        [
          versions: [:"tlsv1.2"],
          active: false,
          cb_info: {Tds.FakeServer.Transport, :tcp, :tcp_closed, :tcp_error}
        ]

    {:ok, ssl} = :ssl.handshake(sock, ssl_opts, 5_000)
    GenServer.cast(tls, :handshake_complete)

    sni =
      case :ssl.connection_information(ssl, [:sni_hostname]) do
        {:ok, [sni_hostname: host]} -> host
        _ -> :none
      end

    send(test, {:sni, sni})
    ssl
  end

  defp cert_opts, do: [key: {:rsa, 2048, 65_537}, digest: :sha256]

  # Reads one client message, packet by packet, up to the EOM status bit.
  # Returns {:error, reason} once the client has hung up.
  def recv_message(conn, acc \\ <<>>) do
    with {:ok, <<_type, status, length::16, _::binary-4>>} <- recv(conn, 8, 5_000),
         {:ok, data} <- recv(conn, length - 8, 5_000) do
      if status == 0, do: recv_message(conn, acc <> data), else: acc <> data
    end
  end

  defp recv({:gen_tcp, sock}, n, timeout), do: :gen_tcp.recv(sock, n, timeout)
  defp recv({:ssl, sock}, n, timeout), do: :ssl.recv(sock, n, timeout)

  defp send_data({:gen_tcp, sock}, data), do: _ = :gen_tcp.send(sock, data)
  defp send_data({:ssl, sock}, data), do: _ = :ssl.send(sock, data)

  defp close({:gen_tcp, sock}), do: :gen_tcp.close(sock)
  defp close({:ssl, sock}), do: :ssl.close(sock)
end

defmodule Tds.FakeServer.Transport do
  @moduledoc false
  # Tds.Tls as an :ssl server transport, which also needs port/1

  defdelegate send(socket, data), to: Tds.Tls
  defdelegate recv(socket, length), to: Tds.Tls
  defdelegate recv(socket, length, timeout), to: Tds.Tls
  defdelegate controlling_process(socket, pid), to: Tds.Tls
  defdelegate setopts(socket, opts), to: Tds.Tls
  defdelegate getopts(socket, opts), to: :inet
  defdelegate peername(socket), to: :inet
  defdelegate sockname(socket), to: :inet
  defdelegate port(socket), to: :inet
  defdelegate close(socket), to: :gen_tcp
  defdelegate shutdown(socket, how), to: :gen_tcp
end
