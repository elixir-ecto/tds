defmodule Tds.TypeIntegrationTest do
  @moduledoc """
  End-to-end tests for the new type system pipeline:
  Registry -> handler.decode_metadata -> DataReader.read -> handler.decode

  These tests craft binary payloads that match real TDS COLMETADATA +
  ROW token sequences and verify that Tds.Tokens.decode_tokens/2
  produces the correct Elixir values.
  """

  use ExUnit.Case, async: true

  import Tds.Protocol.Constants

  alias Tds.Type.{DataReader, Registry}

  # -- Helper: build a minimal COLMETADATA + ROW + DONE stream --------

  # Builds a binary token stream with one column and one row.
  # type_meta_bin is the raw type metadata (starts with type code byte).
  # value_bin is the raw row value data (with length prefix per reader).
  defp single_column_stream(type_meta_bin, value_bin, name \\ "c") do
    col_name_ucs2 = :unicode.characters_to_binary(name, :utf8, {:utf16, :little})
    name_len = div(byte_size(col_name_ucs2), 2)

    colmetadata_body =
      # column_count = 1
      <<0x01, 0x00>> <>
        # usertype (4 bytes) + flags (2 bytes)
        <<0x00, 0x00, 0x00, 0x00, 0x00, 0x20>> <>
        type_meta_bin <>
        <<name_len::unsigned-8>> <>
        col_name_ucs2

    # ROW token (0xD1) + value_bin
    row_body = value_bin

    # DONE token (0xFD) + 12 bytes
    done_body =
      <<0x10, 0x00, 0xC1, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00>>

    <<token(:colmetadata)>> <>
      colmetadata_body <>
      <<token(:row)>> <>
      row_body <>
      <<token(:done)>> <>
      done_body
  end

  # -- Registry + handler.decode_metadata pipeline tests ---------------

  describe "decode pipeline: integer column" do
    test "fixed int (0x38) produces correct value" do
      # Type metadata: int (0x38) — fixed, no extra bytes
      type_meta = <<tds_type(:int)>>
      # Row value: 4 bytes LE = 42
      value = <<42, 0, 0, 0>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: [%{handler: Tds.Type.Integer}],
               row: [42],
               done: _
             ] = tokens
    end

    test "intn (0x26) with bytelen reader and NULL" do
      # Type metadata: intn (0x26), length=4
      type_meta = <<tds_type(:intn), 0x04>>
      # Row value: bytelen NULL (0x00)
      value = <<0x00>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: [%{handler: Tds.Type.Integer}],
               row: [nil],
               done: _
             ] = tokens
    end

    test "intn (0x26) with 4-byte value" do
      # Type metadata: intn (0x26), length=4
      type_meta = <<tds_type(:intn), 0x04>>
      # Row value: bytelen size=4, value=100
      value = <<0x04, 100, 0, 0, 0>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: _,
               row: [100],
               done: _
             ] = tokens
    end

    test "bigint (0x7F) fixed 8-byte value" do
      type_meta = <<tds_type(:bigint)>>
      value = <<1, 0, 0, 0, 0, 0, 0, 0>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: _,
               row: [1],
               done: _
             ] = tokens
    end
  end

  describe "decode pipeline: string column" do
    test "bigvarchar (0xA7) shortlen with ASCII data" do
      collation = <<0x09, 0x04, 0xD0, 0x00, 0x34>>
      type_meta = <<tds_type(:bigvarchar), 0x03, 0x00>> <> collation
      # shortlen: 2-byte LE length + data
      value = <<0x03, 0x00, "foo">>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: [%{handler: Tds.Type.String}],
               row: ["foo"],
               done: _
             ] = tokens
    end

    test "nvarchar (0xE7) shortlen with UCS-2 data" do
      collation = <<0x09, 0x04, 0xD0, 0x00, 0x34>>
      # max_length = 8000 (0x401F -> no, use 200 = 0xC8, 0x00)
      type_meta = <<tds_type(:nvarchar), 0xC8, 0x00>> <> collation
      ucs2 = :unicode.characters_to_binary("hello", :utf8, {:utf16, :little})
      ucs2_len = byte_size(ucs2)
      value = <<ucs2_len::little-unsigned-16>> <> ucs2

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: [%{handler: Tds.Type.String, encoding: :ucs2}],
               row: ["hello"],
               done: _
             ] = tokens
    end

    test "nvarchar (0xE7) PLP with UCS-2 data" do
      collation = <<0x09, 0x04, 0xD0, 0x00, 0x34>>
      # max_length = 0xFFFF means PLP
      type_meta = <<tds_type(:nvarchar), 0xFF, 0xFF>> <> collation
      ucs2 = :unicode.characters_to_binary("test", :utf8, {:utf16, :little})
      ucs2_len = byte_size(ucs2)

      # PLP: 8-byte total size + chunk (4-byte chunk_size + data) + terminator
      value =
        <<ucs2_len::little-unsigned-64>> <>
          <<ucs2_len::little-unsigned-32>> <>
          ucs2<>
          <<0, 0, 0, 0>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: [%{handler: Tds.Type.String, data_reader: :plp}],
               row: ["test"],
               done: _
             ] = tokens
    end

    test "nvarchar PLP NULL" do
      collation = <<0x09, 0x04, 0xD0, 0x00, 0x34>>
      type_meta = <<tds_type(:nvarchar), 0xFF, 0xFF>> <> collation
      # PLP NULL marker: 8 bytes of 0xFF
      value = <<0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: _,
               row: [nil],
               done: _
             ] = tokens
    end

    test "shortlen NULL" do
      collation = <<0x09, 0x04, 0xD0, 0x00, 0x34>>
      type_meta = <<tds_type(:bigvarchar), 0x03, 0x00>> <> collation
      # shortlen NULL: 0xFFFF
      value = <<0xFF, 0xFF>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: _,
               row: [nil],
               done: _
             ] = tokens
    end
  end

  describe "decode pipeline: multiple columns" do
    test "int + nvarchar in same row" do
      collation = <<0x09, 0x04, 0xD0, 0x00, 0x34>>
      ucs2 = :unicode.characters_to_binary("hi", :utf8, {:utf16, :little})
      ucs2_len = byte_size(ucs2)

      col1_name = :unicode.characters_to_binary("id", :utf8, {:utf16, :little})
      col2_name = :unicode.characters_to_binary("name", :utf8, {:utf16, :little})

      colmetadata_body =
        <<0x02, 0x00>> <>
          # Column 1: int
          <<0x00, 0x00, 0x00, 0x00, 0x00, 0x20>> <>
          <<tds_type(:int)>> <>
          <<div(byte_size(col1_name), 2)::unsigned-8>> <> col1_name <>
          # Column 2: nvarchar shortlen
          <<0x00, 0x00, 0x00, 0x00, 0x00, 0x20>> <>
          <<tds_type(:nvarchar), 0xC8, 0x00>> <> collation <>
          <<div(byte_size(col2_name), 2)::unsigned-8>> <> col2_name

      # Row values: int 7 + nvarchar "hi"
      row_body =
        <<7, 0, 0, 0>> <>
          <<ucs2_len::little-unsigned-16>> <> ucs2

      done_body =
        <<0x10, 0x00, 0xC1, 0x00, 0x01, 0x00, 0x00, 0x00,
          0x00, 0x00, 0x00, 0x00>>

      stream =
        <<token(:colmetadata)>> <>
          colmetadata_body <>
          <<token(:row)>> <>
          row_body <>
          <<token(:done)>> <>
          done_body

      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: [
                 %{name: "id", handler: Tds.Type.Integer},
                 %{name: "name", handler: Tds.Type.String}
               ],
               row: [7, "hi"],
               done: _
             ] = tokens
    end
  end

  describe "DataReader + handler.decode unit pipeline" do
    test "integer via bytelen reader" do
      handler = Tds.Type.Integer
      {:ok, meta, <<>>} = handler.decode_metadata(<<tds_type(:intn), 0x04>>)

      # Non-null: bytelen prefix 4, then 4 bytes LE = 99
      {raw, <<>>} = DataReader.read(meta.data_reader, <<0x04, 99, 0, 0, 0>>)
      assert handler.decode(raw, meta) == 99

      # NULL: bytelen prefix 0x00
      {nil_raw, <<>>} = DataReader.read(meta.data_reader, <<0x00>>)
      assert handler.decode(nil_raw, meta) == nil
    end

    test "string via shortlen reader" do
      handler = Tds.Type.String
      collation = <<0x09, 0x04, 0xD0, 0x00, 0x34>>

      {:ok, meta, <<>>} =
        handler.decode_metadata(
          <<tds_type(:nvarchar), 0xC8, 0x00>> <> collation
        )

      ucs2 = :unicode.characters_to_binary("abc", :utf8, {:utf16, :little})
      ucs2_len = byte_size(ucs2)
      {raw, <<>>} = DataReader.read(meta.data_reader, <<ucs2_len::little-16>> <> ucs2)
      assert handler.decode(raw, meta) == "abc"
    end

    test "boolean via fixed reader" do
      handler = Tds.Type.Boolean
      {:ok, meta, <<>>} = handler.decode_metadata(<<tds_type(:bit)>>)

      {raw, <<>>} = DataReader.read(meta.data_reader, <<0x01>>)
      assert handler.decode(raw, meta) == true

      {raw, <<>>} = DataReader.read(meta.data_reader, <<0x00>>)
      assert handler.decode(raw, meta) == false
    end

    test "registry handler lookup" do
      reg = Registry.new()

      assert {:ok, Tds.Type.Integer} =
               Registry.handler_for_code(reg, tds_type(:int))

      assert {:ok, Tds.Type.String} =
               Registry.handler_for_code(reg, tds_type(:nvarchar))

      assert {:ok, Tds.Type.Boolean} =
               Registry.handler_for_code(reg, tds_type(:bit))

      assert {:ok, Tds.Type.DateTime} =
               Registry.handler_for_code(reg, tds_type(:daten))

      assert {:ok, Tds.Type.Decimal} =
               Registry.handler_for_code(reg, tds_type(:decimaln))
    end
  end

  describe "decode pipeline: boolean column" do
    test "fixed bit (0x32) true" do
      type_meta = <<tds_type(:bit)>>
      value = <<0x01>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: [%{handler: Tds.Type.Boolean}],
               row: [true],
               done: _
             ] = tokens
    end

    test "fixed bit (0x32) false" do
      type_meta = <<tds_type(:bit)>>
      value = <<0x00>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: _,
               row: [false],
               done: _
             ] = tokens
    end
  end

  describe "decode pipeline: decimal column" do
    test "decimaln (0x6A) with precision 10, scale 2" do
      # decimaln: type_code, length, precision, scale
      type_meta = <<tds_type(:decimaln), 0x05, 10, 2>>
      # bytelen: size=5, sign=1 (positive), value=12345 LE
      # 12345 = 0x3039 -> <<0x39, 0x30, 0x00, 0x00>>
      value = <<0x05, 0x01, 0x39, 0x30, 0x00, 0x00>>

      stream = single_column_stream(type_meta, value)
      tokens = Tds.Tokens.decode_tokens(stream)

      assert [
               colmetadata: [%{handler: Tds.Type.Decimal}],
               row: [dec],
               done: _
             ] = tokens

      assert Decimal.equal?(dec, Decimal.new("123.45"))
    end
  end
end
