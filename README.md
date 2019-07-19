# Tds

[![Hex.pm](https://img.shields.io/hexpm/v/tds.svg)](https://hex.pm/packages/tds) [![Build status](https://ci.appveyor.com/api/projects/status/aibnqbukppa3kcpt?svg=true)](https://ci.appveyor.com/project/mjaric/tds)

MSSQL / TDS Database driver for Elixir.

Supports Ecto 2.0. It implements the [db_connection](https://github.com/elixir-ecto/db_connection) behaviour and has support for transactions and prepared queries.

Please check out the issues for a more complete overview. This branch should not be considered stable or ready for production yet.

## Usage

As of TDS version `>= 1.2`, it requires `rust` to be installed for nif required to 
properly encode/decode `char`, `text` and `varchars`. In previous versions only 
SQL_Latin1_General was suported. Please follow instructions at [rust website](https://www.rust-lang.org/tools/install)


Add Tds as a dependency in your `mix.exs` file.

```elixir
def deps do
  [{:tds, "~> 1.2"}]
end
```

When you are done, run `mix deps.get` in your shell to fetch and compile Tds. Start an interactive Elixir shell with `iex -S mix`.

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

```elixr
import Mix.Config

config :your_app, tds_conn,
  hostname: "localhost", 
  username: "test_user", 
  password: "test_password", 
  database: "test_db", 
  port: 1433
```

Then using `Application.get_env(:your_app, :tds_conn)` use this as first parameter in `Tds.start_link/1` function.

There is additional parameter that can be used in configuration and 
can improve query execution in sql server. If you find out that 
your queries suffer form "denst estimation" as described [here](https://www.brentozar.com/archive/2018/03/sp_prepare-isnt-good-sp_executesql-performance/)

you can try switching  how tds executes queries as below:

```elixr
import Mix.Config

config :your_app, tds_conn,
  hostname: "localhost", 
  username: "test_user", 
  password: "test_password", 
  database: "test_db", 
  port: 1433,
  execution_mode: :executesql
```
This will skip calling `sp_prepare` and query will be executed using `sp_executesql` instead. Please note that only single  execution mode can be set at the time and SQL will probably use single execution plan (since it is NOT estimated by checking data density!).

## Connecting to SQL Instances

Tds supports SQL instances by passing `instance: "instancename"` to the connection options.
Since v1.0.16, additional connection parameters are:
  - `:set_language` - check stored procedure output `exec sp_helplanguage` name column value should be used here
  - `:set_datefirst` - number in range `1..7`
  - `:set_dateformat` - atom `:mdy | :dmy | :ymd | :ydm | :myd | :dym`
  - `:set_deadlock_priority` - one of `:low | :high | :normal | -10..10`
  - `:set_lock_timeout` - number in milliseconds > 0
  - `:set_remote_proc_transactions` - atom `:on | :off`
  - `:set_implicit_transactions` - atom `:on | :off`
  - `:set_transaction_isolation_level` - atom `:read_uncommitted | :read_committed | :repeatable_read | :snapshot | :serializable`
  - `:set_allow_snapshot_isolation` - atom `:on | :off`

Set this option to enable snapshot isolation on the database level. Requires connecting with a user with appropriate rights. More info [here](https://docs.microsoft.com/en-us/dotnet/framework/data/adonet/sql/snapshot-isolation-in-sql-server).

## Data representation

| TDS      | Elixir                                                         |
| -------- | -------------------------------------------------------------- |
| NULL     | nil                                                            |
| bool     | true / false                                                   |
| char     | "é"                                                            |
| int      | 42                                                             |
| float    | 42.0                                                           |
| text     | "text"                                                         |
| binary   | <<42>>                                                         |
| numeric  | #Decimal<42.0> *                                               |
| date     | {2013, 10, 12}                                                 |
| time     | {0, 37, 14}                                                    |
| datetime | {{2013, 10, 12}, {0, 37, 14}}                                  |
| uuid     | <<160,238,188,153,156,11,78,248,187,109,107,185,189,56,10,17>> |

Currently unsupported: [User-Defined Types](https://docs.microsoft.com/en-us/sql/relational-databases/clr-integration-database-objects-user-defined-types/working-with-user-defined-types-in-sql-server), XML

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

### SQL Server Setup

The tests require an sql server database to be available on localhost.

If you have Docker installed, you can use the official [SQL Server Docker image](https://hub.docker.com/r/microsoft/mssql-server-linux).
To start the container, run:

```bash
./docker-mssql.sh
```

If you prefer to install SQL Server directly on your computer, you can find
installation instructions here:

* [Windows](https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-from-the-installation-wizard-setup)
* [Linux](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup)

Make sure your SQL server accepts the credentials defined in `config/test.exs`.

You also will need to have the *sqlcmd* command line tools installed. Setup
instructions can be found [here](https://docs.microsoft.com/en-us/sql/linux/sql-server-linux-setup-tools).

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
