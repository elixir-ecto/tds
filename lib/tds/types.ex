defmodule Tds.Types do
  #require Logger
  import Tds.BinaryUtils
  import Tds.Utils

  alias Tds.Parameter
  alias Tds.DateTime
  alias Tds.DateTime2

  @year_1900_days :calendar.date_to_gregorian_days({1900,1,1})
  @days_in_month 30
  @secs_in_min 60
  @secs_in_hour 60 * @secs_in_min
  @secs_in_day 24 * @secs_in_hour

  @tds_data_type_null           0x1F
  @tds_data_type_tinyint        0x30
  @tds_data_type_bit            0x32
  @tds_data_type_smallint       0x34
  @tds_data_type_int            0x38
  @tds_data_type_smalldatetime  0x3A
  @tds_data_type_real           0x3B
  @tds_data_type_money          0x3C
  @tds_data_type_datetime       0x3D
  @tds_data_type_float          0x3E
  @tds_data_type_smallmoney     0x7A
  @tds_data_type_bigint         0x7F

  @fixed_data_types [
    @tds_data_type_null,
    @tds_data_type_tinyint,
    @tds_data_type_bit,
    @tds_data_type_smallint,
    @tds_data_type_int,
    @tds_data_type_smalldatetime,
    @tds_data_type_real,
    @tds_data_type_money,
    @tds_data_type_datetime,
    @tds_data_type_float,
    @tds_data_type_smallmoney,
    @tds_data_type_bigint
  ]

  @tds_data_type_uniqueidentifier 0x24
  @tds_data_type_intn             0x26
  @tds_data_type_decimal          0x37 #legacy
  @tds_data_type_numeric          0x3F #legacy
  @tds_data_type_bitn             0x68
  @tds_data_type_decimaln         0x6A
  @tds_data_type_numericn         0x6C
  @tds_data_type_floatn           0x6D
  @tds_data_type_moneyn           0x6E
  @tds_data_type_datetimen        0x6F
  @tds_data_type_daten            0x28
  @tds_data_type_timen            0x29
  @tds_data_type_datetime2n       0x2A
  @tds_data_type_datetimeoffsetn  0x2B
  @tds_data_type_char             0x2F
  @tds_data_type_varchar          0x27
  @tds_data_type_binary           0x2D
  @tds_data_type_varbinary        0x25
  @tds_data_type_bigvarbinary     0xA5
  @tds_data_type_bigvarchar       0xA7
  @tds_data_type_bigbinary        0xAD
  @tds_data_type_bigchar          0xAF
  @tds_data_type_nvarchar         0xE7
  @tds_data_type_nchar            0xEF
  @tds_data_type_xml              0xF1
  @tds_data_type_udt              0xF0
  @tds_data_type_text             0x23
  @tds_data_type_image            0x22
  @tds_data_type_ntext            0x63
  @tds_data_type_variant          0x62

  @variable_data_types [
    @tds_data_type_uniqueidentifier,
    @tds_data_type_intn,
    @tds_data_type_decimal,
    @tds_data_type_numeric,
    @tds_data_type_bitn,
    @tds_data_type_decimaln,
    @tds_data_type_numericn,
    @tds_data_type_floatn,
    @tds_data_type_moneyn,
    @tds_data_type_datetimen,
    @tds_data_type_daten,
    @tds_data_type_timen,
    @tds_data_type_datetime2n,
    @tds_data_type_datetimeoffsetn,
    @tds_data_type_char,
    @tds_data_type_varchar,
    @tds_data_type_binary,
    @tds_data_type_varbinary,
    @tds_data_type_bigvarbinary,
    @tds_data_type_bigvarchar,
    @tds_data_type_bigbinary,
    @tds_data_type_bigchar,
    @tds_data_type_nvarchar,
    @tds_data_type_nchar,
    @tds_data_type_xml,
    @tds_data_type_udt,
    @tds_data_type_text,
    @tds_data_type_image,
    @tds_data_type_ntext,
    @tds_data_type_variant
  ]

  @tds_plp_marker 0xffff
  @tds_plp_null 0xffffffffffffffff
  @tds_plp_unknown 0xfffffffffffffffe

  #
  #  Data Type Decoders
  #

  def decode_info(<<data_type_code::unsigned-8, tail::binary>>) when data_type_code in @fixed_data_types do
    length =
      cond do
        data_type_code == @tds_data_type_null -> 0
        data_type_code in [
          @tds_data_type_tinyint,
          @tds_data_type_bit
        ] -> 1
        data_type_code == @tds_data_type_smallint -> 2
        data_type_code in [
          @tds_data_type_int,
          @tds_data_type_smalldatetime,
          @tds_data_type_real,
          @tds_data_type_smallmoney
        ] -> 4
        data_type_code in [
          @tds_data_type_datetime,
          @tds_data_type_float,
          @tds_data_type_money,
          @tds_data_type_bigint
        ] -> 8
      end
    {%{data_type: :fixed, data_type_code: data_type_code, length: length},tail}
  end

  def decode_info(<<data_type_code::unsigned-8, tail::binary>>) when data_type_code in @variable_data_types do
    col_info = %{data_type: :variable, data_type_code: data_type_code}
    cond do
      data_type_code == @tds_data_type_daten ->
        length = 3
        col_info = col_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)
      data_type_code in [
        @tds_data_type_timen,
        @tds_data_type_datetime2n,
        @tds_data_type_datetimeoffsetn
      ] ->
        <<scale::unsigned-8, tail::binary>> = tail
        length =
          cond do
            scale in [0, 1, 2] -> 3
            scale in [3, 4] -> 4
            scale in [5, 6, 7] -> 5
            true -> nil
          end
        col_info = col_info
          |> Map.put(:scale, scale)

        length =
          case data_type_code do
            @tds_data_type_datetime2n -> length + 3
            @tds_data_type_datetimeoffsetn -> length + 5
            _ -> length
          end
        col_info = col_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)
      data_type_code in [
        @tds_data_type_uniqueidentifier,
        @tds_data_type_intn,
        @tds_data_type_decimal,
        @tds_data_type_decimaln,
        @tds_data_type_numeric,
        @tds_data_type_numericn,
        @tds_data_type_bitn,
        @tds_data_type_floatn,
        @tds_data_type_moneyn,
        @tds_data_type_datetimen,
        @tds_data_type_char,
        @tds_data_type_varchar,
        @tds_data_type_binary,
        @tds_data_type_varbinary
      ] ->
        <<length::little-unsigned-8, tail::binary>> = tail
        if data_type_code in [
            @tds_data_type_numericn,
            @tds_data_type_decimaln
          ] do
          <<precision::unsigned-8, scale::unsigned-8, tail::binary>> = tail
          col_info = col_info
            |> Map.put(:precision, precision)
            |> Map.put(:scale, scale)
        end
        col_info = col_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)
      data_type_code == @tds_data_type_xml ->
        <<schema::unsigned-8, tail::binary>> = tail
        if schema == 1 do
          # TODO should stick a raise in here??
          # BVarChar dbname
          # BVarChar owning schema
          # USVarChar xml schema collection
        end
        col_info = col_info
          |> Map.put(:data_reader, :plp)
      data_type_code in [
        @tds_data_type_bigvarbinary,
        @tds_data_type_bigvarchar,
        @tds_data_type_bigbinary,
        @tds_data_type_bigchar,
        @tds_data_type_nvarchar,
        @tds_data_type_nchar,
        @tds_data_type_udt
      ] ->
        <<length::little-unsigned-16, tail::binary>> = tail
        if data_type_code in [
          @tds_data_type_bigvarchar,
          @tds_data_type_bigchar,
          @tds_data_type_nvarchar,
          @tds_data_type_nchar
          ] do
          <<collation::binary-5, tail::binary>> = tail
          col_info = col_info
            |> Map.put(:collation, collation)
        end
        if length == 0xFFFF do
          col_info = col_info
            |> Map.put(:data_reader, :plp)
        else
          col_info = col_info
            |> Map.put(:data_reader, :shortlen)
        end
        col_info = col_info
          |> Map.put(:length, length)
      data_type_code in [
        @tds_data_type_text,
        @tds_data_type_image,
        @tds_data_type_ntext,
        @tds_data_type_variant
      ] ->
        <<length::signed-32, tail::binary>> = tail
        col_info = col_info
          |> Map.put(:length, length)
        cond do
          data_type_code in [@tds_data_type_text, @tds_data_type_ntext] ->

            <<collation::binary-5, tail::binary>> = tail
            col_info = col_info
              |> Map.put(:collation, collation)
              |> Map.put(:data_reader, :longlen)
            <<numparts::signed-8, tail::binary>> = tail
            tail =
            Enum.reduce([1..numparts], tail, fn(_, acc) ->
              <<tsize::little-unsigned-16, _table_name::binary-size(tsize)-unit(16), tail::binary>> = acc
              tail
            end)
          data_type_code == @tds_data_type_image ->
            # TODO NumBarts Reader
            <<numparts::signed-8, tail::binary>> = tail
            tail =
            Enum.reduce([1..numparts], tail, fn(_, acc) ->
              <<size::unsigned-16, _str::size(size)-unit(16), tail::binary>> = acc
              tail
            end)
            col_info = col_info
              |> Map.put(:data_reader, :bytelen)
          data_type_code == @tds_data_type_variant ->
            col_info = col_info
              |> Map.put(:data_reader, :variant)
          true -> nil
        end


    end
    {col_info,tail}
  end

  #
  #  Data Decoders
  #

  def decode_data(%{data_type: :fixed, data_type_code: data_type_code, length: length}, <<tail::binary>>) do
    <<value_binary::binary-size(length)-unit(8), tail::binary>> = tail
    value = case data_type_code do
      @tds_data_type_null ->
        nil
      @tds_data_type_bit ->
        value_binary != <<0x00>>
      @tds_data_type_smalldatetime -> decode_smalldatetime(value_binary)
      @tds_data_type_smallmoney -> decode_smallmoney(value_binary)
      @tds_data_type_real ->
        <<value::little-float-32>> = value_binary
        Float.round value, 4
      @tds_data_type_datetime -> decode_datetime(value_binary)
      @tds_data_type_float ->
        <<value::little-float-64>> = value_binary
        Float.round value, 8
      @tds_data_type_money -> decode_money(value_binary)
      _ -> <<value::little-signed-size(length)-unit(8)>> = value_binary
        value
    end
    {value, tail}
  end

  # ByteLength Types
  def decode_data(%{data_reader: :bytelen}, <<0x00, tail::binary>>), do: {nil, tail}
  def decode_data(%{data_type_code: data_type_code, data_reader: :bytelen, length: length} = data_info, <<size::unsigned-8, data::binary-size(size), tail::binary>>) do
      value = cond do
        data_type_code == @tds_data_type_daten -> decode_date(data)
        data_type_code == @tds_data_type_timen -> decode_time(data_info[:scale], data)
        data_type_code == @tds_data_type_datetime2n -> decode_datetime2(data_info[:scale], data)
        data_type_code == @tds_data_type_datetimeoffsetn -> decode_datetimeoffset(data_info[:scale], data)
        data_type_code == @tds_data_type_uniqueidentifier -> decode_uuid(data)
        data_type_code == @tds_data_type_intn ->
          data = data <> tail
          case length do
            1 ->
              <<value::unsigned-8, tail::binary>> = data
              value
            2 ->
              <<value::little-signed-16, tail::binary>> = data
              value
            4 ->
              <<value::little-signed-32, tail::binary>> = data
              value
            8 ->
              <<value::little-signed-64, tail::binary>> = data
              value
          end
        data_type_code in [
          @tds_data_type_decimal,
          @tds_data_type_numeric,
          @tds_data_type_decimaln,
          @tds_data_type_numericn
        ] ->
          decode_decimal(data_info[:precision], data_info[:scale], data)
        data_type_code == @tds_data_type_bitn ->
          data != <<0x00>>
        data_type_code == @tds_data_type_floatn ->
          data = data <> tail
          case length do
            4 ->
              <<value::little-float-32, tail::binary>> = data
              value
            8 ->
              <<value::little-float-64, tail::binary>> = data
              value
          end
        data_type_code == @tds_data_type_moneyn ->
          case length do
            4 -> decode_smallmoney(data)
            8 -> decode_money(data)
          end
        data_type_code == @tds_data_type_datetimen ->
          case length do
            4 -> decode_smalldatetime(data)
            8 -> decode_datetime(data)
          end
        data_type_code in [
          @tds_data_type_char,
          @tds_data_type_varchar
        ] -> decode_char(data_info[:collation], data)
        data_type_code in [
          @tds_data_type_binary,
          @tds_data_type_varbinary
        ] -> data
      end
      {value, tail}
  end

  # ShortLength Types
  def decode_data(%{data_reader: :shortlen}, <<0xFF, 0xFF, tail::binary>>), do: {nil, tail}
  def decode_data(%{data_type_code: data_type_code, data_reader: :shortlen} = data_info, <<size::little-unsigned-16, data::binary-size(size), tail::binary>>) do
    value = cond do
      data_type_code in [
        @tds_data_type_bigvarchar,
        @tds_data_type_bigchar
      ] ->
        decode_char(data_info[:collation], data)
      data_type_code in [
        @tds_data_type_bigvarbinary,
        @tds_data_type_bigbinary
      ] ->
        data
      data_type_code in [
        @tds_data_type_nvarchar,
        @tds_data_type_nchar
      ] ->
        decode_nchar(data)
      data_type_code == @tds_data_type_udt ->
        decode_udt(data_info, data)
    end
    {value, tail}
  end

  def decode_data(%{data_reader: :longlen}, <<0x00, tail::binary>>), do: {nil, tail}
  def decode_data(%{data_type_code: data_type_code, data_reader: :longlen} = data_info, <<text_ptr_size::unsigned-8, _text_ptr::size(text_ptr_size)-unit(8), _timestamp::unsigned-64, size::little-signed-32, data::binary-size(size)-unit(8), tail::binary>>) do
    value =
    case data_type_code do
      @tds_data_type_text -> decode_char(data_info[:collation], data)
      @tds_data_type_ntext -> decode_nchar(data)
      @tds_data_type_image -> data
      _ -> nil
    end
    {value, tail}
  end

  # TODO Variant Types

  def decode_data(%{data_reader: :plp}, <<@tds_plp_null, tail::binary>>), do: {nil, tail}
  def decode_data(%{data_type_code: data_type_code, data_reader: :plp} = data_info, <<_size::little-unsigned-64, tail::binary>>) do
    {data, tail} = decode_plp_chunk(tail, <<>>)
    value = cond do
      data_type_code == @tds_data_type_xml ->
        decode_xml(data_info, data)
      data_type_code in [
        @tds_data_type_bigvarchar,
        @tds_data_type_bigchar,
        @tds_data_type_text
      ] ->
        decode_char(data_info[:collation], data)
      data_type_code in [
        @tds_data_type_bigvarbinary,
        @tds_data_type_bigbinary,
        @tds_data_type_image
      ] ->
        data
      data_type_code in [
        @tds_data_type_nvarchar,
        @tds_data_type_nchar,
        @tds_data_type_ntext
      ] ->
        decode_nchar(data)
      data_type_code == @tds_data_type_udt ->
        decode_udt(data_info, data)
    end
    {value, tail}
  end

  def decode_plp_chunk(<<chunksize::little-unsigned-32, tail::binary>>, buf) when chunksize == 0, do: {buf, tail}
  def decode_plp_chunk(<<chunksize::little-unsigned-32, chunk::binary-size(chunksize)-unit(8), tail::binary>>, buf) do
    decode_plp_chunk(tail, buf <> chunk)
  end

  def decode_smallmoney(<<money::little-signed-32>>) do
    Float.round(money * 0.0001, 4)
  end

  def decode_money(<<money_m::little-unsigned-32, money_l::little-unsigned-32>>) do
    <<money::signed-64>> = <<money_m::32>> <> <<money_l::32>>
    Float.round(money * 0.0001, 4)
  end

  #UUID
  def decode_uuid(<<v1::little-signed-32, v2::little-signed-16, v3::little-signed-16, v4::signed-64>>) do
    <<v1::32, v2::16, v3::16, v4::64>>
  end

  def encode_uuid(<<v1::32, v2::16, v3::16, v4::64>>) do
    <<v1::little-signed-32, v2::little-signed-16, v3::little-signed-16, v4::signed-64>>
  end

  def decode_decimal(precision, scale, <<sign::int8, value::binary>>) do
    size = byte_size(value)
    <<value::little-size(size)-unit(8)>> = value
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: precision}
    Decimal.set_context d_ctx

    case sign do
      0 -> Decimal.new(-1, value, (scale * -1))
      _ -> Decimal.new( 1, value, (scale * -1))
    end
  end

  def decode_char(_collation, <<data::binary>>) do
    data
  end

  def decode_nchar(<<data::binary>>) do
    data |> :unicode.characters_to_binary({:utf16, :little}, :utf8)
  end

  def decode_xml(_data_info, <<_data::binary>>) do
    # TODO: Decode XML Data
    nil
  end

  def decode_udt(%{}, <<_data::binary>>) do
    # TODO: Decode UDT Data
    nil
  end

  @doc """
  Data Type Encoders
  Encodes the COLMETADATA for the data type
  """
  def encode_data_type(%Parameter{type: type} = param) when type != nil do
    case type do
      :boolean -> encode_binary_type(param)
      :binary -> encode_binary_type(param)
      :string -> encode_string_type(param)
      :integer -> encode_integer_type(param)
      :decimal -> encode_decimal_type(param)
      :float -> encode_float_type(param)
      :datetime -> encode_datetime_type(param)
      :smalldatetime -> encode_smalldatetime_type(param)
      :datetime2 -> encode_datetime2_type(param)
      :datetimeoffset -> encode_datetimeoffset_type(param)
      :date -> encode_date_type(param)
      :time -> encode_time_type(param)
      :uuid -> encode_uuid_type(param)
      _ -> encode_string_type(param)
    end
  end

  def encode_data_type(%Parameter{value: value} = param)
  when value == true or value == false do
    encode_data_type(%{param | type: :boolean})
  end

  def encode_data_type(%Parameter{value: value} = param)
  when is_binary(value) and value == "" do
    encode_data_type(%{param | type: :string})
  end

  def encode_data_type(%Parameter{value: value} = param)
  when is_binary(value) do
    encode_data_type(%{param | type: :binary})
  end

  def encode_data_type(%Parameter{value: value} = param)
  when is_integer(value) and value >= 0 do
    encode_data_type(%{param | type: :integer})
  end

  def encode_data_type(%Parameter{value: value} = param)
  when is_float(value) do
    encode_data_type(%{param | type: :float})
  end

  def encode_data_type(%Parameter{value: value} = param)
  when (is_integer(value) and value < 0) do
    encode_data_type(%{param | value: Decimal.new(value), type: :decimal})
  end

  def encode_data_type(%Parameter{value: {{_,_,_}}} = param) do
    encode_data_type(%{param | type: :date})
  end
  def encode_data_type(%Parameter{value: {{_,_,_,_}}} = param) do
    encode_data_type(%{param | type: :time})
  end


  def encode_data_type(%Parameter{value: %Decimal{}} = param) do
    encode_data_type(%{param | type: :decimal})
  end

  def encode_data_type(%Parameter{value: %DateTime{}} = param) do
    encode_data_type(%{param | type: :datetime})
  end

  def encode_data_type(%Parameter{value: %DateTime2{}} = param) do
    encode_data_type(%{param | type: :datetime2})
  end

  def encode_data_type(%Parameter{value: {{_,_,_},{_,_,_}}} = param) do
    encode_data_type(%{param | type: :datetime})
  end

  # def encode_data_type(%Parameter{value: {{_,_,_},{_,_,_,0}}} = param) do
  #   encode_data_type(%{param | type: :datetime})
  # end

  def encode_data_type(%Parameter{value: {{_,_,_},{_,_,_,_}}} = param) do
    encode_data_type(%{param | type: :datetime2})
  end

  def encode_data_type(%Parameter{value: {{_,_,_},{_,_,_,_},_}} = param) do
    encode_data_type(%{param | type: :datetimeoffset})
  end
  def encode_data_type(%Parameter{value: {{_,_,_},{_,_,_,},_}} = param) do
    encode_data_type(%{param | type: :datetimeoffset})
  end


  def encode_binary_type(%Parameter{value: value} = param)
  when value == "" do
   encode_string_type(param)
  end

  def encode_binary_type(%Parameter{value: value} = param)
  when is_integer(value) do
    %{param | value: <<value>>} |> encode_binary_type
  end

  def encode_binary_type(%Parameter{value: value}) do
    length =
      if value == nil do
        <<0xFF, 0xFF>>
      else
        <<byte_size(value)::little-unsigned-16>>
      end
    type = @tds_data_type_bigvarbinary
    data = <<type>> <> length
    {type, data, []}
  end

  def encode_bit_type(%Parameter{}) do
    type = @tds_data_type_bigvarbinary
    data = <<type, 0x01>>
    {type, data, []}
  end

  def encode_uuid_type(%Parameter{value: value}) do
    length =
      if value == nil do
        0x00
      else
        0x10
      end
    type = @tds_data_type_uniqueidentifier
    data = <<type, length>>
    {type, data, []}
  end

  def encode_string_type(%Parameter{value: value}) do

    collation = <<0x00, 0x00, 0x00, 0x00, 0x00>>
    length =
    if value != nil do
      value = value |> to_little_ucs2
      value_size = byte_size(value)
      cond do
        value_size == 0 or value_size > 8000 ->
          <<0xFF, 0xFF>>
        true ->
          <<value_size::little-2*8>>
      end
    else
      <<0xFF, 0xFF>>
    end
    type = @tds_data_type_nvarchar
    data = <<type>> <> length <> collation
    {type, data, [collation: collation]}
  end

  def encode_integer_type(%Parameter{value: value} = param)
  when value < 0 do
    encode_decimal_type(param)
  end

  def encode_integer_type(%Parameter{value: value})
  when value >= 0 do
    attributes = []
    type = @tds_data_type_intn
    length =
    if value == nil do
      attributes = attributes
        |> Keyword.put(:length, 1)
      <<0x01::int8>>
    else
      value_size = int_type_size(value)
      # cond do
      #   value_size == 1 ->
      #     data_type_code = @tds_data_type_tinyint #Enum.find(data_types, fn(x) -> x[:name] == :tinyint end)
      #   value_size == 2 ->
      #     data_type_code = @tds_data_type_smallint #Enum.find(data_types, fn(x) -> x[:name] == :smallint end)
      #   value_size > 2 and value_size <= 4 ->
      #     data_type_code = @tds_data_type_int #Enum.find(data_types, fn(x) -> x[:name] == :int end)
      #   value_size > 4 and value_size <= 8 ->
      #     data_type_code = @tds_data_type_bigint #Enum.find(data_types, fn(x) -> x[:name] == :bigint end)
      # end
      attributes = attributes
        |> Keyword.put(:length, value_size)
      <<value_size>>
    end
    data = <<type>> <> length
    {type, data, attributes}
  end

  def encode_decimal_type(%Parameter{value: nil} = param) do
    encode_binary_type(param)
  end
  def encode_decimal_type(%Parameter{value: value}) do
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context d_ctx
    value_list = value
      |> Decimal.abs
      |> Decimal.to_string(:normal)
      |> String.split(".")
    {precision, scale} =
      case value_list do
        [p,s] ->
          {String.length(p) + String.length(s), String.length(s)}
        [p] ->
          {String.length(p), 0}
      end

    dec_abs = value
      |> Decimal.abs
    value = dec_abs.coef
      |> :binary.encode_unsigned(:little)
    value_size = byte_size(value)

    len =
      cond do
        precision <= 9 -> 4
        precision <= 19 -> 8
        precision <= 28 -> 12
        precision <= 38 -> 16
      end
    padding = len - value_size
    value_size = value_size + padding + 1

    type = @tds_data_type_decimaln
    data = <<type, value_size, precision, scale>>
    {type, data, precision: precision, scale: scale}
  end

  def encode_float_type(%Parameter{value: nil} = param) do
    encode_decimal_type(param)
  end
  def encode_float_type(%Parameter{value: value} = param) when is_float(value) do
    value = value |> Decimal.new
    encode_float_type(%{param | value: value})
  end
  def encode_float_type(%Parameter{value: %Decimal{} = value}) do
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context d_ctx
    value_list = value
      |> Decimal.abs
      |> Decimal.to_string(:normal)
      |> String.split(".")
    {precision, scale} =
      case value_list do
        [p,s] ->
          {String.length(p) + String.length(s), String.length(s)}
        [p] ->
          {String.length(p), 0}
      end

    dec_abs = value
      |> Decimal.abs
    value = dec_abs.coef
      |> :binary.encode_unsigned(:little)
    value_size = byte_size(value)

    len =
      cond do
        precision <= 9 -> 4
        precision <= 19 -> 8
      end
    padding = len - value_size
    value_size = value_size + padding

    type = @tds_data_type_floatn
    data = <<type, value_size>>
    {type, data, precision: precision, scale: scale}
  end

  @doc """
  Creates the Parameter Descriptor for the selected type
  """
  def encode_param_descriptor(%Parameter{name: name, value: value, type: type} = param) when type != nil do
    desc = case type do
      :uuid -> "uniqueidentifier"
      :datetime -> "datetime"
      :datetime2 -> "datetime2"
      :datetimeoffset ->  "datetimeoffset"
      :date -> "date"
      :time -> "time"
      :smalldatetime -> "smalldatetime"
      :binary -> encode_binary_descriptor(value)
      :string ->
        length =
          if value == nil do
            0
          else
            String.length(value)
          end
        if length <= 0, do: length = 1
        if length > 4000, do: length = "max"
        "nvarchar(#{length})"
      :integer ->
        if value >= 0 do
          "bigint"
        else
          precision = value
            |> Integer.to_string
            |> String.length
          "decimal(#{precision-1}, 0)"
        end
      :decimal -> encode_decimal_descriptor(param)
      :float -> encode_float_descriptor(param)
      :boolean -> "bit"
      _ ->
        length =
          if value == nil do
            0
          else
            String.length(value)
          end
        if length <= 0, do: length = 1
        if length > 4000, do: length = "max"
        "nvarchar(#{length})"
    end

    "#{name} #{desc}"
  end

  @doc """
  Implictly Selected Types
  """
  # nil
  def encode_param_descriptor(%Parameter{value: nil} = param) do
    #Logger.debug "Param Descriptor nil"
    param = %{param | type: :boolean}
    encode_param_descriptor(param)
  end

  # Boolean
  def encode_param_descriptor(%Parameter{value: value} = param)
  when value == true or value == false do
    param = %{param | type: :boolean}
    encode_param_descriptor(param)
  end

  # DateTime
  def encode_param_descriptor(%Parameter{value: %Tds.DateTime{}} = param) do
    param = %{param | type: :datetime}
    encode_param_descriptor(param)
  end
  def encode_param_descriptor(%Parameter{value: {{_,_,_},{_,_,_}}} = param) do
    param = %{param | type: :datetime}
    encode_param_descriptor(param)
  end

  #DateTime2
  def encode_param_descriptor(%Parameter{value: %Tds.DateTime2{}} = param) do
    param = %{param | type: :datetime2}
    encode_param_descriptor(param)
  end
  def encode_param_descriptor(%Parameter{value: {{_,_,_},{_,_,_,_}}} = param) do
    #Logger.debug "Param Descriptor datetime2"
    param = %{param | type: :datetime2}
    encode_param_descriptor(param)
  end

  def encode_param_descriptor(%Parameter{value: {{_,_,_},{_,_,_,_},_}} = param) do
    ##Logger.debug "Param Descriptor datetime2"
    encode_param_descriptor %{param | type: :datetimeoffset}
  end
  def encode_param_descriptor(%Parameter{value: {{_,_,_},{_,_,_,},_}} = param) do
    ##Logger.debug "Param Descriptor datetime2"
    encode_param_descriptor %{param | type: :datetimeoffset}
  end


  # Positive Integers
  def encode_param_descriptor(%Parameter{value: value} = param)
  when is_integer(value) and value >= 0 do
    param = %{param | type: :integer}
    encode_param_descriptor(param)
  end

  # Float
  def encode_param_descriptor(%Parameter{value: value} = param)
  when is_float(value) do
    param = %{param | type: :float}
    encode_param_descriptor(param)
  end

  # Negative Integers
  def encode_param_descriptor(%Parameter{value: value} = param)
  when is_integer(value) and value < 0 do
    param = %{param | type: :decimal, value: Decimal.new(value)}
    encode_param_descriptor(param)
  end

  # Decimal
  def encode_param_descriptor(%Parameter{value: %Decimal{}} = param) do
    param = %{param | type: :decimal}
    encode_param_descriptor(param)
  end

  # Binary
  def encode_param_descriptor(%Parameter{value: value} = param)
  when is_binary(value) and value == "" do
    #Logger.debug "Param Descriptor String"
    param = %{param | type: :string}
    encode_param_descriptor(param)
  end

  def encode_param_descriptor(%Parameter{value: value} = param)
  when is_binary(value) do
    param = %{param | type: :binary}
    encode_param_descriptor(param)
  end

  @doc """
  Decimal Type Parameter Descriptor
  """
  def encode_decimal_descriptor(%Parameter{value: nil}), do: encode_binary_descriptor(nil)
  def encode_decimal_descriptor(%Parameter{value: value} = param) when is_float(value) do
    param = param
     |> Map.put(:value, Decimal.new(value))
    encode_decimal_descriptor(param)
  end

  def encode_decimal_descriptor(%Parameter{value: %Decimal{} = dec}) do
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context d_ctx
    value_list = dec
      |> Decimal.abs
      |> Decimal.to_string(:normal)
      |> String.split(".")
    {precision, scale} =
      case value_list do
        [p,s] ->
          {String.length(p) + String.length(s), String.length(s)}
        [p] ->
          {String.length(p), 0}
      end
    "decimal(#{precision}, #{scale})"
  end
  def encode_decimal_descriptor(%Parameter{type: :decimal} = param) do
    encode_decimal_descriptor(%{param | value: Decimal.new()})
  end

  @doc """
  Float Type Parameter Descriptor
  """
  def encode_float_descriptor(%Parameter{value: nil}), do: "decimal(1,0)"
  def encode_float_descriptor(%Parameter{value: value} = param) when is_float(value) do
    param = param
     |> Map.put(:value, Decimal.new(value))
     encode_float_descriptor(param)
  end
  def encode_float_descriptor(%Parameter{value: %Decimal{} = dec}) do
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context d_ctx
    value_list = dec
      |> Decimal.abs
      |> Decimal.to_string(:normal)
      |> String.split(".")
    precision =
      case value_list do
        [p,s] ->
          String.length(p) + String.length(s)
        [p] ->
          String.length(p)
      end
    "float(#{precision})"
  end

  @doc """
  Binary Type Parameter Descriptor
  """
  def encode_binary_descriptor(value) when is_integer(value), do: encode_binary_descriptor(<<value>>)
  def encode_binary_descriptor(value) do
    size =
      if value == nil do
        1
      else
        byte_size(value)
      end
    "varbinary(#{size})"
  end

  @doc """
  Data Encoding Binary Types
  """
  def encode_data(@tds_data_type_bigvarbinary = data_type, value, attr)
  when is_integer(value),
    do: encode_data(data_type, <<value>>, attr)

  def encode_data(@tds_data_type_bigvarbinary, value, _) do
    if value != nil do
      <<byte_size(value)::little-unsigned-16>> <> value
    else
      <<@tds_plp_null::little-unsigned-64>>
    end
  end

  @doc """
  Data Encoding String Types
  """
  def encode_data(@tds_data_type_nvarchar, value, _) do
    if value == nil do
      <<@tds_plp_null::little-unsigned-64>>
    else
      value = value |> to_little_ucs2
      value_size = byte_size(value)

      cond do
        value_size == 0 ->
          <<0x00::unsigned-64, 0x00::unsigned-32>>
        value_size > 8000 ->
          encode_plp(value)
        true ->
          <<value_size::little-size(2)-unit(8)>> <> value
      end
    end
  end

  @doc """
  Data Encoding Positive Integers Types
  """
  def encode_data(_, value, _) when is_integer(value) and value >= 0 do
    size = int_type_size(value)
    <<size>> <> <<value::little-signed-size(size)-unit(8)>>
  end

  def encode_data(@tds_data_type_intn, value, _) when value == nil do
    <<0>>
  end
  def encode_data(@tds_data_type_tinyint, value, _) when value == nil do
    <<0>>
  end

  @doc """
  Data Encoding Float Types
  """
  def encode_data(@tds_data_type_floatn, nil, _) do
    <<0>>
  end
  def encode_data(@tds_data_type_floatn, value, _) do
    <<0x04, value::little-float-size(32)>>
  end

  @doc """
  Data Encoding Decimal Types
  """
  def encode_data(@tds_data_type_decimaln, %Decimal{} = value, attr) do
    d_ctx = Decimal.get_context
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context d_ctx
    precision = attr[:precision]
    d = value
      |> Decimal.to_string
      |> Decimal.new
    sign = case d.sign do 1 -> 1; -1 -> 0 end

    d_abs = Decimal.abs d

    value = d_abs.coef

    value_binary = value
      |> :binary.encode_unsigned(:little)
    value_size = byte_size(value_binary)
    len =
      cond do
        precision <= 9 -> 4
        precision <= 19 -> 8
        precision <= 28 -> 12
        precision <= 38 -> 16
      end
    {byte_len, padding} = {len, len - value_size}
    byte_len = byte_len + 1
    value_binary = value_binary <> <<0::size(padding)-unit(8)>>
    <<byte_len>> <> <<sign>> <> value_binary
  end
  def encode_data(@tds_data_type_decimaln, nil, _) do
    <<0x00, 0x00, 0x00, 0x00>>
  end
  def encode_data(@tds_data_type_decimaln = data_type, value, attr) do
    encode_data(data_type, Decimal.new(value), attr)
  end

  @doc """
  Data Encoding UUID Types
  """
  def encode_data(@tds_data_type_uniqueidentifier, value, _) do
    if value != nil do
      <<0x10>> <> encode_uuid(value)
    else
      <<0x00>>
    end
  end

    @doc """
  Data Encoding DateTime Types
  """
  def encode_data(@tds_data_type_daten, value, _attr) do
    data = encode_date(value)
    if data == nil do
      <<0x00>>
    else
      <<0x03>> <> data
    end
  end
  def encode_data(@tds_data_type_timen, value, _attr) do
    #Logger.debug "encode_data_timen"
    data = encode_time(value)
    #Logger.debug "#{inspect data}"
    if data == nil do
      <<0x00>>
    else
      <<0x05>> <> data #0x08 length of binary for scale 7
    end
  end

  def encode_data(@tds_data_type_datetimen, value, attr) do
    #Logger.debug "dtn #{inspect attr}"
    data =
      case attr[:length] do
        4 ->
          encode_smalldatetime(value)
        _ ->
          encode_datetime(value)
      end

    if data == nil do
      <<0x00>>
    else
      <<byte_size(data)::8>> <> data
    end
  end

  def encode_data(@tds_data_type_datetime2n, value, _attr) do
    #Logger.debug "EncodeData #{inspect value}"
    data = encode_datetime2(value)
    if data == nil do
      <<0x00>>
    else
      <<0x08>> <> data #0x08 length of binary for scale 7
    end
  end

  def encode_data(@tds_data_type_datetimeoffsetn, value, _attr) do
    #Logger.debug "encode_data_datetimeoffsetn #{inspect value}"
    data = encode_datetimeoffset(value)
    if data == nil do
      <<0x00>>
    else
      <<0x0A>> <> data
    end
  end

  def encode_plp(data) do
    size = byte_size(data)
    <<size::little-unsigned-64>> <> encode_plp_chunk(size, data, <<>>) <> <<0x00::32>>
  end

  def encode_plp_chunk(0, _, buf), do: buf
  def encode_plp_chunk(size, data, buf) do
    <<_t::unsigned-32, chunk_size::unsigned-32>> = <<size::unsigned-64>>
    <<chunk::binary-size(chunk_size), data::binary>> = data
    plp = <<chunk_size::little-unsigned-32>> <> chunk
    encode_plp_chunk(size-chunk_size, data, buf <> plp)
  end

  defp int_type_size(int) when int in 0..255, do: 1
  defp int_type_size(int) when int in -32768..32767, do: 2
  defp int_type_size(int) when int in -2147483648..2147483647, do: 4
  defp int_type_size(int) when int in -9223372036854775808..9223372036854775807, do: 8

  @doc """
  Data Encoding DateTime Types
  """
  @year_1900_days :calendar.date_to_gregorian_days({1900,1,1})
  @days_in_month 30
  @secs_in_min 60
  @secs_in_hour 60 * @secs_in_min
  @secs_in_day 24 * @secs_in_hour
  @max_time_scale 7
  @usecs_in_sec 1_000_000

  #Date
  def decode_date(<<days::little-24>>) do
    :calendar.gregorian_days_to_date(days + 366)
  end

  def encode_date(nil), do: nil
  def encode_date(date) do
    days = :calendar.date_to_gregorian_days(date) - 366
    <<days::little-24>>
  end

  #SmallDateTime
  def decode_smalldatetime(<<days::little-unsigned-16, mins::little-unsigned-16>>) do
    date = :calendar.gregorian_days_to_date(@year_1900_days + days)
    hour = mins / 60 |> trunc
    min = mins - (hour * 60) |> trunc
    {date, {hour, min, 0, 0}}
  end

  def encode_smalldatetime(nil), do: nil
  def encode_smalldatetime({date, {hour, min, _}}), do: encode_smalldatetime({date, {hour, min, 0, 0}})
  def encode_smalldatetime({date, {hour, min, _, _}}) do
    days = :calendar.date_to_gregorian_days(date) - @year_1900_days
    mins = hour * 60 + min
    encode_smalldatetime(days, mins)
  end
  def encode_smalldatetime(days, mins) do
    <<days::little-unsigned-16, mins::little-unsigned-16>>
  end

  #DateTime
  def decode_datetime(<<days::little-signed-32, secs300::little-unsigned-32>>) do
    #Logger.debug "#{inspect {days, secs300}}"
    date = :calendar.gregorian_days_to_date(@year_1900_days + days)
    secs = secs300 |> div(300)
    {_, {h, m, s}} = secs |> :calendar.seconds_to_daystime

    #Logger.debug "#{inspect {secs}}"
    sub_sec = (secs300/300) - secs #remaining fractional
    #Logger.debug "#{inspect {sub_sec}}"
    usec = (sub_sec * @usecs_in_sec + 0.5) |> trunc
    {date, {h, m, s, usec}}
  end

  def encode_datetime(nil), do: nil
  def encode_datetime({date, {h,m,s}}), do: encode_datetime({date, {h,m,s,0}})
  def encode_datetime({date, {h,m,s,us}}) do
    #Logger.debug "#{inspect {h,m,s,us}}"
    days = :calendar.date_to_gregorian_days(date) - @year_1900_days
    secs = (h * @secs_in_hour) + (m * @secs_in_min) + s
    #Logger.debug "secs #{inspect {secs}}"
    secs = secs + (us / @usecs_in_sec)
    #Logger.debug "secs #{inspect {secs}}"
    secs300 = trunc(secs * 300 + 0.5)
    #Logger.debug "#{inspect {days, secs300}}"
    <<days::little-signed-32, secs300::little-unsigned-32>>
  end

  #Time
  def decode_time(scale, <<fsec::binary>>) do
    cond do
      scale in [0, 1, 2] ->
        <<fsec::little-unsigned-24>> = fsec
      scale in [3, 4] ->
        <<fsec::little-unsigned-32>> = fsec
      scale in [5, 6, 7] ->
        <<fsec::little-unsigned-40>> = fsec
    end

    fs_per_sec = :math.pow(10, scale)

    hour = (fsec / fs_per_sec / @secs_in_hour) |> trunc
    fsec = fsec - (hour * @secs_in_hour * fs_per_sec)

    min = (fsec / fs_per_sec / @secs_in_min) |> trunc
    fsec = fsec - (min * @secs_in_min * fs_per_sec)

    sec = (fsec / fs_per_sec) |> trunc

    fsec = fsec - (sec * fs_per_sec) |> trunc

    {hour, min, sec, fsec}
  end

