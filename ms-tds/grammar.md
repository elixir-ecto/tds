# TDS Protocol Grammar

## Data Stream Types

### Unknown Length Data Streams

```
BYTESTREAM          = *BYTE
UNICODESTREAM       = *(2BYTE)
```

### Variable-Length Data Streams

```
B_VARCHAR           = BYTELEN *CHAR
US_VARCHAR          = USHORTLEN *CHAR
```
_NOTE: that the lengths of B_VARCHAR and US_VARCHAR are given in Unicode characters._

### Generic Bytes

```
B_VARBYTE           = BYTELEN *BYTE
US_VARBYTE          = USHORTLEN *BYTE
L_VARBYTE           = LONGLEN *BYTE

```

```
B_VARCHAR           = BYTELEN *CHAR
US_VARCHAR          = USHORTLEN *CHAR

B_VARBYTE           = BYTELEN *BYTE
US_VARBYTE          = USHORTLEN *BYTE
L_VARBYTE           = LONGLEN *BYTE
```

## Data Type Dependent Data Streams
Some messages contain variable data types. The actual type of a given variable data type is dependent on the type of the data being sent within the message as defined in the `TYPE_INFO` rule.
For example, the *RPCRequest* message contains the `TYPE_INFO` and `TYPE_VARBYTE` rules. These two rules contain data of a type that is dependent on the actual type used in the value of the `FIXEDLENTYPE` or `VARLENTYPE` rules of the `TYPE_INFO` rule.
Data type-dependent data streams occur in three forms: integers, fixed and variable bytes, and partially length-prefixed bytes.

### INTEGERS
```
TYPE_VARLEN         = BYTELEN / USHORTCHARBINLEN / LONGLEN
```

### Fixed and Variable Bytes
```
TYPE_VARBYTE        = GEN_NULL / CHARBIN_NULL / PLP_BODY / ([TYPE_VARLEN] *BYTE)
```

### Partially Length-prefixed Bytes (PARTLENTYPE)
```
PLP_BODY            = PLP_NULL / 
                      ((ULONGLONGLEN / UNKNOWN_PLP_LEN) *PLP_CHUNK PLP_TERMINATOR)

PLP_NULL            = 0xFFFFFFFFFFFFFFFF
UNKNOWN_PLP_LEN     = 0xFFFFFFFFFFFFFFFE
PLP_CHUNK           = ULONGLEN 1*BYTE
PLP_TERMINATOR      = 0x00000000
```


## Packet Data Stream Headers - ALL_HEADERS Rule Definition

Message streams can be preceded by a variable number of headers as specified by the `ALL_HEADERS` rule. The `ALL_HEADERS` rule, the **Query Notifications** header, and the **Transaction Descriptor** header were introduced in TDS 7.2. The **Trace Activity** header was introduced in TDS 7.4.

| Header                |  Value   |  SQLBatch | RPCRequest | TransactionManagerRequest |
|-----------------------|----------|-----------|------------|---------------------------|
| Query Notifications   |  0x00 01 | Optional  |  Optional  | Dissallowed               |
| col 2 is              |  0x00 02 | Required  |  Required  | Required                  |
| col 3 is              |  0x00 03 | Optional  |  Optional  | Optional                  |

Stream-Specific Rules:
```
TotalLength         = DWORD    ;including itself
HeaderLength        = DWORD    ;including itself
HeaderType          = USHORT;
HeaderData          = *BYTE
Header              = HeaderLength HeaderType HeaderData
```

Stream Definition:

```
ALL_HEADERS         = TotalLength 1*Header
```

### Query Notifications Header

