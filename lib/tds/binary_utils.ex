defmodule Tds.BinaryUtils do
  @moduledoc false

  @doc """
  A single bit value of either 0 or 1
  """
  defmacro bit(), do: quote(do: size(1))

  @doc """
  An unsigned single byte (8-bit) value. The range is 0 to 255.
  """
  defmacro byte(), do: quote(do: unsigned - 8)

  @doc """
  An unsigned single byte (8-bit) value representing the length of the associated data. The range is 0 to 255.
  """
  defmacro bytelen(), do: quote(do: unsigned - 8)

  @doc """
  An unsigned 2-byte (16-bit) value. The range is 0 to 65535.
  """
  defmacro ushort(), do: quote(do: little - unsigned - 16)

  @doc """
  A signed 4-byte (32-bit) value. The range is -(2^31) to (2^31)-1.
  """
  defmacro long(), do: quote(do: little - signed - 32)

  @doc """
  A signed 8-byte (64-bit) value. The range is –(2^63) to (2^63)-1.
  """
  defmacro longlong(), do: quote(do: little - signed - 64)

  @doc """
  An unsigned 4-byte (32-bit) value. The range is 0 to (2^32)-1
  """
  defmacro ulong(), do: quote(do: little - unsigned - 32)

  @doc """
  An unsigned 8-byte (64-bit) value. The range is 0 to (2^64)-1.
  """
  defmacro ulonglong(), do: quote(do: little - unsigned - 64)

  @doc """
  An unsigned 4-byte (32-bit) value. The range when used as a numeric value is 0 to (2^32)- 1.
  """
  defmacro dword(), do: quote(do: unsigned - 32)

  @doc """
  An unsigned single byte (8-bit) value representing a character. The range is 0 to 255.
  """
  defmacro uchar(), do: quote(do: unsigned - 8)

  @doc """
  An unsigned 2-byte (16-bit) value representing the length of the associated data. The range is 0 to 65535.
  """
  defmacro ushortlen(), do: quote(do: little - unsigned - 16)

  @doc """
  An unsigned 2-byte (16-bit) value representing the length of the associated character or binary data. The range is 0 to 8000.
  """
  defmacro ushortcharbinlen(), do: quote(do: little - unsigned - 16)

  @doc """
  A signed 4-byte (32-bit) value representing the length of the associated data. The range is -(2^31) to (2^31)-1.
  """
  defmacro longlen(), do: quote(do: little - signed - 32)

  @doc """
  An unsigned 8-byte (64-bit) value representing the length of the associated data. The range is 0 to (2^64)-1.
  """
  defmacro ulonglonglen(), do: quote(do: little - unsigned - 64)

  @doc """
  An unsigned single byte (8-bit) value representing the precision of a numeric number.
  """
  defmacro precision(), do: quote(do: unsigned - 8)

  @doc """
  An unsigned single byte (8-bit) value representing the scale of a numeric number.
  """
  defmacro scale(), do: quote(do: unsigned - 8)

  @doc """
  A single byte (8-bit) value representing a NULL value. 0x00

  ## Example
      iex> import Tds.BinaryUtils
      iex> <<_::gen_null()>> = <<0x00 :: size(8)>>
  """
  defmacro gen_null(), do: quote(do: size(8))

  @doc """
  A 2-byte (16-bit) value representing a T-SQL NULL value for a character or binary data type.

  ## Example
      iex> import Tds.BinaryUtils
      iex> <<_::charbin_null32>> = <<0xFFFF :: size(32)>>

  Please refer to TYPE_VARBYTE (see MS-TDS.pdf section 2.2.5.2.3) for additional details.
  """
  defmacro charbin_null16(), do: quote(do: size(16))

  @doc """
  A 4-byte (32-bit) value representing a T-SQL NULL value for a character or binary data type.

  ## Example
      iex> import Tds.BinaryUtils
      iex> <<_::charbin_null32>> = <<0xFFFFFFFF :: size(32)>>

  Please refer to TYPE_VARBYTE (see MS-TDS.pdf section 2.2.5.2.3) for additional details.
  """
  defmacro charbin_null32(), do: quote(do: size(32))

  @doc """
  A FRESERVEDBIT is a BIT value used for padding that does not transmit information.

  FRESERVEDBIT fields SHOULD be set to %b0 and MUST be ignored on receipt.
  """
  defmacro freservedbit(), do: quote(do: 0x0 :: size(1))

  @doc """
  A FRESERVEDBYTE is a BYTE value used for padding that does not transmit information. FRESERVEDBYTE fields SHOULD be set to %x00 and MUST be ignored on receipt.
  """
  defmacro freservedbyte(), do: quote(do: 0x00 :: size(8))

  @doc """
  A 8-bit signed integer
  """
  defmacro int8(), do: quote(do: signed - 8)

  @doc """
  A 16-bit signed integer
  """
  defmacro int16(), do: quote(do: signed - 16)

  @doc """
  A 16-bit signed integer
  """
  defmacro int32(), do: quote(do: signed - 32)

  @doc """
  A 16-bit signed integer
  """
  defmacro int64(), do: quote(do: signed - 64)

  @doc """
  A 16-bit signed integer
  """
  defmacro uint8(), do: quote(do: unsigned - 8)

  @doc """
  A 16-bit signed integer
  """
  defmacro uint16(), do: quote(do: unsigned - 16)

  @doc """
  A 32-bit signed integer
  """
  defmacro uint32(), do: quote(do: unsigned - 32)

  @doc """
  A 64-bit signed integer
  """
  defmacro uint64(), do: quote(do:  unsigned - 64)

  @doc """
  A 64-bit signed float
  """
  defmacro float64(), do: quote(do: signed - float - 64)

  defmacro float32(), do: quote(do: signed - float - 32)

  defmacro binary(size), do: quote(do: binary - size(unquote(size)))

  defmacro binary(size, unit),
    do: quote(do: binary - size(unquote(size)) - unit(unquote(unit)))

  defmacro unicode(size),
    do: quote(do: binary - little - size(unquote(size)) - unit(16))
end
