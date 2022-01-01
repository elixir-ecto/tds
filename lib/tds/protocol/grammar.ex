defmodule Tds.Protocol.Grammar do
  @moduledoc """
  Grammar Definition for Token Description, General Rules.

  Data structure encodings in TDS are defined in terms of the
  fundamental definitions.
  """

  @doc """
  A single bit value of either 0 or 1.
  """
  defmacro bit(n \\ 1), do: quote(do: size(1) - unit(unquote(n)))

  @doc """
  An unsigned single byte (8-bit) value.

  The range is 0 to 255.
  """
  defmacro byte(n \\ 1), do: quote(do: unsigned - size(unquote(n)) - unit(8))

  @doc """
  An unsigned single byte (8-bit) value representing the length of the
  associated data.

  The range is 0 to 255.
  """
  defmacro bytelen, do: quote(do: little - unsigned - 8)

  @doc """
  An unsigned 2-byte (16-bit) value.

  The range is 0 to 65535.
  """
  defmacro ushort,
    do: quote(do: unsigned - integer - size(8) - unit(2))

  @doc """
  A signed 4-byte (32-bit) value.

  The range is -(2^31) to (2^31)-1.
  """
  defmacro long, do: quote(do: signed - 32)

  @doc """
  An unsigned 4-byte (32-bit) value.

  The range is 0 to (2^32)-1.
  """
  defmacro ulong, do: quote(do: unsigned - 32)

  @doc """
  An unsigned 4-byte (32-bit) value.

  The range when used as a numeric value is 0 to (2^32)- 1.
  """
  defmacro dword, do: quote(do: unsigned - 32)

  @doc """
  A signed 8-byte (64-bit) value.

  The range is –(2^63) to (2^63)-1.
  """
  defmacro longlong, do: quote(do: signed - 64)

  @doc """
  An unsigned 8-byte (64-bit) value.

  The range is 0 to (2^64)-1.
  """
  defmacro ulonglong, do: quote(do: unsigned - 64)

  @doc """
  An unsigned single byte (8-bit) value representing a character.

  The range is 0 to 255.
  """
  defmacro uchar(n \\ 1),
    do: quote(do: unsigned - size(unquote(n)) - unit(8))

  @doc """
  An unsigned 2-byte (16-bit) value representing the length of the associated
  data.

  The range is 0 to 65535.
  """
  defmacro ushortlen, do: quote(do: little - unsigned - integer - 16)

  @doc """
  An unsigned 2-byte (16-bit) value representing the length of the associated
  character or binary data.

  The range is 0 to 8000.
  """
  defmacro ushortcharbinlen, do: quote(do: little - unsigned - integer - 16)

  @doc """
  A signed 4-byte (32-bit) value representing the length of the associated data.

  The range is -(2^31) to (2^31)-1.
  """
  defmacro longlen, do: quote(do: little - signed - integer - 32)

  @doc """
  An unsigned 8-byte (64-bit) value representing the length of the associated
  data.

  The range is 0 to (2^64)-1.
  """
  defmacro ulonglonglen, do: quote(do: little - unsigned - integer - 64)

  @doc """
  An unsigned single byte (8-bit) value representing the precision of a
  numeric number.
  """
  defmacro precision, do: quote(do: unsigned - integer - 8)

  @doc """
  An unsigned single byte (8-bit) value representing the scale of a
  numeric number.
  """
  defmacro scale, do: quote(do: unsigned - integer - 8)

  @doc """
  A single byte (8-bit) value representing a NULL value.
  """
  defmacro gen_null, do: quote(do: size(8))

  @doc """
  A 2-byte (16-bit) or 4-byte (32-bit) value representing a T-SQL NULL value
  for a character or binary data type.

  Please refer to TYPE_VARBYTE (see section 2.2.5.2.3 in MS-TDS.pdf)
  for additional details.
  """
  defmacro charbin_null(n \\ 2) when n in [2, 4],
    do: quote(do: size(unquote(n)) - unit(8))

  @doc """
  A FRESERVEDBIT is a BIT value used for padding that does not transmit
  information.

  FRESERVEDBIT fields SHOULD be set to 0b0 and **MUST be ignored on receipt**.
  """
  defmacro freservedbit(n \\ 1),
    do: quote(do: size(1) - unit(unquote(n)))

  @doc """
  A FRESERVEDBYTE is a BYTE value used for padding that does not transmit
  information.

  FRESERVEDBYTE fields SHOULD be set to 0x00 and **MUST be ignored on
  receipt**.
  """
  defmacro freservedbyte(n \\ 1),
    do: quote(do: size(unquote(n)) - unit(8))

  @doc """
  A single Unicode character in UCS-2 encoding, as specified in
  [Unicode](https://go.microsoft.com/fwlink/?LinkId=90550).
  """
  defmacro unicodechar(n \\ 1), do: quote(do: size(unquote(n)) - unit(16))

  defmacro bigbinary(n), do: quote(do: binary - size(unquote(n)) - unit(8))
end