#time(n) is represented as one unsigned integer that represents the number of 10-n second increments since 12 AM within a day. The length, in bytes, of that integer depends on the scale n as follows:
# 3 bytes if 0 <= n < = 2.
# 4 bytes if 3 <= n < = 4.
# 5 bytes if 5 <= n < = 7.
  def encode_time(nil), do: nil
  def encode_time({h,m,s}), do: encode_time({h, m, s, 0})
  def encode_time(time), do: encode_time(time, @max_time_scale)
  def encode_time({h,m,s}, scale), do: encode_time({h, m, s, 0}, scale)
  def encode_time({hour, min, sec, fsec}, scale) do
    fs_per_sec = :math.pow(10, scale) |> trunc #10^scale fs in 1 sec
    fsec = (hour * 3600 * fs_per_sec) +
      (min * 60 * fs_per_sec) +
      (sec * fs_per_sec) + fsec

    cond do
      scale in [0, 1, 2] ->
        <<fsec::little-unsigned-24>>
      scale in [3, 4] ->
        <<fsec::little-unsigned-32>>
      scale in [5, 6, 7] ->
        <<fsec::little-unsigned-40>>
    end
  end

  #DateTime2
  def decode_datetime2(scale, <<data::binary>>) do
    {time, date} =
      cond do
        scale in [0, 1, 2] ->
          <<time::binary-3, date::binary-3>> = data
          {time, date}
        scale in [3, 4] ->
          <<time::binary-4, date::binary-3>> = data
          {time, date}
        scale in [5, 6, 7] ->
          <<time::binary-5, date::binary-3>> = data
          {time, date}
        true -> raise "DateTime Scale Unknown"
      end
    {decode_date(date), decode_time(scale, time)}
  end

  def encode_datetime2(nil), do: nil
  def encode_datetime2({date, time}, scale \\ @max_time_scale) do
    time = encode_time(time, scale)
    date = encode_date(date)
    time <> date
  end

  #DateTimeOffset
  def decode_datetimeoffset(scale, <<data::binary>>) do
    {datetime, offset_min} =
      cond do
        scale in [0, 1, 2] ->
          <<datetime::binary-6, offset_min::little-signed-16>> = data
          {datetime, offset_min}
        scale in [3, 4] ->
          <<datetime::binary-7, offset_min::little-signed-16>> = data
          {datetime, offset_min}
        scale in [5, 6, 7] ->
          <<datetime::binary-8, offset_min::little-signed-16>> = data
          {datetime, offset_min}
        true -> raise "DateTimeOffset Scale Unknown"
      end
    {date, time} = decode_datetime2(scale, datetime)
    {date, time, offset_min}
  end

  def encode_datetimeoffset(nil), do: nil
  def encode_datetimeoffset({date, time, offset_min}, scale \\ @max_time_scale) do
    datetime = encode_datetime2({date, time}, scale)
    datetime <> <<offset_min::little-signed-16>>
  end

  def encode_datetime_type(%Parameter{}) do
    #Logger.debug "encode_datetime_type"
    type = @tds_data_type_datetimen
    data = <<type, 0x08>>
    {type, data, length: 8}
  end

  def encode_smalldatetime_type(%Parameter{}) do
    #Logger.debug "encode_smalldatetime_type"
    type = @tds_data_type_datetimen
    data = <<type, 0x04>>
    {type, data, length: 4}
  end

  def encode_date_type(%Parameter{}) do
    type = @tds_data_type_daten
    data = <<type>>
    {type, data, []}
  end
  def encode_time_type(%Parameter{}) do
    #Logger.debug "encode_time_type"
    type = @tds_data_type_timen
    data = <<type, 0x07>>
    {type, data, scale: 7}
  end
  def encode_datetime2_type(%Parameter{}) do
    #Logger.debug "encode_datetime2_type"
    type = @tds_data_type_datetime2n
    data = <<type, 0x07>>
    {type, data, scale: 7}
  end

  def encode_datetimeoffset_type(%Parameter{}) do
    type = @tds_data_type_datetimeoffsetn
    data = <<type, 0x07>>
    {type, data, scale: 7}
  end



end
