defmodule Tds.Type.DateTimeTest do
  use ExUnit.Case, async: true

  alias Tds.Type.DateTime, as: DTType

  # Epoch constants matching the wire format
  @year_1900_days :calendar.date_to_gregorian_days({1900, 1, 1})

  describe "type_codes/0" do
    test "returns all 7 datetime type codes" do
      codes = DTType.type_codes()

      assert 0x28 in codes
      assert 0x29 in codes
      assert 0x2A in codes
      assert 0x2B in codes
      assert 0x3A in codes
      assert 0x3D in codes
      assert 0x6F in codes
      assert length(codes) == 7
    end
  end

  describe "type_names/0" do
    test "returns all datetime-related names" do
      names = DTType.type_names()

      assert :date in names
      assert :time in names
      assert :datetime in names
      assert :datetime2 in names
      assert :smalldatetime in names
      assert :datetimeoffset in names
    end
  end

  # -------------------------------------------------------------------
  # decode_metadata
  # -------------------------------------------------------------------

  describe "decode_metadata/1 for daten (0x28)" do
    test "returns bytelen reader, no scale" do
      input = <<0x28, 0xAA, 0xBB>>

      assert {:ok, meta, <<0xAA, 0xBB>>} =
               DTType.decode_metadata(input)

      assert meta.data_reader == :bytelen
    end
  end

  describe "decode_metadata/1 for timen (0x29)" do
    test "reads 1-byte scale" do
      input = <<0x29, 0x07, 0xCC>>

      assert {:ok, meta, <<0xCC>>} =
               DTType.decode_metadata(input)

      assert meta.data_reader == :bytelen
      assert meta.scale == 7
    end

    test "reads scale 0" do
      input = <<0x29, 0x00, 0xDD>>

      assert {:ok, meta, <<0xDD>>} =
               DTType.decode_metadata(input)

      assert meta.scale == 0
    end
  end

  describe "decode_metadata/1 for datetime2n (0x2A)" do
    test "reads 1-byte scale" do
      input = <<0x2A, 0x03, 0xEE>>

      assert {:ok, meta, <<0xEE>>} =
               DTType.decode_metadata(input)

      assert meta.data_reader == :bytelen
      assert meta.scale == 3
    end
  end

  describe "decode_metadata/1 for datetimeoffsetn (0x2B)" do
    test "reads 1-byte scale" do
      input = <<0x2B, 0x07, 0xFF>>

      assert {:ok, meta, <<0xFF>>} =
               DTType.decode_metadata(input)

      assert meta.data_reader == :bytelen
      assert meta.scale == 7
    end
  end

  describe "decode_metadata/1 for smalldatetime (0x3A)" do
    test "returns fixed 4-byte reader" do
      input = <<0x3A, 0xAA>>

      assert {:ok, %{data_reader: {:fixed, 4}}, <<0xAA>>} =
               DTType.decode_metadata(input)
    end
  end

  describe "decode_metadata/1 for datetime (0x3D)" do
    test "returns fixed 8-byte reader" do
      input = <<0x3D, 0xBB>>

      assert {:ok, %{data_reader: {:fixed, 8}}, <<0xBB>>} =
               DTType.decode_metadata(input)
    end
  end

  describe "decode_metadata/1 for datetimen (0x6F)" do
    test "reads 1-byte length, returns bytelen reader" do
      input = <<0x6F, 0x08, 0xCC>>

      assert {:ok, meta, <<0xCC>>} =
               DTType.decode_metadata(input)

      assert meta.data_reader == :bytelen
      assert meta.length == 8
    end

    test "reads 4-byte length for smalldatetime variant" do
      input = <<0x6F, 0x04, 0xDD>>

      assert {:ok, meta, <<0xDD>>} =
               DTType.decode_metadata(input)

      assert meta.data_reader == :bytelen
      assert meta.length == 4
    end
  end

  # -------------------------------------------------------------------
  # decode — daten (0x28)
  # -------------------------------------------------------------------

  describe "decode/2 daten" do
    @meta_date %{type_code: 0x28}

    test "nil returns nil" do
      assert DTType.decode(nil, @meta_date) == nil
    end

    test "decodes 2024-01-01" do
      days = :calendar.date_to_gregorian_days({2024, 1, 1}) - 366
      wire = <<days::little-24>>

      assert DTType.decode(wire, @meta_date) == ~D[2024-01-01]
    end

    test "decodes epoch boundary 0001-01-01" do
      wire = <<0, 0, 0>>
      assert DTType.decode(wire, @meta_date) == ~D[0001-01-01]
    end

    test "decodes max boundary 9999-12-31" do
      days = :calendar.date_to_gregorian_days({9999, 12, 31}) - 366
      wire = <<days::little-24>>

      assert DTType.decode(wire, @meta_date) == ~D[9999-12-31]
    end
  end

  # -------------------------------------------------------------------
  # decode — timen (0x29)
  # -------------------------------------------------------------------

  describe "decode/2 timen" do
    test "nil returns nil" do
      assert DTType.decode(nil, %{type_code: 0x29, scale: 7}) == nil
    end

    test "decodes midnight at scale 0 (3 bytes)" do
      wire = <<0, 0, 0>>
      meta = %{type_code: 0x29, scale: 0}

      assert DTType.decode(wire, meta) == ~T[00:00:00]
    end

    test "decodes 12:30:45 at scale 0 (3 bytes)" do
      fsec = 12 * 3600 + 30 * 60 + 45
      wire = <<fsec::little-unsigned-24>>
      meta = %{type_code: 0x29, scale: 0}

      assert DTType.decode(wire, meta) == ~T[12:30:45]
    end

    test "decodes 12:30:45 at scale 4 (4 bytes)" do
      fsec = 12 * 3600 * 10_000 + 30 * 60 * 10_000 + 45 * 10_000
      wire = <<fsec::little-unsigned-32>>
      meta = %{type_code: 0x29, scale: 4}

      assert DTType.decode(wire, meta) == ~T[12:30:45.0000]
    end

    test "decodes 12:30:45 at scale 7 (5 bytes)" do
      fsec = 12 * 3600 * 10_000_000 + 30 * 60 * 10_000_000 + 45 * 10_000_000
      wire = <<fsec::little-unsigned-40>>
      meta = %{type_code: 0x29, scale: 7}

      # scale 7 > 6, truncated to microseconds (scale 6)
      assert DTType.decode(wire, meta) == ~T[12:30:45.000000]
    end

    test "decodes time with fractional seconds at scale 3" do
      # 12:30:45.123 at scale 3: (12*3600+30*60+45)*1000 + 123 = 45045123
      fsec = (12 * 3600 + 30 * 60 + 45) * 1_000 + 123
      wire = <<fsec::little-unsigned-32>>
      meta = %{type_code: 0x29, scale: 3}

      result = DTType.decode(wire, meta)
      assert result.hour == 12
      assert result.minute == 30
      assert result.second == 45
      {usec, precision} = result.microsecond
      assert precision == 3
      assert usec == 123_000
    end
  end

  # -------------------------------------------------------------------
  # decode — smalldatetime (0x3A)
  # -------------------------------------------------------------------

  describe "decode/2 smalldatetime" do
    @meta_sdt %{type_code: 0x3A}

    test "decodes 1900-01-01 00:00" do
      wire = <<0::little-unsigned-16, 0::little-unsigned-16>>

      assert DTType.decode(wire, @meta_sdt) ==
               ~N[1900-01-01 00:00:00]
    end

    test "decodes 2000-01-01 00:30" do
      days =
        :calendar.date_to_gregorian_days({2000, 1, 1}) -
          @year_1900_days

      wire = <<days::little-unsigned-16, 30::little-unsigned-16>>

      assert DTType.decode(wire, @meta_sdt) ==
               ~N[2000-01-01 00:30:00]
    end

    test "decodes with full hour/minute" do
      days =
        :calendar.date_to_gregorian_days({2024, 6, 15}) -
          @year_1900_days

      mins = 14 * 60 + 30
      wire = <<days::little-unsigned-16, mins::little-unsigned-16>>

      assert DTType.decode(wire, @meta_sdt) ==
               ~N[2024-06-15 14:30:00]
    end
  end

  # -------------------------------------------------------------------
  # decode — datetime (0x3D)
  # -------------------------------------------------------------------

  describe "decode/2 datetime" do
    @meta_dt %{type_code: 0x3D}

    test "decodes 1900-01-01 00:00:00.000" do
      wire = <<0::little-signed-32, 0::little-unsigned-32>>

      assert DTType.decode(wire, @meta_dt) ==
               ~N[1900-01-01 00:00:00.000]
    end

    test "decodes 2000-01-01 12:00:00.000" do
      days =
        :calendar.date_to_gregorian_days({2000, 1, 1}) -
          @year_1900_days

      secs300 = round(12 * 3600 * 1000 / (10 / 3))
      wire = <<days::little-signed-32, secs300::little-unsigned-32>>

      result = DTType.decode(wire, @meta_dt)
      assert result.year == 2000
      assert result.month == 1
      assert result.day == 1
      assert result.hour == 12
      assert result.minute == 0
      assert result.second == 0
    end

    test "decodes 2000-01-01 12:34:56.123" do
      days =
        :calendar.date_to_gregorian_days({2000, 1, 1}) -
          @year_1900_days

      ms = ((12 * 60 + 34) * 60 + 56) * 1_000 + 123
      secs300 = round(ms / (10 / 3))
      wire = <<days::little-signed-32, secs300::little-unsigned-32>>

      result = DTType.decode(wire, @meta_dt)
      assert result.year == 2000
      assert result.month == 1
      assert result.day == 1
      assert result.hour == 12
      assert result.minute == 34
      assert result.second == 56
    end
  end

  # -------------------------------------------------------------------
  # decode — datetimen (0x6F)
  # -------------------------------------------------------------------

  describe "decode/2 datetimen" do
    test "nil returns nil" do
      meta = %{type_code: 0x6F, length: 8}
      assert DTType.decode(nil, meta) == nil
    end

    test "delegates 4-byte to smalldatetime" do
      meta = %{type_code: 0x6F, length: 4}
      wire = <<0::little-unsigned-16, 0::little-unsigned-16>>

      assert DTType.decode(wire, meta) ==
               ~N[1900-01-01 00:00:00]
    end

    test "delegates 8-byte to datetime" do
      meta = %{type_code: 0x6F, length: 8}
      wire = <<0::little-signed-32, 0::little-unsigned-32>>

      assert DTType.decode(wire, meta) ==
               ~N[1900-01-01 00:00:00.000]
    end
  end

  # -------------------------------------------------------------------
  # decode — datetime2n (0x2A)
  # -------------------------------------------------------------------

  describe "decode/2 datetime2n" do
    test "nil returns nil" do
      meta = %{type_code: 0x2A, scale: 7}
      assert DTType.decode(nil, meta) == nil
    end

    test "decodes 2024-01-01 12:30:45 at scale 0" do
      time_fsec = 12 * 3600 + 30 * 60 + 45
      time_bytes = <<time_fsec::little-unsigned-24>>

      days = :calendar.date_to_gregorian_days({2024, 1, 1}) - 366
      date_bytes = <<days::little-24>>

      wire = time_bytes <> date_bytes
      meta = %{type_code: 0x2A, scale: 0}

      assert DTType.decode(wire, meta) ==
               ~N[2024-01-01 12:30:45]
    end

    test "decodes 2024-06-15 14:30:00 at scale 4" do
      fsec = (14 * 3600 + 30 * 60 + 0) * 10_000
      time_bytes = <<fsec::little-unsigned-32>>

      days = :calendar.date_to_gregorian_days({2024, 6, 15}) - 366
      date_bytes = <<days::little-24>>

      wire = time_bytes <> date_bytes
      meta = %{type_code: 0x2A, scale: 4}

      assert DTType.decode(wire, meta) ==
               ~N[2024-06-15 14:30:00.0000]
    end

    test "decodes at scale 7" do
      fsec = (10 * 3600 + 15 * 60 + 30) * 10_000_000
      time_bytes = <<fsec::little-unsigned-40>>

      days = :calendar.date_to_gregorian_days({2024, 3, 5}) - 366
      date_bytes = <<days::little-24>>

      wire = time_bytes <> date_bytes
      meta = %{type_code: 0x2A, scale: 7}

      result = DTType.decode(wire, meta)
      assert result.year == 2024
      assert result.month == 3
      assert result.day == 5
      assert result.hour == 10
      assert result.minute == 15
      assert result.second == 30
    end
  end

  # -------------------------------------------------------------------
  # decode — datetimeoffsetn (0x2B)
  # -------------------------------------------------------------------

  describe "decode/2 datetimeoffsetn" do
    test "nil returns nil" do
      meta = %{type_code: 0x2B, scale: 7}
      assert DTType.decode(nil, meta) == nil
    end

    test "decodes UTC datetime at scale 0" do
      # Wire stores UTC time + 0 offset
      time_fsec = 12 * 3600 + 30 * 60 + 45
      time_bytes = <<time_fsec::little-unsigned-24>>

      days = :calendar.date_to_gregorian_days({2024, 1, 1}) - 366
      date_bytes = <<days::little-24>>

      offset_bytes = <<0::little-signed-16>>

      wire = time_bytes <> date_bytes <> offset_bytes
      meta = %{type_code: 0x2B, scale: 0}

      result = DTType.decode(wire, meta)
      assert %DateTime{} = result
      assert result.year == 2024
      assert result.month == 1
      assert result.day == 1
      assert result.hour == 12
      assert result.minute == 30
      assert result.second == 45
      assert result.utc_offset == 0
    end

    test "decodes positive offset (+05:30 = 330 min) as UTC" do
      # Wire stores UTC time (07:00:45 UTC) + offset 330 min
      # Decode returns UTC DateTime (offset discarded)
      time_fsec = 7 * 3600 + 0 * 60 + 45
      time_bytes = <<time_fsec::little-unsigned-24>>

      days = :calendar.date_to_gregorian_days({2024, 1, 1}) - 366
      date_bytes = <<days::little-24>>

      offset_bytes = <<330::little-signed-16>>

      wire = time_bytes <> date_bytes <> offset_bytes
      meta = %{type_code: 0x2B, scale: 0}

      result = DTType.decode(wire, meta)
      assert %DateTime{} = result
      # Returns UTC time, not local time
      assert result.hour == 7
      assert result.minute == 0
      assert result.second == 45
      assert result.utc_offset == 0
    end
  end

  # -------------------------------------------------------------------
  # encode — Date
  # -------------------------------------------------------------------

  describe "encode/2 Date" do
    test "nil produces daten null" do
      {type_code, meta, value} = DTType.encode(nil, %{type: :date})

      assert type_code == 0x28
      assert IO.iodata_to_binary(meta) == <<0x28>>
      assert IO.iodata_to_binary(value) == <<0x00>>
    end

    test "~D[2024-01-01] encodes to 3-byte LE days" do
      {type_code, meta, value} = DTType.encode(~D[2024-01-01], %{type: :date})

      assert type_code == 0x28
      assert IO.iodata_to_binary(meta) == <<0x28>>

      value_bin = IO.iodata_to_binary(value)
      <<0x03, days_wire::binary-3>> = value_bin
      <<days::little-24>> = days_wire

      expected_days =
        :calendar.date_to_gregorian_days({2024, 1, 1}) - 366

      assert days == expected_days
    end
  end

  # -------------------------------------------------------------------
  # encode — Time
  # -------------------------------------------------------------------

  describe "encode/2 Time" do
    test "nil produces timen null" do
      {type_code, meta, value} = DTType.encode(nil, %{type: :time})

      assert type_code == 0x29
      meta_bin = IO.iodata_to_binary(meta)
      <<0x29, _scale>> = meta_bin
      assert IO.iodata_to_binary(value) == <<0x00>>
    end

    test "~T[12:30:45] encodes correctly" do
      time = ~T[12:30:45]
      {type_code, _meta, value} = DTType.encode(time, %{type: :time})

      assert type_code == 0x29
      value_bin = IO.iodata_to_binary(value)
      assert byte_size(value_bin) > 1
    end

    test "~T[12:30:45.123456] preserves microseconds" do
      time = ~T[12:30:45.123456]
      {type_code, meta, value} = DTType.encode(time, %{type: :time})

      assert type_code == 0x29
      meta_bin = IO.iodata_to_binary(meta)
      <<0x29, scale>> = meta_bin
      assert scale == 6

      value_bin = IO.iodata_to_binary(value)
      assert byte_size(value_bin) > 1
    end
  end

  # -------------------------------------------------------------------
  # encode — NaiveDateTime (datetime2)
  # -------------------------------------------------------------------

  describe "encode/2 NaiveDateTime" do
    test "nil produces datetime2n null" do
      {type_code, meta, value} =
        DTType.encode(nil, %{type: :datetime2})

      assert type_code == 0x2A
      meta_bin = IO.iodata_to_binary(meta)
      <<0x2A, _scale>> = meta_bin
      assert IO.iodata_to_binary(value) == <<0x00>>
    end

    test "~N[2024-01-01 12:30:45] encodes correctly" do
      ndt = ~N[2024-01-01 12:30:45]
      {type_code, meta, value} =
        DTType.encode(ndt, %{type: :datetime2})

      assert type_code == 0x2A
      meta_bin = IO.iodata_to_binary(meta)
      <<0x2A, scale>> = meta_bin
      assert scale == 0

      value_bin = IO.iodata_to_binary(value)
      # 1 byte length + 3 bytes time + 3 bytes date = 7
      assert byte_size(value_bin) == 7
    end
  end

  # -------------------------------------------------------------------
  # encode — DateTime (datetimeoffset)
  # -------------------------------------------------------------------

  describe "encode/2 DateTime" do
    test "nil produces datetimeoffsetn null" do
      {type_code, meta, value} =
        DTType.encode(nil, %{type: :datetimeoffset})

      assert type_code == 0x2B
      meta_bin = IO.iodata_to_binary(meta)
      <<0x2B, _scale>> = meta_bin
      assert IO.iodata_to_binary(value) == <<0x00>>
    end

    test "UTC DateTime encodes correctly" do
      {:ok, dt} = DateTime.new(~D[2024-01-01], ~T[12:30:45], "Etc/UTC")
      {type_code, _meta, value} =
        DTType.encode(dt, %{type: :datetimeoffset})

      assert type_code == 0x2B
      value_bin = IO.iodata_to_binary(value)
      assert byte_size(value_bin) > 1
    end
  end

  # -------------------------------------------------------------------
  # param_descriptor
  # -------------------------------------------------------------------

  describe "param_descriptor/2" do
    test "date" do
      assert DTType.param_descriptor(~D[2024-01-01], %{type: :date}) ==
               "date"
    end

    test "time with scale" do
      time = ~T[12:30:45.123456]

      assert DTType.param_descriptor(time, %{type: :time}) ==
               "time(6)"
    end

    test "time nil" do
      assert DTType.param_descriptor(nil, %{type: :time}) == "time"
    end

    test "datetime" do
      assert DTType.param_descriptor(nil, %{type: :datetime}) ==
               "datetime"
    end

    test "smalldatetime" do
      assert DTType.param_descriptor(nil, %{type: :smalldatetime}) ==
               "smalldatetime"
    end

    test "datetime2 with scale" do
      ndt = ~N[2024-01-01 12:30:45.123456]

      assert DTType.param_descriptor(ndt, %{type: :datetime2}) ==
               "datetime2(6)"
    end

    test "datetime2 nil" do
      assert DTType.param_descriptor(nil, %{type: :datetime2}) ==
               "datetime2"
    end

    test "datetimeoffset with scale" do
      {:ok, dt} =
        DateTime.new(~D[2024-01-01], ~T[12:30:45.123], "Etc/UTC")

      assert DTType.param_descriptor(dt, %{type: :datetimeoffset}) ==
               "datetimeoffset(3)"
    end

    test "datetimeoffset nil" do
      assert DTType.param_descriptor(nil, %{type: :datetimeoffset}) ==
               "datetimeoffset"
    end
  end

  # -------------------------------------------------------------------
  # infer
  # -------------------------------------------------------------------

  describe "infer/1" do
    test "Date infers as date" do
      assert {:ok, %{type: :date}} = DTType.infer(~D[2024-01-01])
    end

    test "Time infers as time" do
      assert {:ok, %{type: :time}} = DTType.infer(~T[12:30:00])
    end

    test "NaiveDateTime infers as datetime2" do
      assert {:ok, %{type: :datetime2}} =
               DTType.infer(~N[2024-01-01 12:30:00])
    end

    test "DateTime infers as datetimeoffset" do
      {:ok, dt} =
        DateTime.new(~D[2024-01-01], ~T[12:30:00], "Etc/UTC")

      assert {:ok, %{type: :datetimeoffset}} = DTType.infer(dt)
    end

    test "integer skips" do
      assert :skip = DTType.infer(42)
    end

    test "string skips" do
      assert :skip = DTType.infer("2024-01-01")
    end

    test "nil skips" do
      assert :skip = DTType.infer(nil)
    end
  end

  # -------------------------------------------------------------------
  # encode/decode roundtrips
  # -------------------------------------------------------------------

  describe "encode/decode roundtrip" do
    test "Date roundtrips" do
      original = ~D[2024-06-15]
      {_type, _meta, value_bin} = DTType.encode(original, %{type: :date})
      value = IO.iodata_to_binary(value_bin)
      <<0x03, data::binary-3>> = value

      assert DTType.decode(data, %{type_code: 0x28}) == original
    end

    test "Time roundtrips" do
      original = ~T[14:30:00.123456]
      {_type, meta_bin, value_bin} =
        DTType.encode(original, %{type: :time})

      meta = IO.iodata_to_binary(meta_bin)
      <<0x29, scale>> = meta

      value = IO.iodata_to_binary(value_bin)
      <<_len, data::binary>> = value

      decoded =
        DTType.decode(data, %{type_code: 0x29, scale: scale})

      assert decoded.hour == original.hour
      assert decoded.minute == original.minute
      assert decoded.second == original.second
      {orig_us, _} = original.microsecond
      {dec_us, _} = decoded.microsecond
      assert dec_us == orig_us
    end

    test "NaiveDateTime roundtrips at scale 0" do
      original = ~N[2024-01-15 08:45:30]
      {_type, meta_bin, value_bin} =
        DTType.encode(original, %{type: :datetime2})

      meta = IO.iodata_to_binary(meta_bin)
      <<0x2A, scale>> = meta

      value = IO.iodata_to_binary(value_bin)
      <<_len, data::binary>> = value

      decoded =
        DTType.decode(data, %{type_code: 0x2A, scale: scale})

      assert decoded == original
    end

    test "DateTime UTC roundtrips" do
      {:ok, original} =
        DateTime.new(~D[2024-03-15], ~T[16:20:00], "Etc/UTC")

      {_type, meta_bin, value_bin} =
        DTType.encode(original, %{type: :datetimeoffset})

      meta = IO.iodata_to_binary(meta_bin)
      <<0x2B, scale>> = meta

      value = IO.iodata_to_binary(value_bin)
      <<_len, data::binary>> = value

      decoded =
        DTType.decode(data, %{type_code: 0x2B, scale: scale})

      assert %DateTime{} = decoded
      assert decoded.year == original.year
      assert decoded.month == original.month
      assert decoded.day == original.day
      assert decoded.hour == original.hour
      assert decoded.minute == original.minute
      assert decoded.second == original.second
      assert decoded.utc_offset == 0
    end
  end
end
