# Tds

MSSQL / TDS Database driver for Elixir.

## Usage

Add Tds as a dependency in your `mix.exs` file.

```elixir
def deps do
  [{:tds, "~> 0.5.4"} ]
end
```

After you are done, run `mix deps.get` in your shell to fetch and compile Tds. Start an interactive Elixir shell with `iex -S mix`.

```iex
iex> {:ok, pid} = Tds.Connection.start_link([hostname: "localhost", username: "test_user", password: "test_password", database: "test_db", port: 4000])
{:ok, #PID<0.69.0>}
iex> Tds.Connection.query(pid, "SELECT 'Some Awesome Text' AS MyColumn", [])
%Tds.Result{columns: ["MyColumn"], rows: [{"Some Awesome Text"}], num_rows: 1}}
iex> Tds.Connection.query(pid, "INSERT INTO MyTable (MyColumn) VALUES (@my_value)", [%Tds.Parameter{name: "@my_value", value: "My Actual Value"}])
%Tds.Result{columns: nil, rows: nil, num_rows: 1}}
```

## Features

  * Automatic decoding and encoding of Elixir values to and from MSSQL's binary format
  * Supports TDS Version 7.3, 7.4

## Connecting to SQL Instances
Tds Supports sql instances by passing ```instance: "instancename"``` to the connection options.



## Data representation

    TDS             Elixir
    ----------      ------
    NULL            nil
    bool            true | false
    char            "é"
    int             42
    float           42.0
    text            "text"
    binary          <<42>>
    numeric         #Decimal<42.0> *
    date            {2013, 10, 12}
    time            {0, 37, 14}
    datetime	      {{2013, 10, 12}, {0, 37, 14}}
    uuid            <<160,238,188,153,156,11,78,248,187,109,107,185,189,56,10,17>>

All data types will be supported, unsupported types currently are udt, xml

## Contributing

To contribute you need to compile Tds from source and test it:

```
$ git clone https://github.com/livehelpnow/tds.git
$ cd tds
$ mix test
```

The tests require an addition to your hosts file to connect to your sql server database.

<IP OF SQL SERVER>	sqlserver.local

Additionally SQL authentication needs to be used for connecting and testing. Add the user test_user as owner to the database test_db. See one of the test files for the connection information and port number.

##Special Thanks

Thanks to ericmj, this driver takes a lot of inspiration from postgrex.
https://github.com/ericmj/


Also thanks to everyone in the Elixir Gogle group and on the Elixir IRC Channel


## License

   Copyright 2014, 2015 LiveHelpNow

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
