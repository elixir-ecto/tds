defmodule Tds.Types do
  import Tds.BinaryUtils
  import Tds.Utils
  use Bitwise

  alias Tds.Parameter

  @year_1900_days :calendar.date_to_gregorian_days({1900, 1, 1})
  # @days_in_month 30
  @secs_in_min 60
  @secs_in_hour 60 * @secs_in_min
  # @secs_in_day 24 * @secs_in_hour

  @tds_data_type_null 0x1F
  @tds_data_type_tinyint 0x30
  @tds_data_type_bit 0x32
  @tds_data_type_smallint 0x34
  @tds_data_type_int 0x38
  @tds_data_type_smalldatetime 0x3A
  @tds_data_type_real 0x3B
  @tds_data_type_money 0x3C
  @tds_data_type_datetime 0x3D
  @tds_data_type_float 0x3E
  @tds_data_type_smallmoney 0x7A
  @tds_data_type_bigint 0x7F

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
  @tds_data_type_intn 0x26
  # legacy
  @tds_data_type_decimal 0x37
  # legacy
  @tds_data_type_numeric 0x3F
  @tds_data_type_bitn 0x68
  @tds_data_type_decimaln 0x6A
  @tds_data_type_numericn 0x6C
  @tds_data_type_floatn 0x6D
  @tds_data_type_moneyn 0x6E
  @tds_data_type_datetimen 0x6F
  @tds_data_type_daten 0x28
  @tds_data_type_timen 0x29
  @tds_data_type_datetime2n 0x2A
  @tds_data_type_datetimeoffsetn 0x2B
  @tds_data_type_char 0x2F
  @tds_data_type_varchar 0x27
  @tds_data_type_binary 0x2D
  @tds_data_type_varbinary 0x25
  @tds_data_type_bigvarbinary 0xA5
  @tds_data_type_bigvarchar 0xA7
  @tds_data_type_bigbinary 0xAD
  @tds_data_type_bigchar 0xAF
  @tds_data_type_nvarchar 0xE7
  @tds_data_type_nchar 0xEF
  @tds_data_type_xml 0xF1
  @tds_data_type_udt 0xF0
  @tds_data_type_text 0x23
  @tds_data_type_image 0x22
  @tds_data_type_ntext 0x63
  @tds_data_type_variant 0x62

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

  # @tds_plp_marker 0xffff
  @tds_plp_null 0xFFFFFFFFFFFFFFFF
  # @tds_plp_unknown 0xfffffffffffffffe

  #
  #  Data Type Decoders
  #

  def to_atom(token) do
    case token do
      @tds_data_type_null -> :null
      @tds_data_type_tinyint -> :tinyint
      @tds_data_type_bit -> :bit
      @tds_data_type_smallint -> :smallint
      @tds_data_type_int -> :int
      @tds_data_type_smalldatetime -> :smalldatetime
      @tds_data_type_real -> :real
      @tds_data_type_money -> :money
      @tds_data_type_datetime -> :datetime
      @tds_data_type_float -> :float
      @tds_data_type_smallmoney -> :smallmoney
      @tds_data_type_bigint -> :bigint
      @tds_data_type_uniqueidentifier -> :uniqueidentifier
      @tds_data_type_intn -> :intn
      @tds_data_type_decimal -> :decimal
      @tds_data_type_numeric -> :numeric
      @tds_data_type_bitn -> :bitn
      @tds_data_type_decimaln -> :decimaln
      @tds_data_type_numericn -> :numericn
      @tds_data_type_floatn -> :floatn
      @tds_data_type_moneyn -> :moneyn
      @tds_data_type_datetimen -> :datetimen
      @tds_data_type_daten -> :daten
      @tds_data_type_timen -> :timen
      @tds_data_type_datetime2n -> :datetime2n
      @tds_data_type_datetimeoffsetn -> :datetimeoffsetn
      @tds_data_type_char -> :char
      @tds_data_type_varchar -> :varchar
      @tds_data_type_binary -> :binary
      @tds_data_type_varbinary -> :varbinary
      @tds_data_type_bigvarbinary -> :bigvarbinary
      @tds_data_type_bigvarchar -> :bigvarchar
      @tds_data_type_bigbinary -> :bigbinary
      @tds_data_type_bigchar -> :bigchar
      @tds_data_type_nvarchar -> :nvarchar
      @tds_data_type_nchar -> :nchar
      @tds_data_type_xml -> :xml
      @tds_data_type_udt -> :udt
      @tds_data_type_text -> :text
      @tds_data_type_image -> :image
      @tds_data_type_ntext -> :ntext
      @tds_data_type_variant -> :variant
    end
  end

  def decode_info(<<data_type_code::unsigned-8, tail::binary>>)
      when data_type_code in @fixed_data_types do
    length =
      cond do
        data_type_code == @tds_data_type_null ->
          0

        data_type_code in [
          @tds_data_type_tinyint,
          @tds_data_type_bit
        ] ->
          1

        data_type_code == @tds_data_type_smallint ->
          2

        data_type_code in [
          @tds_data_type_int,
          @tds_data_type_smalldatetime,
          @tds_data_type_real,
          @tds_data_type_smallmoney
        ] ->
          4

        data_type_code in [
          @tds_data_type_datetime,
          @tds_data_type_float,
          @tds_data_type_money,
          @tds_data_type_bigint
        ] ->
          8
      end

    {%{
       data_type: :fixed,
       data_type_code: data_type_code,
       length: length,
       data_type_name: to_atom(data_type_code)
     }, tail}
  end

  def decode_info(<<data_type_code::unsigned-8, tail::binary>>)
      when data_type_code in @variable_data_types do
    def_type_info = %{
      data_type: :variable,
      data_type_code: data_type_code,
      sql_type: to_atom(data_type_code)
    }

    cond do
      data_type_code == @tds_data_type_daten ->
        length = 3

        type_info =
          def_type_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)

        {type_info, tail}

      data_type_code in [
        @tds_data_type_timen,
        @tds_data_type_datetime2n,
        @tds_data_type_datetimeoffsetn
      ] ->
        <<scale::unsigned-8, rest::binary>> = tail

        length =
          cond do
            scale in [0, 1, 2] -> 3
            scale in [3, 4] -> 4
            scale in [5, 6, 7] -> 5
            true -> nil
          end

        length =
          case data_type_code do
            @tds_data_type_datetime2n -> length + 3
            @tds_data_type_datetimeoffsetn -> length + 5
            _ -> length
          end

        type_info =
          def_type_info
          |> Map.put(:scale, scale)
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)

        {type_info, rest}

      data_type_code in [
        @tds_data_type_numericn,
        @tds_data_type_decimaln
      ] ->
        <<
          length::little-unsigned-8,
          precision::unsigned-8,
          scale::unsigned-8,
          rest::binary
        >> = tail

        type_info =
          def_type_info
          |> Map.put(:precision, precision)
          |> Map.put(:scale, scale)
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)

        {type_info, rest}

      data_type_code in [
        @tds_data_type_uniqueidentifier,
        @tds_data_type_intn,
        @tds_data_type_decimal,
        @tds_data_type_numeric,
        @tds_data_type_bitn,
        @tds_data_type_floatn,
        @tds_data_type_moneyn,
        @tds_data_type_datetimen,
        @tds_data_type_binary,
        @tds_data_type_varbinary
      ] ->
        <<length::little-unsigned-8, rest::binary>> = tail

        type_info =
          def_type_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)

        {type_info, rest}

      data_type_code in [
        @tds_data_type_char,
        @tds_data_type_varchar
      ] ->
        <<length::little-unsigned-8, collation::binary-5, rest::binary>> = tail
        {:ok, collation} = decode_collation(collation)

        type_info =
          def_type_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)
          |> Map.put(:collation, collation)

        {type_info, rest}

      data_type_code == @tds_data_type_xml ->
        <<schema::unsigned-8, rest::binary>> = tail

        if schema == 1 do
          # TODO should stick a raise in here??
          # BVarChar dbname
          # BVarChar owning schema
          # USVarChar xml schema collection
        end

        type_info =
          def_type_info
          |> Map.put(:data_reader, :plp)

        {type_info, rest}

      data_type_code in [
        @tds_data_type_bigvarchar,
        @tds_data_type_bigchar,
        @tds_data_type_nvarchar,
        @tds_data_type_nchar
      ] ->
        <<length::little-unsigned-16, collation::binary-5, rest::binary>> = tail
        {:ok, collation} = decode_collation(collation)

        type_info =
          def_type_info
          |> Map.put(:collation, collation)
          |> Map.put(
            :data_reader,
            if(length == 0xFFFF, do: :plp, else: :shortlen)
          )
          |> Map.put(:length, length)

        {type_info, rest}

      data_type_code in [
        @tds_data_type_bigvarbinary,
        @tds_data_type_bigbinary,
        @tds_data_type_udt
      ] ->
        <<length::little-unsigned-16, rest::binary>> = tail

        type_info =
          def_type_info
          |> Map.put(
            :data_reader,
            if(length == 0xFFFF, do: :plp, else: :shortlen)
          )
          |> Map.put(:length, length)

        {type_info, rest}

      data_type_code in [@tds_data_type_text, @tds_data_type_ntext] ->
        <<
          length::little-unsigned-32,
          collation::binary-5,
          numparts::signed-8,
          rest::binary
        >> = tail

        {:ok, collation} = decode_collation(collation)

        type_info =
          def_type_info
          |> Map.put(:collation, collation)
          |> Map.put(:data_reader, :longlen)
          |> Map.put(:length, length)

        rest =
          Enum.reduce(
            1..numparts,
            rest,
            fn _,
               <<tsize::little-unsigned-16,
                 _table_name::binary-size(tsize)-unit(16),
                 next_rest::binary>> ->
              next_rest
            end
          )

        {type_info, rest}

      data_type_code == @tds_data_type_image ->
        # TODO NumBarts Reader
        <<length::signed-32, numparts::signed-8, rest::binary>> = tail

        rest =
          Enum.reduce(1..numparts, rest, fn _,
                                            <<
                                              size::unsigned-16,
                                              _str::size(size)-unit(16),
                                              next_rest::binary
                                            >> ->
            next_rest
          end)

        type_info =
          def_type_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :bytelen)

        {type_info, rest}

      data_type_code == @tds_data_type_variant ->
        <<length::signed-32, rest::binary>> = tail

        type_info =
          def_type_info
          |> Map.put(:length, length)
          |> Map.put(:data_reader, :variant)

        {type_info, rest}
    end
  end

  @spec decode_collation(binpart :: <<_::40>>) ::
          {:ok, Tds.Protocol.Collation.t()}
          | {:error, :more}
          | {:error, any}
  defdelegate decode_collation(binpart),
    to: Tds.Protocol.Collation,
    as: :decode

  #
  #  Data Decoders
  #
  def decode_data(
        %{data_type: :fixed, data_type_code: data_type_code, length: length},
        <<tail::binary>>
      ) do
    <<value_binary::binary-size(length)-unit(8), tail::binary>> = tail

    value =
      case data_type_code do
        @tds_data_type_null ->
          nil

        @tds_data_type_bit ->
          value_binary != <<0x00>>

        @tds_data_type_smalldatetime ->
          decode_smalldatetime(value_binary)

        @tds_data_type_smallmoney ->
          decode_smallmoney(value_binary)

        @tds_data_type_real ->
          <<val::little-float-32>> = value_binary
          Float.round(val, 4)

        @tds_data_type_datetime ->
          decode_datetime(value_binary)

        @tds_data_type_float ->
          <<val::little-float-64>> = value_binary
          Float.round(val, 8)

        @tds_data_type_money ->
          decode_money(value_binary)

        _ ->
          <<val::little-signed-size(length)-unit(8)>> = value_binary
          val
      end

    {value, tail}
  end

  # ByteLength Types
  def decode_data(%{data_reader: :bytelen}, <<0x00, tail::binary>>),
    do: {nil, tail}

  def decode_data(
        %{
          data_type_code: data_type_code,
          data_reader: :bytelen,
          length: length
        } = data_info,
        <<size::unsigned-8, data::binary-size(size), tail::binary>>
      ) do
    value =
      cond do
        data_type_code == @tds_data_type_daten ->
          decode_date(data)

        data_type_code == @tds_data_type_timen ->
          decode_time(data_info[:scale], data)

        data_type_code == @tds_data_type_datetime2n ->
          decode_datetime2(data_info[:scale], data)

        data_type_code == @tds_data_type_datetimeoffsetn ->
          decode_datetimeoffset(data_info[:scale], data)

        data_type_code == @tds_data_type_uniqueidentifier ->
          decode_uuid(:binary.copy(data))

        data_type_code == @tds_data_type_intn ->
          case length do
            1 ->
              <<val::unsigned-8, _tail::binary>> = data
              val

            2 ->
              <<val::little-signed-16, _tail::binary>> = data
              val

            4 ->
              <<val::little-signed-32, _tail::binary>> = data
              val

            8 ->
              <<val::little-signed-64, _tail::binary>> = data
              val
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
          len = length * 8
          <<val::little-float-size(len), _::binary>> = data
          val

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
        ] ->
          decode_char(data_info, data)

        data_type_code in [
          @tds_data_type_binary,
          @tds_data_type_varbinary
        ] ->
          :binary.copy(data)
      end

    {value, tail}
  end

  # ShortLength Types
  def decode_data(%{data_reader: :shortlen}, <<0xFF, 0xFF, tail::binary>>),
    do: {nil, tail}

  def decode_data(
        %{data_type_code: data_type_code, data_reader: :shortlen} = data_info,
        <<size::little-unsigned-16, data::binary-size(size), tail::binary>>
      ) do
    value =
      cond do
        data_type_code in [
          @tds_data_type_bigvarchar,
          @tds_data_type_bigchar
        ] ->
          decode_char(data_info, data)

        data_type_code in [
          @tds_data_type_bigvarbinary,
          @tds_data_type_bigbinary
        ] ->
          :binary.copy(data)

        data_type_code in [
          @tds_data_type_nvarchar,
          @tds_data_type_nchar
        ] ->
          decode_nchar(data_info, data)

        data_type_code == @tds_data_type_udt ->
          decode_udt(data_info, :binary.copy(data))
      end

    {value, tail}
  end

  def decode_data(%{data_reader: :longlen}, <<0x00, tail::binary>>),
    do: {nil, tail}

  def decode_data(
        %{data_type_code: data_type_code, data_reader: :longlen} = data_info,
        <<
          text_ptr_size::unsigned-8,
          _text_ptr::size(text_ptr_size)-unit(8),
          _timestamp::unsigned-64,
          size::little-signed-32,
          data::binary-size(size)-unit(8),
          tail::binary
        >>
      ) do
    value =
      case data_type_code do
        @tds_data_type_text -> decode_char(data_info, data)
        @tds_data_type_ntext -> decode_nchar(data_info, data)
        @tds_data_type_image -> :binary.copy(data)
        _ -> nil
      end

    {value, tail}
  end

  # TODO Variant Types

  def decode_data(%{data_reader: :plp}, <<
        @tds_plp_null::little-unsigned-64,
        tail::binary
      >>),
      do: {nil, tail}

  def decode_data(
        %{data_type_code: data_type_code, data_reader: :plp} = data_info,
        <<_size::little-unsigned-64, tail::binary>>
      ) do
    {data, tail} = decode_plp_chunk(tail, <<>>)

    value =
      cond do
        data_type_code == @tds_data_type_xml ->
          decode_xml(data_info, data)

        data_type_code in [
          @tds_data_type_bigvarchar,
          @tds_data_type_bigchar,
          @tds_data_type_text
        ] ->
          decode_char(data_info, data)

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
          decode_nchar(data_info, data)

        data_type_code == @tds_data_type_udt ->
          decode_udt(data_info, data)
      end

    {value, tail}
  end

  def decode_plp_chunk(<<chunksize::little-unsigned-32, tail::binary>>, buf)
      when chunksize == 0,
      do: {buf, tail}

  def decode_plp_chunk(
        <<
          chunksize::little-unsigned-32,
          chunk::binary-size(chunksize)-unit(8),
          tail::binary
        >>,
        buf
      ) do
    decode_plp_chunk(tail, buf <> :binary.copy(chunk))
  end

  def decode_smallmoney(<<money::little-signed-32>>) do
    Float.round(money * 0.0001, 4)
  end

  def decode_money(<<
        money_m::little-unsigned-32,
        money_l::little-unsigned-32
      >>) do
    <<money::signed-64>> = <<money_m::32, money_l::32>>
    Float.round(money * 0.0001, 4)
  end

  # UUID
  def decode_uuid(<<_::128>> = bin), do: bin

  def encode_uuid(
        <<_::64, ?-, _::32, ?-, _::32, ?-, _::32, ?-, _::96>> = string
      ) do
    raise ArgumentError,
          "trying to load string UUID as Tds.Types.UUID: #{inspect(string)}. " <>
            "Maybe you wanted to declare :uuid as your database field?"
  end

  def encode_uuid(<<_::128>> = bin), do: bin

  def encode_uuid(any),
    do: raise(ArgumentError, "Invalid uuid value #{inspect(any)}")

  # Decimal
  def decode_decimal(precision, scale, <<sign::int8, value::binary>>) do
    size = byte_size(value)
    <<value::little-size(size)-unit(8)>> = value

    Decimal.get_context()
    |> Map.put(:precision, precision)
    |> Decimal.set_context()

    case sign do
      0 -> Decimal.new(-1, value, -scale)
      _ -> Decimal.new(1, value, -scale)
    end
  end

  def decode_char(data_info, <<data::binary>>) do
    Tds.Utils.decode_chars(data, data_info.collation.codepage)
  end

  def decode_nchar(_data_info, <<data::binary>>) do
    ucs2_to_utf(data)
  end

  def decode_xml(_data_info, <<data::binary>>) do
    ucs2_to_utf(data)
  end

  def decode_udt(%{}, <<data::binary>>) do
    # UDT, if used, should be decoded by app that uses it,
    # tho we could've registered UDT types on connection
    # Example could be ecto, where custom type is created
    # special case are built in udt types such as HierarchyId
    data
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
      :smalldatetime -> encode_smalldatetime_type(param)
      :datetime -> encode_datetime_type(param)
      :datetime2 -> encode_datetime2_type(param)
      :datetimeoffset -> encode_datetimeoffset_type(param)
      :date -> encode_date_type(param)
      :time -> encode_time_type(param)
      :uuid -> encode_uuid_type(param)
      _ -> encode_string_type(param)
    end
  end

  def encode_data_type(param),
    do: param |> Parameter.fix_data_type() |> encode_data_type()

  def encode_binary_type(%Parameter{value: value} = param)
      when value == "" do
    encode_string_type(param)
  end

  def encode_binary_type(%Parameter{value: value} = param)
      when is_integer(value) do
    %{param | value: <<value>>} |> encode_binary_type
  end

  def encode_binary_type(%Parameter{value: value}) do
    length = length_for_binary(value)
    type = @tds_data_type_bigvarbinary
    data = <<type>> <> length
    {type, data, []}
  end

  defp length_for_binary(nil), do: <<0xFF, 0xFF>>

  defp length_for_binary(value) do
    case byte_size(value) do
      # varbinary(max)
      value_size when value_size > 8000 -> <<0xFF, 0xFF>>
      value_size -> <<value_size::little-unsigned-16>>
    end
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

        if value_size == 0 or value_size > 8000 do
          <<0xFF, 0xFF>>
        else
          <<value_size::little-(2 * 8)>>
        end
      else
        <<0xFF, 0xFF>>
      end

    type = @tds_data_type_nvarchar
    data = <<type>> <> length <> collation
    {type, data, [collation: collation]}
  end

  # def encode_integer_type(%Parameter{value: value} = param)
  #     when value < 0 do
  #   encode_decimal_type(Decima.new(param))
  # end

  def encode_integer_type(%Parameter{value: value}) do
    attributes = []
    type = @tds_data_type_intn

    {attributes, length} =
      if value == nil do
        attributes =
          attributes
          |> Keyword.put(:length, 4)

        value_size = int_type_size(value)
        {attributes, <<value_size>>}
      else
        value_size = int_type_size(value)
        # cond do
        #   value_size == 1 ->
        #     data_type_code = @tds_data_type_tinyint
        # Enum.find(data_types, fn(x) -> x[:name] == :tinyint end)
        #   value_size == 2 ->
        #     data_type_code = @tds_data_type_smallint
        # Enum.find(data_types, fn(x) -> x[:name] == :smallint end)
        #   value_size > 2 and value_size <= 4 ->
        #     data_type_code = @tds_data_type_int
        # Enum.find(data_types, fn(x) -> x[:name] == :int end)
        #   value_size > 4 and value_size <= 8 ->
        #     data_type_code = @tds_data_type_bigint
        # Enum.find(data_types, fn(x) -> x[:name] == :bigint end)
        # end
        attributes =
          attributes
          |> Keyword.put(:length, value_size)

        {attributes, <<value_size>>}
      end

    data = <<type>> <> length
    {type, data, attributes}
  end

  def encode_decimal_type(%Parameter{value: nil} = param) do
    encode_binary_type(param)
  end

  def encode_decimal_type(%Parameter{value: value}) do
    d_ctx = Decimal.get_context()
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context(d_ctx)

    value_list =
      value
      |> Decimal.abs()
      |> Decimal.to_string(:normal)
      |> String.split(".")

    {precision, scale} =
      case value_list do
        [p, s] ->
          {String.length(p) + String.length(s), String.length(s)}

        [p] ->
          {String.length(p), 0}
      end

    dec_abs =
      value
      |> Decimal.abs()

    value =
      dec_abs.coef
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

  def encode_float_type(%Parameter{value: value} = param)
      when is_float(value) do
    encode_float_type(%{param | value: to_decimal(value)})
  end

  def encode_float_type(%Parameter{value: %Decimal{} = value}) do
    d_ctx = Decimal.get_context()
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context(d_ctx)

    value_list =
      value
      |> Decimal.abs()
      |> Decimal.to_string(:normal)
      |> String.split(".")

    {precision, scale} =
      case value_list do
        [p, s] ->
          {String.length(p) + String.length(s), String.length(s)}

        [p] ->
          {String.length(p), 0}
      end

    dec_abs =
      value
      |> Decimal.abs()

    value =
      dec_abs.coef
      |> :binary.encode_unsigned(:little)

    value_size = byte_size(value)

    # keep max precision
    len = 8
    # cond do
    #   precision <= 9 -> 4
    #   precision <= 19 -> 8
    # end

    padding = len - value_size
    value_size = value_size + padding

    type = @tds_data_type_floatn
    data = <<type, value_size>>
    {type, data, precision: precision, scale: scale}
  end

  @doc """
  Creates the Parameter Descriptor for the selected type
  """
  def encode_param_descriptor(
        %Parameter{name: name, value: value, type: type} = param
      )
      when type != nil do
    desc =
      case type do
        :uuid ->
          "uniqueidentifier"

        :datetime ->
          "datetime"

        :datetime2 ->
          case value do
            %NaiveDateTime{microsecond: {_, scale}} ->
              "datetime2(#{scale})"

            _ ->
              "datetime2"
          end

        :datetimeoffset ->
          case value do
            %DateTime{microsecond: {_, s}} ->
              "datetimeoffset(#{s})"

            _ ->
              "datetimeoffset"
          end

        :date ->
          "date"

        :time ->
          case value do
            %Time{microsecond: {_, scale}} ->
              "time(#{scale})"

            _ ->
              "time"
          end

        :smalldatetime ->
          "smalldatetime"

        :binary ->
          encode_binary_descriptor(value)

        :string ->
          cond do
            is_nil(value) -> "nvarchar(1)"
            String.length(value) <= 0 -> "nvarchar(1)"
            String.length(value) <= 2_000 -> "nvarchar(2000)"
            true -> "nvarchar(max)"
          end

        :varchar ->
          cond do
            is_nil(value) -> "varchar(1)"
            String.length(value) <= 0 -> "varchar(1)"
            String.length(value) <= 2_000 -> "varchar(2000)"
            true -> "varchar(max)"
          end

        :integer ->
          case value do
            0 ->
              "int"

            val when val >= 1 ->
              "bigint"

            _ ->
              precision =
                value
                |> Integer.to_string()
                |> String.length()

              "decimal(#{precision - 1}, 0)"
          end

        :bigint ->
          "bigint"

        :decimal ->
          encode_decimal_descriptor(param)

        :float ->
          encode_float_descriptor(param)

        :boolean ->
          "bit"

        _ ->
          # this should fix issues when column is varchar but parameter
          # is threated as nvarchar(..) since nothing defines parameter
          # as varchar.
          latin1 = :unicode.characters_to_list(value || "", :latin1)
          utf8 = :unicode.characters_to_list(value || "", :utf8)

          db_type =
            if latin1 == utf8,
              do: "varchar",
              else: "nvarchar"

          # this is same .net driver uses in order to avoid too many
          # cached execution plans, it must be always same length otherwise it will
          # use too much memory in sql server to cache each plan per param size
          cond do
            is_nil(value) -> "#{db_type}(1)"
            String.length(value) <= 0 -> "#{db_type}(1)"
            String.length(value) <= 2_000 -> "#{db_type}(2000)"
            true -> "#{db_type}(max)"
          end
      end

    "#{name} #{desc}"
  end

  @doc """
  Implictly Selected Types
  """
  # nil
  def encode_param_descriptor(param),
    do: param |> Parameter.fix_data_type() |> encode_param_descriptor()

  @doc """
  Decimal Type Parameter Descriptor
  """
  def encode_decimal_descriptor(%Parameter{value: nil}),
    do: encode_binary_descriptor(nil)

  def encode_decimal_descriptor(%Parameter{value: value} = param)
      when is_float(value) do
    encode_decimal_descriptor(%{param | value: Decimal.from_float(value)})
  end

  def encode_decimal_descriptor(%Parameter{value: value} = param)
      when is_binary(value) or is_integer(value) do
    encode_decimal_descriptor(%{param | value: Decimal.new(value)})
  end

  def encode_decimal_descriptor(%Parameter{value: %Decimal{} = dec}) do
    d_ctx = Decimal.get_context()
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context(d_ctx)

    value_list =
      dec
      |> Decimal.abs()
      |> Decimal.to_string(:normal)
      |> String.split(".")

    {precision, scale} =
      case value_list do
        [p, s] ->
          {String.length(p) + String.length(s), String.length(s)}

        [p] ->
          {String.length(p), 0}
      end

    "decimal(#{precision}, #{scale})"
  end

  # Decimal.new/0 is undefined -- modifying params to hopefully fix
  def encode_decimal_descriptor(
        %Parameter{type: :decimal, value: value} = param
      ) do
    encode_decimal_descriptor(%{param | value: Decimal.new(value)})
  end

  @doc """
  Float Type Parameter Descriptor
  """
  def encode_float_descriptor(%Parameter{value: nil}), do: "decimal(1,0)"

  def encode_float_descriptor(%Parameter{value: value} = param)
      when is_float(value) do
    param
    |> Map.put(:value, to_decimal(value))
    |> encode_float_descriptor
  end

  def encode_float_descriptor(%Parameter{value: %Decimal{}}), do: "float(53)"

  @doc """
  Binary Type Parameter Descriptor
  """
  def encode_binary_descriptor(value) when is_integer(value),
    do: encode_binary_descriptor(<<value>>)

  def encode_binary_descriptor(value) when is_nil(value), do: "varbinary(1)"

  def encode_binary_descriptor(value) when byte_size(value) <= 0,
    do: "varbinary(1)"

  def encode_binary_descriptor(value) when byte_size(value) > 0,
    do: "varbinary(max)"

  # def encode_binary_descriptor(value) when byte_size(value) > 8_000,
  #   do: "varbinary(max)"

  # def encode_binary_descriptor(value), do: "varbinary(#{byte_size(value)})"

  @doc """
  Data Encoding Binary Types
  """
  def encode_data(@tds_data_type_bigvarbinary, value, attr)
      when is_integer(value),
      do: encode_data(@tds_data_type_bigvarbinary, <<value>>, attr)

  def encode_data(@tds_data_type_bigvarbinary, nil, _),
    do: <<@tds_plp_null::little-unsigned-64>>

  def encode_data(@tds_data_type_bigvarbinary, value, _) do
    case byte_size(value) do
      # varbinary(max) gets encoded in chunks
      value_size when value_size > 8000 -> encode_plp(value)
      value_size -> <<value_size::little-unsigned-16>> <> value
    end
  end

  @doc """
  Data Encoding String Types
  """
  def encode_data(@tds_data_type_nvarchar, nil, _),
    do: <<@tds_plp_null::little-unsigned-64>>

  def encode_data(@tds_data_type_nvarchar, value, _) do
    value = to_little_ucs2(value)
    value_size = byte_size(value)

    cond do
      value_size <= 0 ->
        <<0x00::unsigned-64, 0x00::unsigned-32>>

      value_size > 8000 ->
        encode_plp(value)

      true ->
        <<value_size::little-size(2)-unit(8)>> <> value
    end
  end

  @doc """
  Data Encoding Positive Integers Types
  """
  def encode_data(_, value, _) when is_integer(value) do
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
    # d_ctx = Decimal.get_context()
    # d_ctx = %{d_ctx | precision: 38}
    # Decimal.set_context(d_ctx)

    # value_list =
    #   value
    #   |> Decimal.new()
    #   |> Decimal.abs()
    #   |> Decimal.to_string(:scientific)
    #   |> String.split(".")

    # precision =
    #   case value_list do
    #     [p, s] ->
    #       String.length(p) + String.length(s)

    #     [p] ->
    #       String.length(p)
    #   end

    # if precision <= 7 + 1 do
    #   <<0x04, value::little-float-32>>
    # else
    # up to 15 digits of precision
    # https://docs.microsoft.com/en-us/sql/t-sql/data-types/float-and-real-transact-sql
    <<0x08, value::little-float-64>>
    # end
  end

  @doc """
  Data Encoding Decimal Types
  """
  def encode_data(@tds_data_type_decimaln, %Decimal{} = value, attr) do
    d_ctx = Decimal.get_context()
    d_ctx = %{d_ctx | precision: 38}
    Decimal.set_context(d_ctx)
    precision = attr[:precision]

    d =
      value
      |> Decimal.to_string()
      |> Decimal.new()

    sign =
      case d.sign do
        1 -> 1
        -1 -> 0
      end

    d_abs = Decimal.abs(d)

    value = d_abs.coef

    value_binary =
      value
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

  def encode_data(@tds_data_type_decimaln, nil, _),
    # <<0, 0, 0, 0>
    do: <<0x00::little-unsigned-32>>

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
      <<0x03, data::binary>>
    end
  end

  def encode_data(@tds_data_type_timen, value, _attr) do
    # Logger.debug "encode_data_timen"
    {data, scale} = encode_time(value)
    # Logger.debug "#{inspect data}"
    if data == nil do
      <<0x00>>
    else
      len =
        cond do
          scale < 3 -> 0x03
          scale < 5 -> 0x04
          scale < 8 -> 0x05
        end

      <<len, data::binary>>
    end
  end

  def encode_data(@tds_data_type_datetimen, value, attr) do
    # Logger.debug "dtn #{inspect attr}"
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
    # Logger.debug "EncodeData #{inspect value}"
    {data, scale} = encode_datetime2(value)

    if data == nil do
      <<0x00>>
    else
      # 0x08 length of binary for scale 7
      storage_size =
        cond do
          scale < 3 -> 0x06
          scale < 5 -> 0x07
          scale < 8 -> 0x08
        end

      <<storage_size>> <> data
    end
  end

  def encode_data(@tds_data_type_datetimeoffsetn, value, _attr) do
    # Logger.debug "encode_data_datetimeoffsetn #{inspect value}"
    data = encode_datetimeoffset(value)

    if data == nil do
      <<0x00>>
    else
      case value do
        %DateTime{microsecond: {_, s}} when s < 3 ->
          <<0x08, data::binary>>

        %DateTime{microsecond: {_, s}} when s < 5 ->
          <<0x09, data::binary>>

        _ ->
          <<0x0A, data::binary>>
      end
    end
  end

  def encode_plp(data) do
    size = byte_size(data)

    <<size::little-unsigned-64>> <>
      encode_plp_chunk(size, data, <<>>) <> <<0x00::little-unsigned-32>>
  end

  def encode_plp_chunk(0, _, buf), do: buf

  def encode_plp_chunk(size, data, buf) do
    <<_t::unsigned-32, chunk_size::unsigned-32>> = <<size::unsigned-64>>
    <<chunk::binary-size(chunk_size), data::binary>> = data
    plp = <<chunk_size::little-unsigned-32>> <> chunk
    encode_plp_chunk(size - chunk_size, data, buf <> plp)
  end

  defp int_type_size(int) when int == nil, do: 4
  defp int_type_size(int) when int in -254..255, do: 4
  defp int_type_size(int) when int in -32_768..32_767, do: 4
  defp int_type_size(int) when int in -2_147_483_648..2_147_483_647, do: 4

  defp int_type_size(int)
       when int in -9_223_372_036_854_775_808..9_223_372_036_854_775_807,
       do: 8

  defp int_type_size(int),
    do:
      raise(
        ArgumentError,
        "Erlang integer value #{int} is too big (more than 64bits) to fit tds integer/bigint. Please consider using Decimal.new/1 to maintain precision."
      )

  @doc """
  Data Encoding DateTime Types
  """
  @year_1900_days :calendar.date_to_gregorian_days({1900, 1, 1})
  # @days_in_month 30
  @secs_in_min 60
  @secs_in_hour 60 * @secs_in_min
  # @secs_in_day 24 * @secs_in_hour
  @max_time_scale 7
  @usecs_in_sec 1_000_000

  # Date
  def decode_date(<<days::little-24>>) do
    date = :calendar.gregorian_days_to_date(days + 366)

    if use_elixir_calendar_types?() do
      Date.from_erl!(date, Calendar.ISO)
    else
      date
    end
  end

  def encode_date(nil), do: nil

  def encode_date(%Date{} = date), do: date |> Date.to_erl() |> encode_date()

  def encode_date(date) do
    days = :calendar.date_to_gregorian_days(date) - 366
    <<days::little-24>>
  end

  # SmallDateTime
  def decode_smalldatetime(<<
        days::little-unsigned-16,
        mins::little-unsigned-16
      >>) do
    date = :calendar.gregorian_days_to_date(@year_1900_days + days)
    hour = trunc(mins / 60)
    min = trunc(mins - hour * 60)

    if use_elixir_calendar_types?() do
      NaiveDateTime.from_erl!({date, {hour, min, 0}})
    else
      {date, {hour, min, 0, 0}}
    end
  end

  def encode_smalldatetime(nil), do: nil

  def encode_smalldatetime({date, {hour, min, _}}),
    do: encode_smalldatetime({date, {hour, min, 0, 0}})

  def encode_smalldatetime({date, {hour, min, _, _}}) do
    days = :calendar.date_to_gregorian_days(date) - @year_1900_days
    mins = hour * 60 + min
    encode_smalldatetime(days, mins)
  end

  def encode_smalldatetime(days, mins) do
    <<days::little-unsigned-16, mins::little-unsigned-16>>
  end

  # DateTime
  def decode_datetime(<<
        days::little-signed-32,
        secs300::little-unsigned-32
      >>) do
    # Logger.debug "#{inspect {days, secs300}}"
    date = :calendar.gregorian_days_to_date(@year_1900_days + days)

    milliseconds = round(secs300 * 10 / 3)
    usec = rem(milliseconds, 1_000)

    seconds = div(milliseconds, 1_000)

    {_, {h, m, s}} = :calendar.seconds_to_daystime(seconds)

    if use_elixir_calendar_types?() do
      # precision =
      #   case Integer.digits(usec) do
      #     [0] -> 0
      #     [_, 0] -> 2
      #     [_, 0, 0] -> 1
      #     [_, _, 0] -> 2
      #     _ -> 3
      #   end

      NaiveDateTime.from_erl!(
        {date, {h, m, s}},
        {usec * 1_000, 3},
        Calendar.ISO
      )
    else
      {date, {h, m, s, usec}}
    end
  end

  def encode_datetime(nil), do: nil

  def encode_datetime(%DateTime{} = dt),
    do: encode_datetime(DateTime.to_naive(dt))

  def encode_datetime(%NaiveDateTime{} = dt) do
    {date, {h, m, s}} = NaiveDateTime.to_erl(dt)
    {msec, _} = dt.microsecond
    encode_datetime({date, {h, m, s, msec}})
  end

  def encode_datetime({date, {h, m, s}}),
    do: encode_datetime({date, {h, m, s, 0}})

  def encode_datetime({date, {h, m, s, us}}) do
    days = :calendar.date_to_gregorian_days(date) - @year_1900_days
    milliseconds = ((h * 60 + m) * 60 + s) * 1_000 + us / 1_000

    secs_300 = round(milliseconds / (10 / 3))

    {days, secs_300} =
      if secs_300 == 25_920_000 do
        {days + 1, 0}
      else
        {days, secs_300}
      end

    <<days::little-signed-32, secs_300::little-unsigned-32>>
  end

  # Time
  def decode_time(scale, <<fsec::binary>>) do
    # this is kind of rendudant, since "size" can be, and is, read from token
    parsed_fsec =
      cond do
        scale in [0, 1, 2] ->
          <<parsed_fsec::little-unsigned-24>> = fsec
          parsed_fsec

        scale in [3, 4] ->
          <<parsed_fsec::little-unsigned-32>> = fsec
          parsed_fsec

        scale in [5, 6, 7] ->
          <<parsed_fsec::little-unsigned-40>> = fsec
          parsed_fsec
      end

    fs_per_sec = trunc(:math.pow(10, scale))

    hour = trunc(parsed_fsec / fs_per_sec / @secs_in_hour)
    parsed_fsec = parsed_fsec - hour * @secs_in_hour * fs_per_sec

    min = trunc(parsed_fsec / fs_per_sec / @secs_in_min)
    parsed_fsec = parsed_fsec - min * @secs_in_min * fs_per_sec

    sec = trunc(parsed_fsec / fs_per_sec)

    parsed_fsec = trunc(parsed_fsec - sec * fs_per_sec)

    if use_elixir_calendar_types?() do
      {parsed_fsec, scale} =
        if scale > 6 do
          {trunc(parsed_fsec / 10), 6}
        else
          {trunc(parsed_fsec * :math.pow(10, 6 - scale)), scale}
        end

      Time.from_erl!({hour, min, sec}, {parsed_fsec, scale})
    else
      {hour, min, sec, parsed_fsec}
    end
  end

  # time(n) is represented as one unsigned integer that represents the number of
  # 10-n second increments since 12 AM within a day. The length, in bytes, of
  # that integer depends on the scale n as follows:
  # 3 bytes if 0 <= n < = 2.
  # 4 bytes if 3 <= n < = 4.
  # 5 bytes if 5 <= n < = 7.
  def encode_time(nil), do: {nil, 0}

  def encode_time({h, m, s}), do: encode_time({h, m, s, 0})

  def encode_time(%Time{} = t) do
    {h, m, s} = Time.to_erl(t)
    {ms, scale} = t.microsecond
    # fix ms
    ms =
      if scale != 6 do
        trunc(ms / :math.pow(10, 6 - scale))
      else
        ms
      end

    encode_time({h, m, s, ms}, scale)
  end

  def encode_time(time), do: encode_time(time, @max_time_scale)

  def encode_time({h, m, s}, scale), do: encode_time({h, m, s, 0}, scale)

  def encode_time({hour, min, sec, fsec}, scale) do
    # 10^scale fs in 1 sec
    fs_per_sec = trunc(:math.pow(10, scale))

    fsec =
      hour * 3600 * fs_per_sec + min * 60 * fs_per_sec + sec * fs_per_sec + fsec

    bin =
      cond do
        scale < 3 ->
          <<fsec::little-unsigned-24>>

        scale < 5 ->
          <<fsec::little-unsigned-32>>

        :else ->
          <<fsec::little-unsigned-40>>
      end

    {bin, scale}
  end

  # DateTime2
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

        true ->
          raise "DateTime Scale Unknown"
      end

    date = decode_date(date)
    time = decode_time(scale, time)

    with true <- use_elixir_calendar_types?(),
         {:ok, datetime2} <- NaiveDateTime.new(date, time) do
      datetime2
    else
      false -> {date, time}
      {:error, error} -> raise DBConnection.EncodeError, error
    end
  end

  def encode_datetime2(value, scale \\ @max_time_scale)
  def encode_datetime2(nil, _), do: {nil, 0}

  def encode_datetime2({date, time}, scale) do
    {time, scale} = encode_time(time, scale)
    date = encode_date(date)
    {time <> date, scale}
  end

  def encode_datetime2(%NaiveDateTime{} = value, _scale) do
    t = NaiveDateTime.to_time(value)
    {time, scale} = encode_time(t)
    date = encode_date(NaiveDateTime.to_date(value))
    {time <> date, scale}
  end

  def encode_datetime2(value, scale) do
    raise ArgumentError,
          "value #{inspect(value)} with scale #{inspect(scale)} is not supported DateTime2 value"
  end

  # DateTimeOffset
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

        true ->
          raise DBConnection.EncodeError, "DateTimeOffset Scale invalid"
      end

    case decode_datetime2(scale, datetime) do
      {date, time} ->
        {date, time, offset_min}

      %NaiveDateTime{} = dt ->
        str = NaiveDateTime.to_iso8601(dt)
        h = trunc(offset_min / 60)

        m =
          Integer.to_string(offset_min - h * 60)
          |> String.pad_leading(2, "0")

        h =
          Integer.to_string(h)
          |> String.pad_leading(2, "0")

        {:ok, datetime, ^offset_min} = DateTime.from_iso8601("#{str}+#{h}:#{m}")
        datetime
    end
  end

  def encode_datetimeoffset(datetimetz, scale \\ @max_time_scale)
  def encode_datetimeoffset(nil, _), do: nil

  def encode_datetimeoffset({date, time, offset_min}, scale) do
    {datetime, _ignore_allways_10bytes} = encode_datetime2({date, time}, scale)
    datetime <> <<offset_min::little-signed-16>>
  end

  def encode_datetimeoffset(
        %DateTime{utc_offset: offset} = dt,
        scale
      ) do
    {datetime, s} =
      dt
      |> DateTime.to_naive()
      |> encode_datetime2(scale)

    cond do
      s < 3 ->
        datetime <> <<offset::little-signed-16>>

      s < 5 ->
        datetime <> <<offset::little-signed-16>>

      :else ->
        <<datetime::binary-8, offset::little-signed-16>>
    end

  end

  def encode_datetime_type(%Parameter{}) do
    # Logger.debug "encode_datetime_type"
    type = @tds_data_type_datetimen
    data = <<type, 0x08>>
    {type, data, length: 8}
  end

  def encode_smalldatetime_type(%Parameter{}) do
    # Logger.debug "encode_smalldatetime_type"
    type = @tds_data_type_datetimen
    data = <<type, 0x04>>
    {type, data, length: 4}
  end

  def encode_date_type(%Parameter{}) do
    type = @tds_data_type_daten
    data = <<type>>
    {type, data, []}
  end

  def encode_time_type(%Parameter{value: value}) do
    # Logger.debug "encode_time_type"
    type = @tds_data_type_timen

    case value do
      nil ->
        {type, <<type, 0x07>>, scale: 1}

      {_, _, _} ->
        {type, <<type, 0x07>>, scale: 1}

      {_, _, _, fsec} ->
        scale = Integer.digits(fsec) |> length()
        {type, <<type, 0x07>>, scale: scale}

      %Time{microsecond: {_, scale}} ->
        {type, <<type, scale>>, scale: scale}

      other ->
        raise ArgumentError, "Value #{inspect(other)} is not valid time"
    end
  end

  def encode_datetime2_type(%Parameter{
        value: %NaiveDateTime{microsecond: {_, s}}
      }) do
    type = @tds_data_type_datetime2n
    data = <<type, s>>
    {type, data, scale: s}
  end

  def encode_datetime2_type(%Parameter{}) do
    # Logger.debug "encode_datetime2_type"
    type = @tds_data_type_datetime2n
    data = <<type, 0x07>>
    {type, data, scale: 7}
  end

  def encode_datetimeoffset_type(%Parameter{
        value: %DateTime{microsecond: {_, s}}
      }) do
    type = @tds_data_type_datetimeoffsetn
    data = <<type, s>>
    {type, data, scale: s}
  end

  def encode_datetimeoffset_type(%Parameter{}) do
    type = @tds_data_type_datetimeoffsetn
    data = <<type, 0x07>>
    {type, data, scale: 7}
  end
end
