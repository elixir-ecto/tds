# v1.0.17
* bugfix
  - Fixing missing case when string/varchar length is between 2_000 and 4_000 characters long.

# v1.0.17
* Bugfix
  - Fix for SET TRANSACTION_ISOLATION_LEVEL issue

# v1.0.16
* Improvements
  - expsing connection options such as:
    - set_language - check stored procedure `sp_helplanguage` name column value should be used here
    - set_datefirst - number in range `1..7`
    - set_dateformat - atom `:mdy | :dmy | :ymd | :ydm | :myd | :dym`
    - set_deadlock_priority - one of `:low | :high | :normal | -10..10`
    - set_lock_timeout - number in milliseconds > 0
    - set_remote_proc_transactions - atom :on | :off
    - set_implicit_transactions - atom :on | :off
    - set_transaction_isolation_level - atom :read_uncommited | :read_commited | :repeatable_read | :snapshot | :serializable
    - set_allow_snapshot_isolation - atom :on | :off

# v1.0.14
* Improvents
  - Handle Azure redirecting to new host after env_change token on login #61
# v1.0.14

* Improvements
  - Parameters `:string`, `:varchar` and `:binary` are encoded as `nvarchar(max)`, `varchar(max)` and `varbinary(max)` when string or binary length is greater than 2000, otherwise `nvarchar(2000)`, `varchar(2000)` and `varbinary(2000)`. This change is added to avoid agresive execution plan caching on SQL Server since parameters may often vary in length, so SQL server will makes execution plan for each parameter lenght case.
    
# v1.0.13
* BugFix
  * issue #62 fixing info message token parsing

# v1.0.12
* BugFix
  * issue #59 fixing login error when database name contains special characters like "-"

# v1.0.11
* BugFix
  * fixing issue with done in proc token when stored pcedure is executed

# v1.0.10
* BugFix
  * fixing negative integer/bigint encoding

# v1.0.9
* BugFix
  * Removing obsolete reply function which causing error when connection can not be established to server

# v1.0.8
* BugFix
  * Fixing handle 0 error

# v1.0.7
* BugFix
  * Ping timout caused process to crash

# v1.0.6
* BugFix
  * Double precision floats fix

# v1.0.5
* BugFix
  * StaleEntity error fix when row is inserted into table and done token is incorectlly parsed
  * fixing resultset order

# v1.0.3
* BugFix
  * When insert is performed with output incorect row count is calucated. Causing tds_ecto and ecto to think it is StaleEntity

# v0.5.4
* Enhancements
  * Cleaned up code style for Elixir 1.2.0 warnings

# v0.5.3
* Enhancements
  * Loosen Elixir dependency

# v0.5.2
* Bug Fixes
  * If server outputs warning result rows are missing.

# v0.5.1
* Bug Fixes
  * Added token decoder for return status of RPC

# v0.5.0
* Backwards Incompatable Changes
  * Rows now return as list instead of tuple

# v0.4.0
* Backwards Incompatable Changes
  * datetime tuples are now {{year,month,day},{hour,min,sec,usec}}

# v0.3.0
* Enhancements
  * Added parameter encoding support for datetime2
  * Removed dependency on Timex

# v0.2.8
* Bug Fixes
  * Fixed issue where tail would time out queries randomly

# v0.2.7
* Enhancements
  * Added ability to pass socket options to connect.
  * Set internal socket buffer.

# v0.2.6
* Bug Fixes
  * Fixed issue where messages spanning multiple packets might not finish

# v0.2.5
* Bug Fixes
  * Enum error when calling ATTN on server

# v0.2.4
* Bug Fixes
  * Added support for DateTimeOffset
  * Updated Deps

# v0.2.3
* Bug Fixes
  * Added Long Length decoder support for text, ntext and image
  * Fixed PLP decode / Encode for sending and receiving large test
  * Fixed issue where selecting from NTEXT, TEXT, NVARCHAR(MAX), VARCHAR(MAX) would trunc to 4kb

# v0.2.2
* Bug Fixes
  * Fixed udp port scope for instances

# v0.2.1
* Bug Fixes
  * Fixed: Packets sent to the server which exceed the negotiated packet size would cause the connection to close
* Enhancements
  * Added support for decoding Time(n) and DateTime2
  * Added support for SQL Named Instances, pass instance: "instance_name" in connection options

# v0.2.0
* Enhancements
  * Added SET defaults upon connection of
    SET ANSI_NULLS ON;
    SET QUOTED_IDENTIFIER ON;
    SET CURSOR_CLOSE_ON_COMMIT OFF;
    SET ANSI_NULL_DFLT_ON ON;
    SET IMPLICIT_TRANSACTIONS OFF;
    SET ANSI_PADDING ON;
    SET ANSI_WARNINGS ON;
    SET CONCAT_NULL_YIELDS_NULL ON;

* Bug Fixes
  * Fixed issue with empty strings and binaries being converted to nil

* Enhancements
  * datetime2 with 0 usec's will be transmitted as datetime

* Backwards incompatable changes
  * Changed datetime to be passed back as {{year, month, day} ,{hour, min, sec, microsec}}

# v0.1.6
* Bug Fixes
  * Changed default connection timeout to 5000 from :infinity
  * Added caller pid monitoring to cancel query if caller dies
  * Call ATTN if the caller who dies is the currently executing query

* Enhancements
  * Added API for ATTN call

# v0.1.5
* Bug Fixes
  * Fixed issue where driver would not call Connection.next when setting the state to :ready
  * Fixed UCS2 Encoding

# v0.1.4
* Bug Fixes
  * Fixed encoding for integers

# v0.1.3
* Bug Fixes
  * Removed Timer from queued commands.
  * Changed error handling to error func

# v0.1.2
* Bug Fixes
  * Adding missing date time decoders
  * Compatibility updates for ecto

# v0.1.1
* Bug Fixes
  * Fixed issue with Bitn always returning true
  * Fixed missing data return for char data decoding
  * Added float encoders

* General
  * Cleaned up logger functions

# v0.1.0 (2015-02-02)
* First Release
