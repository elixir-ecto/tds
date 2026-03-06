defmodule Tds.Type.XmlTest do
  use ExUnit.Case, async: true

  alias Tds.Type.Xml
  alias Tds.Encoding.UCS2

  @null_collation <<0x00, 0x00, 0x00, 0x00, 0x00>>

  describe "type_codes/0" do
    test "returns xml type code 0xF1" do
      codes = Xml.type_codes()

      assert 0xF1 in codes
      assert length(codes) == 1
    end
  end

  describe "type_names/0" do
    test "returns :xml" do
      assert Xml.type_names() == [:xml]
    end
  end

  describe "decode_metadata/1 without schema" do
    test "reads 1 schema-presence byte and returns plp reader" do
      tail = <<0xAA, 0xBB>>
      input = <<0xF1, 0x00>> <> tail

      assert {:ok, meta, ^tail} = Xml.decode_metadata(input)
      assert meta.data_reader == :plp
    end
  end

  describe "decode_metadata/1 with schema" do
    test "reads schema info strings and returns plp reader" do
      db_name = UCS2.from_string("mydb")
      db_len = div(byte_size(db_name), 2)

      owner_name = UCS2.from_string("dbo")
      owner_len = div(byte_size(owner_name), 2)

      collection_name = UCS2.from_string("MySchema")
      collection_len = div(byte_size(collection_name), 2)

      tail = <<0xCC>>

      input =
        <<0xF1, 0x01, db_len::unsigned-8>> <>
          db_name <>
          <<owner_len::unsigned-8>> <>
          owner_name <>
          <<collection_len::little-unsigned-16>> <>
          collection_name <>
          tail

      assert {:ok, meta, ^tail} = Xml.decode_metadata(input)
      assert meta.data_reader == :plp
    end

    test "handles empty schema strings" do
      tail = <<0xDD>>

      input =
        <<0xF1, 0x01, 0::unsigned-8, 0::unsigned-8,
          0::little-unsigned-16>> <> tail

      assert {:ok, meta, ^tail} = Xml.decode_metadata(input)
      assert meta.data_reader == :plp
    end
  end

  describe "decode/2" do
    test "nil returns nil" do
      assert Xml.decode(nil, %{}) == nil
    end

    test "UCS-2 data decodes to UTF-8 string" do
      ucs2_data = UCS2.from_string("<root>hello</root>")
      assert Xml.decode(ucs2_data, %{}) == "<root>hello</root>"
    end

    test "empty binary returns empty string" do
      assert Xml.decode(<<>>, %{}) == ""
    end

    test "UCS-2 with non-ASCII characters" do
      ucs2_data = UCS2.from_string("<el>cafe\u0301</el>")
      result = Xml.decode(ucs2_data, %{})

      assert is_binary(result)
      assert String.valid?(result)
      assert String.contains?(result, "<el>")
    end
  end

  describe "encode/2" do
    test "nil produces nvarchar PLP null" do
      {type_code, meta_bin, value_bin} = Xml.encode(nil, %{})

      assert type_code == 0xE7
      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xE7, 0xFF, 0xFF>> <> @null_collation

      value = IO.iodata_to_binary(value_bin)
      assert value == <<0xFFFFFFFFFFFFFFFF::little-unsigned-64>>
    end

    test "short XML encodes as nvarchar with shortlen" do
      xml = "<r/>"
      {type_code, meta_bin, value_bin} = Xml.encode(xml, %{})

      assert type_code == 0xE7

      ucs2 = UCS2.from_string(xml)
      ucs2_size = byte_size(ucs2)

      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xE7, ucs2_size::little-unsigned-16>> <> @null_collation

      value = IO.iodata_to_binary(value_bin)
      assert value == <<ucs2_size::little-unsigned-16>> <> ucs2
    end

    test "empty string encodes as nvarchar(max) with PLP empty" do
      {type_code, meta_bin, value_bin} = Xml.encode("", %{})

      assert type_code == 0xE7

      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xE7, 0xFF, 0xFF>> <> @null_collation

      value = IO.iodata_to_binary(value_bin)
      assert value == <<0::unsigned-64, 0::unsigned-32>>
    end

    test "large XML (>8000 UCS-2 bytes) encodes with PLP" do
      xml =
        "<root>" <> String.duplicate("A", 4001) <> "</root>"

      {type_code, meta_bin, value_bin} = Xml.encode(xml, %{})

      assert type_code == 0xE7

      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xE7, 0xFF, 0xFF>> <> @null_collation

      value = IO.iodata_to_binary(value_bin)
      ucs2 = UCS2.from_string(xml)
      ucs2_size = byte_size(ucs2)

      <<total_size::little-unsigned-64, _rest::binary>> = value
      assert total_size == ucs2_size

      # Ends with PLP terminator
      assert :binary.part(value, byte_size(value), -4) ==
               <<0::little-unsigned-32>>
    end
  end

  describe "param_descriptor/2" do
    test "nil returns xml" do
      assert Xml.param_descriptor(nil, %{}) == "xml"
    end

    test "any XML string returns xml" do
      assert Xml.param_descriptor("<r/>", %{}) == "xml"
    end

    test "empty string returns xml" do
      assert Xml.param_descriptor("", %{}) == "xml"
    end
  end

  describe "infer/1" do
    test "always returns :skip for strings" do
      assert :skip = Xml.infer("<root/>")
    end

    test "always returns :skip for nil" do
      assert :skip = Xml.infer(nil)
    end

    test "always returns :skip for integers" do
      assert :skip = Xml.infer(42)
    end
  end

  describe "encode/decode roundtrip" do
    test "short XML roundtrips" do
      original = "<root><child>data</child></root>"
      {_type, _meta, value_bin} = Xml.encode(original, %{})
      value = IO.iodata_to_binary(value_bin)

      # shortlen: 2-byte length prefix + UCS-2 data
      <<size::little-unsigned-16, data::binary-size(size)>> = value

      decoded = Xml.decode(data, %{})
      assert decoded == original
    end
  end
end