This packet data stream header allows the client to specify that a notification is to be supplied on the results of the request. The contents of the header specify the information necessary for delivery of the notification. For more information about query notifications functionality for a database server that supports SQL, see [MSDN-QUERYNOTE](https://go.microsoft.com/fwlink/?LinkId=119984).

Stream Specific Rules:
```
NotifyId            = USHORT UNICODESTREAM  ; user specified value 
                                            ; when subscribing to
                                            ; query notifications
SSBDeployment       = USHORT UNICODESTREAM
NotifyTimeout       = ULONG                 ; duration (in milliseconds) 
                                            ; in which the query notification
                                            ; subscription is valid 
```
The USHORT field defined within the NotifyId and SSBDeployment rules specifies the length, in bytes, of the actual data value, defined by the UNICODESTREAM.

Stream Definition:
```
HeaderData       =   NotifyId SSBDeployment [NotifyTimeout]
```

### Transaction Descriptor Header

This packet data stream contains information regarding transaction descriptor and number of outstanding requests as they apply to **Multiple Active Result Sets (MARS)** 
[MSDN-MARS](https://go.microsoft.com/fwlink/?LinkId=98459).
The TransactionDescriptor MUST be 0, and OutstandingRequestCount MUST be 1 if the connection is operating in AutoCommit mode. For more information about autocommit transactions, see [MSDN- Autocommit](https://go.microsoft.com/fwlink/?LinkId=145156).

Stream-Specific Rules:
```
OutstandingRequestCount = DWORD         ; number of requests currently active on 
                                        ; the connection
TransactionDescriptor   = ULONGLONG     ; for each connection, a number that uniquely 
                                        ; identifies the transaction with which the
                                        ; request is associated
                                        ; initially generated 
                                        ; by the server when a new transaction is
                                        ; created and returned to the client as part 
                                        ; of the ENVCHANGE token stream
```

Strem Definition:
```
HeaderData          = TransactionDescriptor OutstandingRequestCount
```

### Trace Activity Header
This packet data stream contains a client trace activity ID intended to be used by the server for debugging purposes, to allow correlating the server's processing of the request with the client request.

A client MUST NOT send a Trace Activity header when the negotiated TDS major version is less than 7.4. If the negotiated TDS major version is less than TDS 7.4 and the server receives a Trace Activity header token, the server MUST reject the request with a TDS protocol error.

Stream-Specific Rules:
```
GUID_ActivityID     = 16bytes   ; client application activity id 
                                ; used for debugging purposes
ActivitySequence    = ULONG     ; client application activity sequence
                                ; used for debugging purposes
```

Stream Definition:
```
HeaderData          =   ActivityId
```

## Data Type Definitions

The subsections within this section describe the different sets of data types and how they are categorized. Specifically, data values are interpreted and represented in association with their data type. Details about each data type categorization are described in the following sections.

### Fixed-Length Data Types (FIXEDLENTYPE)

```
NULLTYPE            =   0x1F  ; Null
                              ; NULLTYPE can be sent to SQL Server 
                              ; (for example, in RPCRequest), 
                              ; but SQL Server never emits NULLTYPE data.
INT1TYPE            =   0x30  ; TinyInt
BITTYPE             =   0x32  ; Bit
INT2TYPE            =   0x34  ; SmallInt
INT4TYPE            =   0x38  ; Int
DATETIM4TYPE        =   0x3A  ; SmallDateTime
FLT4TYPE            =   0x3B  ; Real
MONEYTYPE           =   0x3C  ; Money
DATETIMETYPE        =   0x3D  ; DateTime
FLT8TYPE            =   0x3E  ; Float
MONEY4TYPE          =   0x7A  ; SmallMoney
INT8TYPE            =   0x7F  ; BigInt

FIXEDLENTYPE        = NULLTYPE / INT1TYPE / BITTYPE / INT2TYPE / INT4TYPE /
                      DATETIM4TYPE / FLT4TYPE / MONEYTYPE / DATETIMETYPE /
                      FLT8TYPE / MONEY4TYPE / INT8TYPE
```
### Variable-Length Data Types (VARLENTYPE)
```
GUIDTYPE            =   0x24    ; UniqueIdentifier
                                ;   GEN_NULL  NULL     ( 0bytes)
                                ;   0x10 NOT  NULL (16bytes)
INTNTYPE            =   0x26    ; TinyInt | SmallInt | Int | BigInt
                                ;   GEN_NULL  NULL
                                ;   0x01      TinyInt
                                ;   0x02      SmallInt
                                ;   0x04      Int
                                ;   0x08      BigInt
DECIMALTYPE         =   0x37    ; Decimal (legacy support)
NUMERICTYPE         =   0x3F    ; Numeric (legacy support)
BITNTYPE            =   0x68    ; (see below)
                                ; GEN_NULL  NULL
                                ; 0x01      NOT NULL
DECIMALNTYPE        =   0x6A    ; Decimal
NUMERICNTYPE        =   0x6C    ; Numeric
FLTNTYPE            =   0x6D    ; (see below)
                                ; GEN_NULL  NULL
                                ; 0x04      precision 7 Float
                                ; 0x08      precision 15 Float
MONEYNTYPE          =   0x6E    ; (see below)
                                ; GEN_NULL  NULL
                                ; 0x04      SmallMoney
                                ; 0x08      Money
DATETIMNTYPE        =   0x6F    ; (see      below)
                                ; GEN_NULL  NULL
                                ; 0x4       SmallDateTime
                                ; 0x8       DateTime
DATENTYPE           =   0x28    ; (introduced in TDS 7.3)
                                ; 0x00 NULL
                                ; 0x03 NOT NULL
TIMENTYPE           =   0x29    ; (introduced in TDS 7.3)
                                ; |scale | length |
                                ; |------|--------|
                                ; |1     | 0x03   |
                                ; |2     | 0x03   |
                                ; |3     | 0x04   |
                                ; |4     | 0x04   |
                                ; |5     | 0x05   |
                                ; |6     | 0x05   |
                                ; |7     | 0x05   |
DATETIME2NTYPE      =   0x2A    ; (introduced in TDS 7.3)
                                ; |scale | length |
                                ; |------|--------|
                                ; |1     | 0x06   |
                                ; |2     | 0x06   |
                                ; |3     | 0x07   |
                                ; |4     | 0x07   |
                                ; |5     | 0x08   |
                                ; |6     | 0x08   |
                                ; |7     | 0x08   |
DATETIMEOFFSETNTYPE =   0x2B    ; (introduced in TDS 7.3)
                                ; |scale | length |
                                ; |------|--------|
                                ; |1     | 0x08   |
                                ; |2     | 0x08   |
                                ; |3     | 0x09   |
                                ; |4     | 0x09   |
                                ; |5     | 0x0A   |
                                ; |6     | 0x0A   |
                                ; |7     | 0x0A   |
CHARTYPE            =   0x2F    ; Char (legacy support)
VARCHARTYPE         =   0x27    ; VarChar (legacy support)
BINARYTYPE          =   0x2D    ; Binary (legacy support)
VARBINARYTYPE       =   0x25    ; VarBinary (legacy support)
BIGVARBINTYPE       =   0xA5    ; VarBinary
BIGVARCHRTYPE       =   0xA7    ; VarChar
BIGBINARYTYPE       =   0xAD    ; Binary
BIGCHARTYPE         =   0xAF    ; Char
NVARCHARTYPE        =   0xE7    ; NVarChar
NCHARTYPE           =   0xEF    ; NChar
XMLTYPE             =   0xF1    ; XML (introduced in TDS 7.2)
UDTTYPE             =   0xF0    ; CLR UDT (introduced in TDS 7.2)



TEXTTYPE            = 0x23 ; Text
IMAGETYPE           = 0x22 ; Image
NTEXTTYPE           = 0x63 ; NText
SSVARIANTTYPE       = 0x62 ; Sql_Variant (introduced in TDS 7.2)
```

Associated length value type: 

```
BYTELEN_TYPE        = GUIDTYPE / INTNTYPE / DECIMALTYPE /
                      NUMERICTYPE / BITNTYPE / DECIMALNTYPE /
                      NUMERICNTYPE / FLTNTYPE / MONEYNTYPE /
                      DATETIMNTYPE / DATENTYPE / TIMENTYPE /
                      DATETIME2NTYPE / DATETIMEOFFSETNTYPE /
                      CHARTYPE / VARCHARTYPE / BINARYTYPE /
                      VARBINARYTYPE 
                            ; the length value associated with these data
                            ; types is specified within a BYTE

USHORTLEN_TYPE      = BIGVARBINTYPE / BIGVARCHRTYPE / BIGBINARYTYPE / 
                      BIGCHARTYPE / NVARCHARTYPE / NCHARTYPE
                            ; the length value associated with 
                            ; these data types is specified
                            ; within a USHORT
LONGLEN_TYPE        = (IMAGETYPE / NTEXTTYPE / SSVARIANTTYPE / TEXTTYPE / XMLTYPE)
                            ; the length value associated with
                            ; these data types is specified
                            ; within a LONG
```

Notes:
* `MaxLength` for an `SSVARIANTTYPE` is 8009 (8000 for strings)
* `XMLTYPE` is only a valid `LONGLEN_TYPE` for `BulkLoadBCP`

```
VARLENTYPE          = BYTELEN_TYPE / USHORTLEN_TYPE / LONGLEN_TYPE
```