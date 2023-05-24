defmodule Tds.TypeInfo do
  @moduledoc """
  The information about a type that is provided to the custom encoder/decoder
  functions.

  This module will decode TDS type information so that it can be used by
  data decoding and encoding functions.

  SQL Server also support user defined types, where one could define custom type from
  builtin types. This definition will be transferred to user code as user type, still
  driver will be able to decode it to Elixir type before passing it to user code or
  extension. TDS library will not be able to decode user defined types, except if it
  builtin extension of TDS library, but it will always decode values to the system type.
  This will allow user to define custom extension for user defined types.

  ## Token definition
  TDS protocol defines four classes of token definitions, each class is stored in single byte:
    - Zero length token (0b__01____)
    - Fixed length token (0b__11____)
    - Variable length token (0b__10____)
    - Variable count token (0b__00____)

  Each token class has its own set of token types. Token type is defined by
  first 4 bits of token definition. Token type is used to define how to parse
  token data. Token type is also used to define how to encode token data.

  ### Zero length token (0b__01____)
  Zero length token is token that has no data. It is not followed by
  any length nor data. It is used to define token type only.

  Below is list of zero length tokens:
    - NULLTYPE = 0x1F (0b00011111, dec: 31) or **null** as user type, TDS lib will
      decode it to `nil`.

  ### Fixed length token (0b__11____)
  Fixed length token is token that has fixed length. It is not followed by length,
  but it is followed by data. The length of data is stored in token itself 4th and 5th bit of token byte.

  - If token type is 0b__1100___, then length is 1 byte.
  - If token type is 0b__1101___, then length is 2 bytes.
  - If token type is 0b__1110___, then length is 4 bytes.
  - If token type is 0b__1111___, then length is 8 bytes.

  Fixed-length tokens are used by the following data types: bigint, int, smallint, tinyint, float, real,
  money, smallmoney, datetime, smalldatetime, and bit. The type definition is always represented in
  COLMETADATA and ALTMEADATA data streams as single byte type identifier.

  Below is list of fixed length tokens:
  - INT1TYPE = 0x30 (0b00110000, dec: 48) or **tinyint** as user type, TDS lib will
    decode it to `integer` type
  - BITTYPE = 0x32 (0b00110010, dec: 50) or **bit** as user type, TDS lib will
    decode it to `boolean` type
  - INT2TYPE = 0x34 (0b00110100, dec: 52) or **smallint** as user type, TDS lib will
    decode it to `integer` type
  - INT4TYPE = 0x38 (0b00111000, dec: 56) or **int** as user type, TDS lib will
    decode it to `integer` type
  - DATETIM4TYPE = 0x3A (0b00111010, dec: 58) or **smalldatetime** as user type, TDS lib will
    decode it to tuple `{{year, month, day}, {hour, minute, 0, 0}}`
  - FLT4TYPE = 0x3B (0b00111011, dec: 59) or **real** as user type, TDS lib will
    decode it to `float` type
  - MONEYTYPE = 0x3C (0b00111100, dec: 60) or **money** as user type, TDS lib will
    decode it to `Decimal` type
  - DATETIMETYPE = 0x3D (0b00111101, dec: 61) or **datetime** as user type, TDS lib will
    decode it to tuple `{{year, month, day}, {hour, minute, second, usec}}` or as `NaiveDateTime` if
    Tds connection is congured with `use_elixir_calendar_types: true`
  - FLT8TYPE = 0x3E (0b00111110, dec: 62) or **float** as user type, TDS lib will
    decode it to `float()` type
  - MONEY4TYPE = 0x7A (0b01111010, dec: 122) or **smallmoney** as user type, TDS lib will
    decode it to `Decimal` type
  - INT8TYPE = 0x7F (0b01111111, dec: 127) or **bigint** as user type, TDS lib will
    decode it to `integer()` type
  - DECIMALTYPE = 0x37 (0b00110111, dec: 55) or **decimal** as user type, TDS lib will
    decode it to `Decimal` type (this is legacy type, use NUMERICN instead)
  - NUMERICNTYPE = 0x3F (0b00111111, dec: 63) or **numeric** as user type, TDS lib will
    decode it to `Decimal` type (this is legacy type, use NUMERICN instead)

  Non-nullable values are returned using these fixed-length data types. For the fixed-length
  data types, the length of data is predefined by the type. There is no TYPE_VARLEN field in
  the TYPE_INFO rule for these types. In the TYPE_VARBYTE rule for these types, the
  TYPE_VARLEN field is BYTELEN, and the value is:
  - 1 for INT1TYPE, BITTYPE
  - 2 for INT2TYPE
  - 4 for INT4TYPE, DATETIM4TYPE, FLT4TYPE, MONEY4TYPE
  - 8 for MONEYTYPE, DATETIMETYPE, FLT8TYPE, INT8TYPE.

  The value represents the number of bytes of data to be followed. The SQL data types of
  the corresponding fixed-length data types are in the comment part of each data type.

  ### Variable length token (0b__10____)
  Except as noted later in this section, this class of token definition is followed by a
  length specification. The length, in bytes, of this length is included in the token
  itself as a Length value.

  ### Variable count token (0b__00____)
  This class of token definition is followed by a count of the number of
  fields that follow that token. Each field length is dependent on the token type. This class is used
  only by the COLMETADATA data stream.
  """

  # @doc """
  # Decodes the TYPE_INFO from TDS packet data token stream. Describes
  # type for interpretation of the following data stream tokens.
  # """
end
