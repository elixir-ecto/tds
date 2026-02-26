defmodule Tds.Protocol.Binary do
  @moduledoc """
  Unified binary macros for TDS protocol encoding and decoding.

  Consolidates macros from `Tds.BinaryUtils` (little-endian, used by most
  modules) and `Tds.Protocol.Grammar` (big-endian + parameterized, used by
  prelogin and collation).

  ## Byte Order Convention

  Zero-arity macros (`ushort/0`, `ulong/0`, etc.) are **little-endian** —
  the default for TDS data fields.

  Big-endian variants have a `_be` suffix (`ushort_be/0`, `ulong_be/0`, etc.)
  and are used for TDS prelogin header offsets/lengths per the MS-TDS spec.

  ## Parameterized Macros

  `bit/1`, `byte/1`, `uchar/1`, `unicodechar/1`, `bigbinary/1` accept
  a size parameter and are used for structures like collation bitfields.
  """

  # ===========================================================================
  # Unsigned integers — little-endian (from BinaryUtils)
  # ===========================================================================

  @doc "An unsigned single byte (8-bit) value. Range: 0..255."
  defmacro byte, do: quote(do: unsigned - 8)

  @doc "An unsigned 2-byte (16-bit) little-endian value. Range: 0..65535."
  defmacro ushort, do: quote(do: little - unsigned - 16)

  @doc "An unsigned 4-byte (32-bit) little-endian value. Range: 0..(2^32)-1."
  defmacro ulong, do: quote(do: little - unsigned - 32)

  @doc "Alias for `ulong/0`."
  defmacro dword, do: quote(do: little - unsigned - 32)

  @doc "An unsigned 8-byte (64-bit) little-endian value. Range: 0..(2^64)-1."
  defmacro ulonglong, do: quote(do: little - unsigned - 64)

  @doc "An unsigned single byte (8-bit) value representing a character."
  defmacro uchar, do: quote(do: unsigned - 8)

  # ===========================================================================
  # Signed integers — little-endian (from BinaryUtils)
  # ===========================================================================

  @doc "A signed 4-byte (32-bit) little-endian value."
  defmacro long, do: quote(do: little - signed - 32)

  @doc "A signed 8-byte (64-bit) little-endian value."
  defmacro longlong, do: quote(do: little - signed - 64)

  @doc "A signed 8-bit integer."
  defmacro int8, do: quote(do: signed - 8)

  @doc "A signed 16-bit little-endian integer."
  defmacro int16, do: quote(do: little - signed - 16)

  @doc "A signed 32-bit little-endian integer."
  defmacro int32, do: quote(do: little - signed - 32)

  @doc "A signed 64-bit little-endian integer."
  defmacro int64, do: quote(do: little - signed - 64)

  # ===========================================================================
  # Unsigned integer aliases (from BinaryUtils)
  # ===========================================================================

  @doc "An unsigned 8-bit integer."
  defmacro uint8, do: quote(do: unsigned - 8)

  @doc "An unsigned 16-bit little-endian integer."
  defmacro uint16, do: quote(do: little - unsigned - 16)

  @doc "An unsigned 32-bit little-endian integer."
  defmacro uint32, do: quote(do: little - unsigned - 32)

  @doc "An unsigned 64-bit little-endian integer."
  defmacro uint64, do: quote(do: little - unsigned - 64)

  # ===========================================================================
  # Floats — little-endian (from BinaryUtils)
  # ===========================================================================

  @doc "A 32-bit little-endian float."
  defmacro float32, do: quote(do: little - signed - float - 32)

  @doc "A 64-bit little-endian float."
  defmacro float64, do: quote(do: little - signed - float - 64)

  # ===========================================================================
  # Length prefixes (from BinaryUtils)
  # ===========================================================================

  @doc "Unsigned 8-bit length prefix."
  defmacro bytelen, do: quote(do: unsigned - 8)

  @doc "Unsigned 16-bit little-endian length prefix."
  defmacro ushortlen, do: quote(do: little - unsigned - 16)

  @doc "Unsigned 16-bit little-endian char/binary length prefix."
  defmacro ushortcharbinlen, do: quote(do: little - unsigned - 16)

  @doc "Signed 32-bit little-endian length prefix."
  defmacro longlen, do: quote(do: little - signed - 32)

  @doc "Unsigned 64-bit little-endian length prefix."
  defmacro ulonglonglen, do: quote(do: little - unsigned - 64)

  # ===========================================================================
  # Type metadata (from BinaryUtils)
  # ===========================================================================

  @doc "Unsigned 8-bit precision value."
  defmacro precision, do: quote(do: unsigned - 8)

  @doc "Unsigned 8-bit scale value."
  defmacro scale, do: quote(do: unsigned - 8)

  # ===========================================================================
  # Null markers (from BinaryUtils)
  # ===========================================================================

  @doc "A single byte (8-bit) NULL value."
  defmacro gen_null, do: quote(do: size(8))

  @doc "A 2-byte (16-bit) NULL value for char/binary data."
  defmacro charbin_null16, do: quote(do: size(16))

  @doc "A 4-byte (32-bit) NULL value for char/binary data."
  defmacro charbin_null32, do: quote(do: size(32))

  # ===========================================================================
  # Reserved fields (from BinaryUtils — include literal zero values)
  # ===========================================================================

  @doc "A single reserved bit, set to 0."
  defmacro freservedbit, do: quote(do: 0x0 :: size(1))

  @doc "A single reserved byte, set to 0x00."
  defmacro freservedbyte, do: quote(do: 0x00 :: size(8))

  # ===========================================================================
  # Fixed-width special (from BinaryUtils)
  # ===========================================================================

  @doc "An unsigned 6-byte (48-bit) value."
  defmacro sixbyte, do: quote(do: unsigned - 48)

  @doc "A single bit value of either 0 or 1."
  defmacro bit, do: quote(do: size(1))

  # ===========================================================================
  # Parameterized binary/unicode (from BinaryUtils)
  # ===========================================================================

  @doc "A binary of `size` bytes."
  defmacro binary(size), do: quote(do: binary - size(unquote(size)))

  @doc "A binary of `size * unit` bits."
  defmacro binary(size, unit),
    do: quote(do: binary - size(unquote(size)) - unit(unquote(unit)))

  @doc "A little-endian UCS-2 binary of `size` 16-bit code units."
  defmacro unicode(size),
    do: quote(do: binary - little - size(unquote(size)) - unit(16))

  # ===========================================================================
  # Big-endian variants (from Grammar, for prelogin headers)
  # ===========================================================================

  @doc "An unsigned 2-byte (16-bit) big-endian value."
  defmacro ushort_be, do: quote(do: unsigned - 16)

  @doc "An unsigned 4-byte (32-bit) big-endian value."
  defmacro ulong_be, do: quote(do: unsigned - 32)

  @doc "Alias for `ulong_be/0`."
  defmacro dword_be, do: quote(do: unsigned - 32)

  @doc "A signed 4-byte (32-bit) big-endian value."
  defmacro long_be, do: quote(do: signed - 32)

  @doc "A signed 8-byte (64-bit) big-endian value."
  defmacro longlong_be, do: quote(do: signed - 64)

  @doc "An unsigned 8-byte (64-bit) big-endian value."
  defmacro ulonglong_be, do: quote(do: unsigned - 64)

  # ===========================================================================
  # Parameterized macros (from Grammar, for collation and structured fields)
  # ===========================================================================

  @doc "A field of `n` consecutive 1-bit units."
  defmacro bit(n), do: quote(do: size(1) - unit(unquote(n)))

  @doc "An unsigned field of `n` bytes."
  defmacro byte(n), do: quote(do: unsigned - size(unquote(n)) - unit(8))

  @doc "An unsigned field of `n` bytes (character variant)."
  defmacro uchar(n), do: quote(do: unsigned - size(unquote(n)) - unit(8))

  @doc "A field of `n` UCS-2 (16-bit) character units."
  defmacro unicodechar(n), do: quote(do: size(unquote(n)) - unit(16))

  @doc "A binary field of `n` bytes."
  defmacro bigbinary(n), do: quote(do: binary - size(unquote(n)) - unit(8))

  @doc "A reserved bit field of `n` 1-bit units for padding."
  defmacro freservedbit(n), do: quote(do: size(1) - unit(unquote(n)))

  @doc "A reserved byte field of `n` bytes for padding."
  defmacro freservedbyte(n), do: quote(do: size(unquote(n)) - unit(8))

  @doc """
  A 2-byte or 4-byte NULL marker for char/binary data.

  `n` must be 2 or 4.
  """
  defmacro charbin_null(n) when n in [2, 4],
    do: quote(do: size(unquote(n)) - unit(8))
end
