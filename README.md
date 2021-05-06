# Tds - MSSQL Driver for Elixir

[![Hex.pm](https://img.shields.io/hexpm/v/tds.svg)](https://hex.pm/packages/tds) 
[![Coverage Status](https://coveralls.io/repos/github/livehelpnow/tds/badge.svg?branch=support-1.1)](https://coveralls.io/github/livehelpnow/tds?branch=master)
![Elixir TDS CI](https://github.com/livehelpnow/tds/workflows/Elixir%20TDS%20CI/badge.svg)

MSSQL / TDS Database driver for Elixir.

### NOTE: 
Since TDS version 2.0, `tds_ecto` package is deprecated, this version supports `ecto_sql` since version 3.3.4. 

Please check out the issues for a more complete overview. This branch should not be considered stable or ready for production yet.

For stable versions always use [hex.pm](https://hex.pm/packages/tds) as source for your mix.exs!!!

## Usage


Add `:tds` as a dependency in your `mix.exs` file.

```elixir
def deps do
  [{:tds, "~> 2.0"}]
end
```

As of TDS version `>= 1.2`, tds can support windows codepages other than `windows-1252` (latin1). 
If you need such support you will need to include additional dependency `{:tds_encoding, "~> 1.0"}` 
and configure `:tds` app to use `Tds.Encoding` module like this:


```elixir
import Mix.Config

config :tds, :text_encoder, Tds.Encoding
```

Note that `:tds_encoding` requires Rust compiler installed in order to compile nif. 
In previous versions only SQL_Latin1_General was suported (codepage `windows-1252`). 
Please follow instructions at [rust website](https://www.rust-lang.org/tools/install) 
to install rust.

When you are done, run `mix deps.get` in your shell to fetch and compile Tds. 
Start an interactive Elixir shell with `iex -S mix`.

```iex
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

you can try switching how tds executes queries as below:

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

## Data representation

| TDS               | Elixir                                                                                     |
| ----------------- | ------------------------------------------------------------------------------------------ |
| NULL              | nil                                                                                        |
| bool              | true / false                                                                               |
| char              | "é"                                                                                        |
| int               | 42                                                                                         |
| float             | 42.0                                                                                       |
| text              | "text"                                                                                     |
| binary            | <<42>>                                                                                     |
| numeric           | #Decimal<42.0>                                                                             |
| date              | {2013, 10, 12} or %Date{}                                                                  |
| time              | {0, 37, 14} or {0, 37, 14, 123456} or %Time{}                                              |
| smalldatetime     | {{2013, 10, 12}, {0, 37, 14}} or {{2013, 10, 12}, {0, 37, 14, 123456}}                     |
| datetime          | {{2013, 10, 12}, {0, 37, 14}} or {{2013, 10, 12}, {0, 37, 14, 123456}} or %NaiveDateTime{} |
| datetime2         | {{2013, 10, 12}, {0, 37, 14}} or {{2013, 10, 12}, {0, 37, 14, 123456}} or %NaiveDateTime{} |
| datetimeoffset(n) | {{2013, 10, 12}, {0, 37, 14}} or {{2013, 10, 12}, {0, 37, 14, 123456}} or %DateTime{}      |
| uuid              | <<160,238,188,153,156,11,78,248,187,109,107,185,189,56,10,17>>                             |

Currently unsupported: [User-Defined Types](https://docs.microsoft.com/en-us/sql/relational-databases/clr-integration-database-objects-user-defined-types/working-with-user-defined-types-in-sql-server), XML

### Dates and Times

Tds can work with dates and times in either a tuple format or as Elixir calendar types. Calendar types can be enabled in the config with `config :tds, opts: [use_elixir_calendar_types: true]`.

**Tuple forms:**

- Date: `{yr, mth, day}`
- Time: `{hr, min, sec}` or `{hr, min, sec, fractional_seconds}`
- DateTime: `{date, time}`
- DateTimeOffset: `{utc_date, utc_time, offset_mins}`

In SQL Server, the `fractional_seconds` of a `time`, `datetime2` or `datetimeoffset(n)` column can have a precision of 0-7, where the `microsecond` field of a `%Time{}` or `%DateTime{}` struct can have a precision of 0-6.

Note that the DateTimeOffset tuple expects the date and time in UTC and the offset in minutes. For example, `{{2020, 4, 5}, {5, 30, 59}, 600}` is equal to `'2020-04-05 15:30:59+10:00'`.

### UUIDs

[MSSQL stores UUIDs in mixed-endian
format](https://dba.stackexchange.com/a/121878), and these mixed-endian UUIDs
are returned in [Tds.Result](https://hexdocs.pm/tds/Tds.Result.html).

To convert a mixed-endian UUID binary to a big-endian string, use 
[Tds.Types.UUID.load/1](https://hexdocs.pm/tds/Tds.Types.UUID.html#load/1)

To convert a big-endian UUID string to a mixed-endian binary, use
[Tds.Types.UUID.dump/1](https://hexdocs.pm/tds/Tds.Types.UUID.html#dump/1)

## Contributing

Clone and compile Tds with:

```bash
git clone https://github.com/livehelpnow/tds.git
cd tds
mix deps.get
```

You can test the library with `mix test`. Use `mix credo` for linting and
`mix dialyzer` for static code analysis. Dialyzer will take a while when you
use it for the first time.

### Development SQL Server Setup

The tests require an SQL Server database to be available on localhost. 
If you are not using Windows OS you can start sql server instance using Docker.
Official SQL Server Docker image can be found [here](https://hub.docker.com/r/microsoft/mssql-server-linux).

If you do not have specific requirements on how you would like to start sql server 
in docker, you can use script for this repo.

```bash
$ ./docker-mssql.sh
```

If you prefer to install SQL Server directly on your computer, you can find
installation instructions here:

* [Windows](https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-installation-wizard-setup)
* [Linux](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup)

Make sure your SQL Server accepts the credentials defined in `config/test.exs`.

You also will need to have the *sqlcmd* command line tools installed. Setup
instructions can be found here:

* [Linux](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools)
* [macOS](https://docs.microsoft.com/en-us/sql/connect/odbc/linux-mac/install-microsoft-odbc-driver-sql-server-macos)

## Special Thanks

Thanks to [ericmj](https://github.com/ericmj), this driver takes a lot of inspiration from postgrex.

Also thanks to everyone in the Elixir Google group and on the Elixir IRC Channel.

## License

Copyright 2014, 2015, 2017 LiveHelpNow

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
