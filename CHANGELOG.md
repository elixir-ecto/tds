# v2.1.3
### BugFix
* Values in `datetimeoffset(n)` columns were failing to decode on match error due to offset unit mismatch (seconds != minutes).
* Values in `datetimeoffset(n)` columns of non-UTC timezones were not encoded/decoded correctly.

# v2.1.2
### BugFix
* Resolves [PR #115](https://github.com/livehelpnow/tds/pull/115). Thank you, [Chris Martin](https://github.com/trbngr)
* Fix double incrementing of the packet number [PR #117](https://github.com/livehelpnow/tds/pull/117). Thank you, [DJ Jani](https://github.com/deepankar-j)


# v2.1.1
### Improvements
* As per discussion [here](https://github.com/livehelpnow/tds/issues/108) exposed 
`Tds.query_multi/4` that should return complete resultset rather than single `%Tds.Result{}` 
so one can run multiple batches in single statement

# v2.1.0
### BugFix
* ColMetadata token that contains XML schema_info now is parsed correctly.

### Improvements
* Improved compatibiliy with `ecto_sql` TDS adapter
* Removed `Tds.Types.VarChar`. From now `ecto_sql` implements `Tds.Ecto.VarChar` that should be used in
fields if schema requires it.
* `Tds.Type.UUID` is moved to `ecto_sql` please use `Tds.Ecto.UUID` instead if you are using ecto.
* `Tds.generate_uuid/0` is added so users can generate valid binary MS UUIDS, 
there is also `Tds.decode_uuid/1` that should help parsing MS UUID binary to its string representation
* `sp_execute` is now using **PROCID** in protocol so message size is reduced for few bytes
* In explicit transactions (`Tds.transaction/2`) now you can tell transaction manager what isolation level you need. 
You are encaruadged to use this instead of `SET TRANSACTION ISOLATION LEVEL ...` due:
  - Less roundtrips to database (saving 3 RPC calls)
  - Less bytes are sent over wire since all is in single transaction manager call
  - snapshot isolation level works in combination with connection settings `set_allow_snapshot_isolation: :on`
* Elixir calendar types are supported if connection is configured with `use_elixir_calendar_types: true`, 
columns that are of sql types `SmallDateTime`, `DateTime`, `DateTime2`, `DateTimeOffset`, `Time` and `Date` will be 
decoded into elixir `NaiveDateTime`, `DateTime`, `Time` and `Date`. If this falg is not set to connection tuples will be used.
* Rustler dependency is not mandatory anymore. Requirements are muved to `tds_encoding` library. If you need non latin1 encoding 
for your varchars please add this library to your dependency and add in configuration `config :tds, :text_encoder, Tds.Encoding`

# v2.0.1-rc1
### Breaking changes
In order to improve compatibility with `ecto_sql`, following breaking changes are introduced in this release:
* Since `tds_ecto` package is deprecated and adapter is moving to `ecto_sql`, use `Tds.Types.UUID` for 
column types `binary_id` (`uuid`). 
* For same reason as above `Tds.VarChar` is now `Tds.Types.VarChar`
* If you are using collation other than Latin1 please add dependency to `:tds_encoding` package and followin instructions
in readme on how to configure tds to use this encoder.

# v1.2.0
### Improvements
- `char`, `nchar`, `text`, `ntext`, `varchar` and `nvarchar` encoding improvements 
for most of the SQL collations. More will be supported.

# v1.1.7
### Bugfix
- Fix for "Error with set_transaction_isolation_level: :read_uncommited" [issue #72](https://github.com/livehelpnow/tds_ecto/issues/72) 


# v2.0.0
### Improvements:
* Implements DBConnection v2.0 to support `ecto_sql`. Please note that starting from this version [tds_ecto](https://hex.pm/packages/tds_ecto) is not improved anymore and will not use tds version 2.0.0+, instead use [ecto_sql](https://hex.pm/packages/ecto_sql) where tds_ecto will become part of it starting from version 3.1.0.


# v1.1.5
### Improvements
* Allow users to choose between `:prepare_execute` and `:executesql` style (PR #71) default is `:prepare_execute`
* Fix unnecessary append of possibly large binaries #70
### Bugfix
* Unexpected Environment Change message kills the connection #72

# v1.1.4
### Improvements
* Adding `sp_unprepare` after SQL statement is executed.

# v1.1.3
### Improvements
* Improving traceability. Adding hostname and application/program name to login7 tds package so one could easier trace rpc calls in SQL Server. Program name is equal to FQ erlang node name, while hostname is what ever :inet.gethostname() returns. May fail to connect if `:inet` is unable to read hostname.

# v1.1.2
### Bugfix
* Float loses precision. Fix will force floats to be encoded as 64bit floats and param type as float(53) in order to keep all bits
* Fix for: Rollback is called twice on failure in explicit transaction. (DBConnection [mode: :savepoint] support)
  
# v1.1.0
## Breaking Changes
UUID/UNIQUEIDENTIFER column is now stored AS IS in database, meaning that compatibility with Ecto.UUID is broken, 
if you are using `tds_ecto` please use Tds.UUID to encode/decode value to its sting representation. MSSQL has its way of 
parsing binary UUID value into string representation as following string illustration:

  Ecto.UUID string representation:
  `f72f71ce-ee18-4db3-74d9-f5662a7691b8`

  MSSQL string representation:
  `ce712ff7-18ee-b34d-74d9-f5662a7691b8`

To allow other platforms to interprect corectly uuids we had to introduce 
`Tds.UUID` in `tds_ecto` library and `Tds.Types.UUID` in `tds` both are trying to 
keep binary storage in valid byte order so each platform can corectly decode it into string.
So far unique identifiers were and will be returned in resultset as binary, if you need to convert it into 
formatted string, use `Tds.Types.UUID.parse(<<_::128>>=uuid)` to get that string. 
It is safe to call this function several times since it will not fail if value is valid uuid string,
it will just return same value. But if value do not match `<<_::128>>` or 
`<<a::32, ?-, b::16, ?-, c::16, ?- d::16, ?-, e::48>>` it will throw runtime error. 

If you are using `tds_ecto` :uuid, :binary_id, and Tds.UUID are types you want to use in your models.
For any of those 3 types auto encode/decode will be performed.

Since there was a bug where in some cases old version of `tds_ecto` library 
could not detemine if binary is of uuid type, it interpeted such values as raw binary which caused some issues when non elixir apps interpreted that binary in wrong string format. This was ok as long as parsed string values were not shared between elixir and other platforms trough e.g. json messages, but if they did, this could be a problem where other app is not kapable to find object which missparsed uuid value.

# v1.0.17
### Bugfix
* Fixing missing case when string/varchar length is between 2_000 and 4_000 characters long.

# v1.0.17
### Bugfix
* Fix for SET TRANSACTION_ISOLATION_LEVEL issue

# v1.0.16
### Improvements
* expsing connection options such as:
  * set_language - check stored procedure `sp_helplanguage` name column value should be used here
  * set_datefirst - number in range `1..7`
  * set_dateformat - atom `:mdy | :dmy | :ymd | :ydm | :myd | :dym`
  * set_deadlock_priority - one of `:low | :high | :normal | -10..10`
  * set_lock_timeout - number in milliseconds > 0
  * set_remote_proc_transactions - atom :on | :off
  * set_implicit_transactions - atom :on | :off
  * set_transaction_isolation_level - atom :read_uncommited | :read_commited | :repeatable_read | :snapshot | :serializable
  * set_allow_snapshot_isolation - atom :on | :off

# v1.0.14
* Improvents
* Handle Azure redirecting to new host after env_change token on login #61
# v1.0.14

### Improvements
* Parameters `:string`, `:varchar` and `:binary` are encoded as `nvarchar(max)`, `varchar(max)` and `varbinary(max)` when string or binary length is greater than 2000, otherwise `nvarchar(2000)`, `varchar(2000)` and `varbinary(2000)`. This change is added to avoid agresive execution plan caching on SQL Server since parameters may often vary in length, so SQL server will makes execution plan for each parameter lenght case.
    
# v1.0.13
### Bugfix
  * issue #62 fixing info message token parsing

# v1.0.12
### Bugfix
  * issue #59 fixing login error when database name contains special characters like "-"

# v1.0.11
### Bugfix
  * fixing issue with done in proc token when stored pcedure is executed

# v1.0.10
### Bugfix
  * fixing negative integer/bigint encoding

# v1.0.9
### Bugfix
  * Removing obsolete reply function which causing error when connection can not be established to server

# v1.0.8
### Bugfix
  * Fixing handle 0 error

# v1.0.7
### Bugfix
  * Ping timout caused process to crash

# v1.0.6
### Bugfix
  * Double precision floats fix

# v1.0.5
### Bugfix
  * StaleEntity error fix when row is inserted into table and done token is incorectlly parsed
  * fixing resultset order

# v1.0.3
### Bugfix
  * When insert is performed with output incorect row count is calucated. Causing tds_ecto and ecto to think it is StaleEntity

# v0.5.4
### Enhancements
  * Cleaned up code style for Elixir 1.2.0 warnings

# v0.5.3
### Enhancements
  * Loosen Elixir dependency

# v0.5.2
### Bug Fixes
  * If server outputs warning result rows are missing.

# v0.5.1
### Bug Fixes
  * Added token decoder for return status of RPC

# v0.5.0
* Backwards Incompatable Changes
  * Rows now return as list instead of tuple

# v0.4.0
* Backwards Incompatable Changes
  * datetime tuples are now {{year,month,day},{hour,min,sec,usec}}

# v0.3.0
### Enhancements
  * Added parameter encoding support for datetime2
  * Removed dependency on Timex

# v0.2.8
### Bug Fixes
  * Fixed issue where tail would time out queries randomly

# v0.2.7
### Enhancements
  * Added ability to pass socket options to connect.
  * Set internal socket buffer.

# v0.2.6
### Bug Fixes
  * Fixed issue where messages spanning multiple packets might not finish

# v0.2.5
### Bug Fixes
  * Enum error when calling ATTN on server

# v0.2.4
### Bug Fixes
  * Added support for DateTimeOffset
  * Updated Deps

# v0.2.3
### Bug Fixes
  * Added Long Length decoder support for text, ntext and image
  * Fixed PLP decode / Encode for sending and receiving large test
  * Fixed issue where selecting from NTEXT, TEXT, NVARCHAR(MAX), VARCHAR(MAX) would trunc to 4kb

# v0.2.2
### Bug Fixes
  * Fixed udp port scope for instances

# v0.2.1
### Bug Fixes
  * Fixed: Packets sent to the server which exceed the negotiated packet size would cause the connection to close
### Enhancements
  * Added support for decoding Time(n) and DateTime2
  * Added support for SQL Named Instances, pass instance: "instance_name" in connection options

# v0.2.0
### Enhancements
  * Added SET defaults upon connection of:
    SET ANSI_NULLS ON;
    SET QUOTED_IDENTIFIER ON;
    SET CURSOR_CLOSE_ON_COMMIT OFF;
    SET ANSI_NULL_DFLT_ON ON;
    SET IMPLICIT_TRANSACTIONS OFF;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET CONCAT_NULL_YIELDS_NULL ON;

### Bug Fixes
  * Fixed issue with empty strings and binaries being converted to nil

### Enhancements
  * datetime2 with 0 usec's will be transmitted as datetime

* Backwards incompatable changes
  * Changed datetime to be passed back as {{year, month, day} ,{hour, min, sec, microsec}}

# v0.1.6
### Bug Fixes
  * Changed default connection timeout to 5000 from :infinity
  * Added caller pid monitoring to cancel query if caller dies
  * Call ATTN if the caller who dies is the currently executing query

### Enhancements
  * Added API for ATTN call

# v0.1.5
### Bug Fixes
  * Fixed issue where driver would not call Connection.next when setting the state to :ready
  * Fixed UCS2 Encoding

# v0.1.4
### Bug Fixes
  * Fixed encoding for integers

# v0.1.3
### Bug Fixes
  * Removed Timer from queued commands.
  * Changed error handling to error func

# v0.1.2
### Bug Fixes
  * Adding missing date time decoders
  * Compatibility updates for ecto

# v0.1.1
### Bug Fixes
  * Fixed issue with Bitn always returning true
  * Fixed missing data return for char data decoding
  * Added float encoders

### General
  * Cleaned up logger functions

# v0.1.0 (2015-02-02)
* First Release
