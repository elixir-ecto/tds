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
