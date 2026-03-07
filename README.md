# Tds - MSSQL Driver for Elixir

[![Hex.pm](https://img.shields.io/hexpm/v/tds.svg)](https://hex.pm/packages/tds)
![Elixir TDS CI](https://github.com/elixir-ecto/tds/workflows/Elixir%20TDS%20CI/badge.svg)

MSSQL / TDS Database driver for Elixir.

### NOTE:
Since TDS version 2.0, `tds_ecto` package is deprecated, this version supports `ecto_sql` since version 3.3.4.

For stable versions always use [hex.pm](https://hex.pm/packages/tds) as source for your mix.exs.

## Usage

Add `:tds` as a dependency in your `mix.exs` file.

```elixir
def deps do
  [
    {:tds, "~> 3.0"}
  ]
end
```

As of TDS version `>= 1.2`, tds can support windows codepages other than `windows-1252` (latin1).
If you need such support you will need to include additional dependency `{:excoding, "~> 0.1"}`
and configure `:tds` app to use `Excoding` module like this:


```elixir
import Mix.Config

config :tds, :text_encoder, Excoding
```

When you are done, run `mix deps.get` in your shell to fetch and compile Tds.
Start an interactive Elixir shell with `iex -S mix`.

```elixir
iex> {:ok, pid} = Tds.start_link([hostname: "localhost", username: "test_user", password: "test_password", database: "test_db", port: 4000])
{:ok, #PID<0.69.0>}

iex> Tds.query!(pid, "SELECT 'Some Awesome Text' AS MyColumn", [])
%Tds.Result{columns: ["MyColumn"], rows: [{"Some Awesome Text"}], num_rows: 1}}

iex> Tds.query!(pid, "INSERT INTO MyTable (MyColumn) VALUES (@my_value)",
...> [%Tds.Parameter{name: "@my_value", value: "My Actual Value"}])
%Tds.Result{columns: nil, rows: nil, num_rows: 1}}
```

## Features

* Automatic decoding and encoding of Elixir values to and from MSSQL's binary format
* Support of TDS Versions 7.3, 7.4

## Configuration

Example configuration

```elixir
import Mix.Config

config :your_app, :tds_conn,
  hostname: "localhost",
  username: "test_user",
  password: "test_password",
  database: "test_db",
  port: 1433
```

Then using `Application.get_env(:your_app, :tds_conn)` use this as first parameter in `Tds.start_link/1` function.

There is additional parameter that can be used in configuration and
can improve query execution in SQL Server. If you find out that
your queries suffer from "density estimation" as described [here](https://www.brentozar.com/archive/2018/03/sp_prepare-isnt-good-sp_executesql-performance/)

You can try switching how tds executes queries as below:

```elixir
import Mix.Config

config :your_app, :tds_conn,
  hostname: "localhost",
  username: "test_user",
  password: "test_password",
  database: "test_db",
  port: 1433,
  execution_mode: :executesql
```
This will skip calling `sp_prepare` and query will be executed using `sp_executesql` instead.
Please note that only one execution mode can be set at a time, and SQL Server will probably
use single execution plan (since it is NOT estimated by checking data density!).

## SSL / TLS support

tds `>= 2.3.0` supports encrypted connections to the SQL Server.

The following encryption behaviours are currently supported:

- `:required`: Requires the server to use TLS
- `:on`: Same as required
- `:not_supported`: Indicates to the server that encryption is not supported. If server requires encryption, the connection will not be established.
- `:ssl_opts`: Allow pass options for ssl connection (this options are the same as ssl erlang standart library).

Currently not supported:

- `:off`: This setting allows the server to upgrade the connection (if server encryption is `:on` or `:required`) and only encrypts the LOGIN packet when the server has encryption set to `:off`.
- `:client_cert`: This will make the server check the client cerfiticate.

Setting `ssl: true` or `ssl: false` is also allowed. In that case `true` is mapped to `:required` and `false` to `:not_supported`.

```elixir
config :your_app, :tds_conn,
  hostname: "localhost",
  username: "test_user",
  password: "test_password",
  database: "test_db",
  ssl: :required,
  port: 1433,
  execution_mode: :executesql

```

## Connecting to SQL Server Instances

Tds supports SQL Server instances by passing `instance: "instancename"` to the connection options.
Since v1.0.16, additional connection parameters are:
  - `:set_language` - check stored procedure output `exec sp_helplanguage` name column value should be used here
  - `:set_datefirst` - number in range `1..7`
  - `:set_dateformat` - atom, one of `:mdy | :dmy | :ymd | :ydm | :myd | :dym`
  - `:set_deadlock_priority` - atom, one of `:low | :high | :normal | -10..10`
  - `:set_lock_timeout` - number in milliseconds > 0
  - `:set_remote_proc_transactions` - atom, one of `:on | :off`
  - `:set_implicit_transactions` - atom, one of `:on | :off`
  - `:set_transaction_isolation_level` - atom, one of `:read_uncommitted | :read_committed | :repeatable_read | :snapshot | :serializable`
  - `:set_allow_snapshot_isolation` - atom, one of `:on | :off`
  - `:set_cursor_close_on_commit` - atom, one of `:on | :off`
  - `:set_read_committed_snapshot` - atom, one of `:on | :off`

Set this option to enable snapshot isolation on the database level.
Requires connecting with a user with appropriate rights.
More info [here](https://docs.microsoft.com/en-us/dotnet/framework/data/adonet/sql/snapshot-isolation-in-sql-server).


## Federation Authentication

This Authentication mechanism is not supported.
This functionality requires specific environment to be developed.

## Data representation

| TDS               | Elixir                 |
| ----------------- | ---------------------- |
| NULL              | `nil`                  |
| bool              | `true` / `false`       |
| char / varchar    | `"text"`               |
| nchar / nvarchar  | `"text"`               |
| int / bigint      | `42`                   |
| float / real      | `42.0`                 |
| text / ntext      | `"text"`               |
| binary / varbinary | `<<42>>`              |
| numeric / decimal | `#Decimal<42.0>`       |
| money / smallmoney | `#Decimal<10.5000>`   |
| date              | `%Date{}`              |
| time              | `%Time{}`              |
| smalldatetime     | `%NaiveDateTime{}`     |
| datetime          | `%NaiveDateTime{}`     |
| datetime2         | `%NaiveDateTime{}`     |
| datetimeoffset(n) | `%DateTime{}`          |
| uniqueidentifier  | `<<_::128>>`           |
| xml               | `"<xml>...</xml>"`     |
| sql_variant       | varies by inner type   |

User-Defined Types (UDT) are returned as raw binary by default. Register custom
handlers via `extra_types` to decode specific UDTs (see below).

### Dates and Times

As of v3.0, all date/time columns are decoded as Elixir calendar structs:

| SQL Type            | Elixir Type          |
| ------------------- | -------------------- |
| `date`              | `%Date{}`            |
| `time(n)`           | `%Time{}`            |
| `smalldatetime`     | `%NaiveDateTime{}`   |
| `datetime`          | `%NaiveDateTime{}`   |
| `datetime2(n)`      | `%NaiveDateTime{}`   |
| `datetimeoffset(n)` | `%DateTime{}`        |

SQL Server `time`, `datetime2`, and `datetimeoffset` support precision 0-7.
Elixir's `microsecond` field supports precision 0-6, so fractional seconds
are truncated to microsecond precision when the SQL scale exceeds 6.

The `use_elixir_calendar_types` config option from v2.x is no longer needed
and is ignored in v3.0.

### UUIDs

[MSSQL stores UUIDs in mixed-endian
format](https://dba.stackexchange.com/a/121878) where the first three groups
are byte-reversed (little-endian) and the last two are big-endian.

As of v3.0, the `Tds.Type.UUID` wire handler performs this byte reordering
automatically at the protocol level, so `Ecto.UUID` works directly without
any wrapper module.

`Tds.Types.UUID` is deprecated. Use `Ecto.UUID` for all UUID operations.

### Custom Type Handlers

Register custom type handlers via the `extra_types` connection option:

```elixir
Tds.start_link(
  hostname: "localhost",
  extra_types: [MyApp.GeographyType]
)
```

Custom handlers implement the `Tds.Type` behaviour and can override built-in
handlers for the same type codes or names. See `Tds.Type` docs for the
callback specification.

## Contributing

Clone and compile Tds with:

```bash
git clone https://github.com/elixir-ecto/tds.git
cd tds
mix deps.get
```

You can test the library with `mix test`. Use `mix credo` for linting and
`mix dialyzer` for static code analysis. Dialyzer will take a while when you
use it for the first time.

### Development SQL Server Setup

The tests require an SQL Server database to be available on localhost.
If you are not using Windows OS you can start sql server instance using Docker.
Official SQL Server Docker image can be found [here](https://hub.docker.com/r/microsoft/mssql-server).

If you do not have specific requirements on how you would like to start sql server
in docker, you can use script for this repo.

```bash
$ docker compose up -d --profile=<check_profile_in_compose>
```

👉🏻 OR  you can let mix task to detect platform you are using and chose best option for you.

```
mix docker.compose up
```

you can see more details about options for `mix docker.compose` taks by running help `mix help docker.compose`


it will do but in some cases you may want to use `mix docker.compose up` so it detects for you which platform you are using, so it will use appropriate image.

If you prefer to install SQL Server directly on your computer, you can find
installation instructions here:

* [Windows](https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-installation-wizard-setup)
* [Linux](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup)

Make sure your SQL Server accepts the credentials defined in `test/test_helper.exs`.

You also will need to have the *sqlcmd* command line tools installed. Setup
instructions can be found here:

* [Linux](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools)
* [macOS](https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/install-microsoft-odbc-driver-sql-server-macos)

## Special Thanks

Thanks to [ericmj](https://github.com/ericmj), this driver takes a lot of inspiration from postgrex.

Also thanks to everyone in the Elixir Google group and on the Elixir IRC Channel.

## Copyright and License

Copyright (c) 2015 LiveHelpNow

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [https://www.apache.org/licenses/LICENSE-2.0](https://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
