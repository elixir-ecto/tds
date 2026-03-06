defmodule Tds.Type.StringTest do
  use ExUnit.Case, async: true

  alias Tds.Type.String, as: StrType
  alias Tds.Encoding.UCS2

  # Null collation used in parameter encoding
  @null_collation <<0x00, 0x00, 0x00, 0x00, 0x00>>

  # A real collation: lcid=0x00409 (US English), col_flags=0, version=0,
  # sort_id=0x34 => WINDOWS-1252
  @sample_collation <<0x09, 0x04, 0x00, 0x00, 0x34>>

  describe "type_codes/0" do
    test "returns all 8 string-related type codes" do
      codes = StrType.type_codes()

      assert 0xAF in codes  # bigchar
      assert 0xA7 in codes  # bigvarchar
      assert 0xE7 in codes  # nvarchar
      assert 0xEF in codes  # nchar
      assert 0x23 in codes  # text
      assert 0x27 in codes  # varchar (legacy short)
      assert 0x2F in codes  # char (legacy short)
      assert 0x63 in codes  # ntext
      assert length(codes) == 8
    end
  end

  describe "type_names/0" do
    test "returns :string" do
      assert StrType.type_names() == [:string]
    end
  end

  describe "decode_metadata/1 for nvarchar (0xE7)" do
    test "reads 2-byte max_length and 5-byte collation, shortlen" do
      tail = <<0xAA, 0xBB>>
      # max_length=100 (LE), collation=null, tail
      input =
        <<0xE7, 100::little-unsigned-16>> <>
          @null_collation <> tail

      assert {:ok, meta, ^tail} = StrType.decode_metadata(input)
      assert meta.data_reader == :shortlen
      assert meta.encoding == :ucs2
      assert meta.length == 100
      assert meta.collation != nil
    end

    test "PLP marker 0xFFFF sets data_reader to :plp" do
      input =
        <<0xE7, 0xFF, 0xFF>> <>
          @null_collation <> <<0xCC>>

      assert {:ok, meta, <<0xCC>>} = StrType.decode_metadata(input)
      assert meta.data_reader == :plp
      assert meta.encoding == :ucs2
    end
  end

  describe "decode_metadata/1 for nchar (0xEF)" do
    test "reads metadata like nvarchar" do
      input =
        <<0xEF, 200::little-unsigned-16>> <>
          @null_collation <> <<0xDD>>

      assert {:ok, meta, <<0xDD>>} = StrType.decode_metadata(input)
      assert meta.data_reader == :shortlen
      assert meta.encoding == :ucs2
      assert meta.length == 200
    end
  end

  describe "decode_metadata/1 for bigvarchar (0xA7)" do
    test "reads 2-byte max_length and 5-byte collation" do
      input =
        <<0xA7, 500::little-unsigned-16>> <>
          @sample_collation <> <<0xEE>>

      assert {:ok, meta, <<0xEE>>} = StrType.decode_metadata(input)
      assert meta.data_reader == :shortlen
      assert meta.encoding == :single_byte
      assert meta.length == 500
      assert meta.collation.codepage == "WINDOWS-1252"
    end

    test "PLP marker sets :plp reader for bigvarchar" do
      input =
        <<0xA7, 0xFF, 0xFF>> <>
          @sample_collation <> <<0xFF>>

      assert {:ok, meta, <<0xFF>>} = StrType.decode_metadata(input)
      assert meta.data_reader == :plp
      assert meta.encoding == :single_byte
    end
  end

  describe "decode_metadata/1 for bigchar (0xAF)" do
    test "reads metadata like bigvarchar" do
      input =
        <<0xAF, 100::little-unsigned-16>> <>
          @sample_collation <> <<0x11>>

      assert {:ok, meta, <<0x11>>} = StrType.decode_metadata(input)
      assert meta.data_reader == :shortlen
      assert meta.encoding == :single_byte
    end
  end

  describe "decode_metadata/1 for legacy varchar (0x27)" do
    test "reads 1-byte length and 5-byte collation" do
      input = <<0x27, 50>> <> @sample_collation <> <<0x22>>

      assert {:ok, meta, <<0x22>>} = StrType.decode_metadata(input)
      assert meta.data_reader == :bytelen
      assert meta.encoding == :single_byte
      assert meta.length == 50
    end
  end

  describe "decode_metadata/1 for legacy char (0x2F)" do
    test "reads 1-byte length and 5-byte collation" do
      input = <<0x2F, 30>> <> @sample_collation <> <<0x33>>

      assert {:ok, meta, <<0x33>>} = StrType.decode_metadata(input)
      assert meta.data_reader == :bytelen
      assert meta.encoding == :single_byte
      assert meta.length == 30
    end
  end

  describe "decode_metadata/1 for text (0x23)" do
    test "reads 4-byte length, collation, and table name parts" do
      # length=65535, collation, numparts=1,
      # table part: 4 UCS-2 chars = 8 bytes = "test"
      table_name = UCS2.from_string("test")
      table_size = div(byte_size(table_name), 2)

      input =
        <<0x23, 65535::little-unsigned-32>> <>
          @sample_collation <>
          <<1::signed-8, table_size::little-unsigned-16>> <>
          table_name <> <<0x44>>

      assert {:ok, meta, <<0x44>>} = StrType.decode_metadata(input)
      assert meta.data_reader == :longlen
      assert meta.encoding == :single_byte
    end
  end

  describe "decode_metadata/1 for ntext (0x63)" do
    test "reads 4-byte length, collation, and table name parts" do
      table_name = UCS2.from_string("tbl")
      table_size = div(byte_size(table_name), 2)

      input =
        <<0x63, 65535::little-unsigned-32>> <>
          @null_collation <>
          <<1::signed-8, table_size::little-unsigned-16>> <>
          table_name <> <<0x55>>

      assert {:ok, meta, <<0x55>>} = StrType.decode_metadata(input)
      assert meta.data_reader == :longlen
      assert meta.encoding == :ucs2
    end
  end

  describe "decode/2" do
    test "nil returns nil" do
      assert StrType.decode(nil, %{encoding: :ucs2}) == nil
    end

    test "UCS-2 data decodes to UTF-8 string" do
      ucs2_data = UCS2.from_string("Hello")
      meta = %{encoding: :ucs2}

      assert StrType.decode(ucs2_data, meta) == "Hello"
    end

    test "empty UCS-2 data decodes to empty string" do
      assert StrType.decode(<<>>, %{encoding: :ucs2}) == ""
    end

    test "UCS-2 with non-ASCII characters" do
      ucs2_data = UCS2.from_string("cafe\u0301")
      meta = %{encoding: :ucs2}

      result = StrType.decode(ucs2_data, meta)
      assert is_binary(result)
      assert String.valid?(result)
    end

    test "single-byte data uses codepage from collation" do
      {:ok, collation} =
        Tds.Protocol.Collation.decode(@sample_collation)

      meta = %{encoding: :single_byte, collation: collation}
      # ASCII chars are valid in all WINDOWS codepages
      data = "Hello"

      result = StrType.decode(data, meta)
      assert result == "Hello"
    end
  end

  describe "encode/2" do
    test "nil produces nvarchar PLP null" do
      {type_code, meta_bin, value_bin} = StrType.encode(nil, %{})

      assert type_code == 0xE7
      meta = IO.iodata_to_binary(meta_bin)
      # type_code + nvarchar(max): 0xFFFF + null collation
      assert meta == <<0xE7, 0xFF, 0xFF>> <> @null_collation

      value = IO.iodata_to_binary(value_bin)
      # PLP null: 0xFFFFFFFFFFFFFFFF
      assert value == <<0xFFFFFFFFFFFFFFFF::little-unsigned-64>>
    end

    test "short string encodes as nvarchar with shortlen" do
      {type_code, meta_bin, value_bin} = StrType.encode("hi", %{})

      assert type_code == 0xE7

      ucs2 = UCS2.from_string("hi")
      ucs2_size = byte_size(ucs2)

      meta = IO.iodata_to_binary(meta_bin)
      assert meta == <<0xE7, ucs2_size::little-unsigned-16>> <> @null_collation

      value = IO.iodata_to_binary(value_bin)
      assert value == <<ucs2_size::little-unsigned-16>> <> ucs2
    end

    test "empty string encodes as nvarchar(max) with PLP empty" do
      {type_code, meta_bin, value_bin} = StrType.encode("", %{})

      assert type_code == 0xE7

      meta = IO.iodata_to_binary(meta_bin)
      # type_code + nvarchar(max) header for empty string
      assert meta == <<0xE7, 0xFF, 0xFF>> <> @null_collation

      value = IO.iodata_to_binary(value_bin)
      # PLP empty: size=0 (8 bytes) + terminator 0x00000000
      assert value == <<0::unsigned-64, 0::unsigned-32>>
    end

    test "long string (>8000 UCS-2 bytes) encodes with PLP" do
      # Create a string that will be > 8000 bytes in UCS-2
      long_str = String.duplicate("A", 4001)
      {type_code, meta_bin, value_bin} = StrType.encode(long_str, %{})

      assert type_code == 0xE7

      meta = IO.iodata_to_binary(meta_bin)
      # type_code + nvarchar(max)
      assert meta == <<0xE7, 0xFF, 0xFF>> <> @null_collation

      value = IO.iodata_to_binary(value_bin)
      ucs2 = UCS2.from_string(long_str)
      ucs2_size = byte_size(ucs2)

      # PLP format: total_size (8) + chunk_size (4) + data + terminator (4)
      <<total_size::little-unsigned-64, _rest::binary>> = value
      assert total_size == ucs2_size

      # Should end with 0x00000000 terminator
      assert :binary.part(value, byte_size(value), -4) ==
               <<0::little-unsigned-32>>
    end

    test "string at exactly 8000 UCS-2 bytes uses shortlen" do
      # 4000 chars * 2 bytes = 8000 UCS-2 bytes
      str = String.duplicate("X", 4000)
      {_type_code, meta_bin, _value_bin} = StrType.encode(str, %{})

      meta = IO.iodata_to_binary(meta_bin)
      ucs2_size = byte_size(UCS2.from_string(str))
      # type_code + shortlen, not PLP
      assert meta == <<0xE7, ucs2_size::little-unsigned-16>> <> @null_collation
    end
  end

  describe "param_descriptor/2" do
    test "nil returns nvarchar(1)" do
      assert StrType.param_descriptor(nil, %{}) == "nvarchar(1)"
    end

    test "empty string returns nvarchar(1)" do
      assert StrType.param_descriptor("", %{}) == "nvarchar(1)"
    end

    test "short string returns nvarchar(2000)" do
      assert StrType.param_descriptor("hello", %{}) == "nvarchar(2000)"
    end

    test "string over 2000 chars returns nvarchar(max)" do
      long_str = String.duplicate("x", 2001)
      assert StrType.param_descriptor(long_str, %{}) == "nvarchar(max)"
    end

    test "string of exactly 2000 chars returns nvarchar(2000)" do
      str = String.duplicate("y", 2000)
      assert StrType.param_descriptor(str, %{}) == "nvarchar(2000)"
    end
  end

  describe "infer/1" do
    test "UTF-8 string infers as string" do
      assert {:ok, %{}} = StrType.infer("hello")
    end

    test "empty string infers as string" do
      assert {:ok, %{}} = StrType.infer("")
    end

    test "integer skips" do
      assert :skip = StrType.infer(42)
    end

    test "atom skips" do
      assert :skip = StrType.infer(:foo)
    end

    test "nil skips" do
      assert :skip = StrType.infer(nil)
    end

    test "list skips" do
      assert :skip = StrType.infer([1, 2])
    end
  end

  describe "encode/decode roundtrip" do
    test "short ASCII string roundtrips" do
      original = "Hello, World!"
      {_type, _meta, value_bin} = StrType.encode(original, %{})
      value = IO.iodata_to_binary(value_bin)

      # shortlen: 2-byte length prefix + UCS-2 data
      <<size::little-unsigned-16, data::binary-size(size)>> = value

      decoded =
        StrType.decode(data, %{encoding: :ucs2})

      assert decoded == original
    end

    test "unicode string roundtrips" do
      original = "Bonjour le monde"
      {_type, _meta, value_bin} = StrType.encode(original, %{})
      value = IO.iodata_to_binary(value_bin)

      <<size::little-unsigned-16, data::binary-size(size)>> = value

      decoded = StrType.decode(data, %{encoding: :ucs2})
      assert decoded == original
    end
  end
end
