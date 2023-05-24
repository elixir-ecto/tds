defmodule Tds.Token.ColumnData do
  import Bitwise
  import Tds.Protocol.Grammar

  @typedoc """
  Map representing decoded bitmap flags from COLMETADATA token stream.

  ## Fields
  - `nullable` - column is nullable
  - `case_sensitive` - Set to `true` for string columns with binary collation
    and always for the XML data type. Set to `false` otherwise.
  - `updatable` - tells if column is `:updatable`, `:read_only`, or `:unknown`
  - `identity` - if true, the column is identity column.
  - `computed` - if true, the column is computed column.
  - `sparse_column_set` - if `true`, the column is the special XML column
    for the sparse column set. For information about using column sets,
    see [MSDN-ColSets](https://learn.microsoft.com/en-us/sql/relational-databases/tables/use-column-sets?view=sql-server-ver16).
  - `encrypted` - if `true`, the column is encrypted transparently
    and has to be decrypted to view the plaintext value. This flag is
    valid when the column encryption feature is negotiated between client
    and server and is turned on.
  - `fixed_len_clr_type` - if `true` the column is a fixed-length
    common language runtime user-defined type (CLR UDT)
  - `hidden` - if `true`, column is part of hidden primary key created to support
    a T-SQL SELECT statement contiang FOR BROWSE.
  - `key` - if `true`, column is part of the primary key
  - `nullable_unknown` - if true, it is unknown whether the column is nullable.
    This can occur if the column is a computed column or a sparse column set column.
  """
  @type flags :: %{
          nullable: boolean(),
          case_sensitive: boolean(),
          updatable: :read_only | :read_write | :unused,
          identity: boolean(),
          computed: boolean(),
          sparse_column_set: boolean(),
          encrypted: boolean(),
          fixed_len_clr_type: boolean(),
          hidden: boolean(),
          key: boolean(),
          nullable_unknown: boolean()
        }

  @typedoc """
  Represent **ColumnData** in COLMETADATA token stream.

  ## Fields
  - `user_type` - user type of the column
  - `flags` - bitmap flags of the column
  - `type_info` - `Tds.Protocol.TypeInfo.t()` of the column
  - `table_name` - Full qualified table name of the column.
  - `column_name` - column name of the column
  - `base_type_info` - base type info of the column

  """
  @type t :: %__MODULE__{
          user_type: integer(),
          flags: non_neg_integer(),
          type_info: Tds.Protocol.TypeInfo.t(),
          table_name: [String.t()],
          column_name: String.t(),
          base_type_info: integer()
        }

  defstruct user_type: 0,
            flags: 0,
            type_info: %{},
            table_name: [],
            column_name: "",
            base_type_info: 0

  def decode(<<count::little-ushort(), rest::binary>>) do
    decode(count, rest, [])
  end

  @spec decode(non_neg_integer(), binary(), list(ColumnData.t())) :: {list(ColumnData.t()), binary()}
  def decode(0, token_stream, columndata_list),
    do: {Enum.reverse(columndata_list), token_stream}

  def decode(count, token_stream, columndata_list) do
    <<
      user_type::little-ulong(),
      flags::byte(2),
      token_stream::binary
    >> = token_stream

    {type_info, token_stream} = Tds.Protocol.TypeInfo.decode(token_stream, __MODULE__)
    {table_name, token_stream} = decode_full_table_name(token_stream)
    # {column_name, token_stream} = decode_column_name(1, token_stream, [])
    columndata = %__MODULE__{
      user_type: user_type,
      flags: flags,
      type_info: type_info,
      table_name: table_name,
      # column_name: column_name,
      # base_type_info: base_type_info
    }

    decode(count - 1, token_stream, [columndata | columndata_list])
  end

  @doc """
  fNullable. If set, the column is nullable.
  """
  @spec nullable?(Tds.Token.ColumnData.t()) :: boolean
  def nullable?(%__MODULE__{flags: flags}),
    do: flag_match?(flags, 0x01)

  @doc """
  fCaseSen - Set to `true` for string columns with binary collation and always
  for the XML data type. Set to `false` otherwise.
  """
  @spec case_sensitive?(Tds.Token.ColumnData.t()) :: boolean
  def case_sensitive?(%__MODULE__{flags: flags}),
    do: flag_match?(flags, 0x02)

  @doc """
  fUpdatable. Tells if column is `:updatable`, `:read_only`, or `:unknown`.
  """
  @spec updatable?(Tds.Token.ColumnData.t()) :: :updatable | :read_only | :unknown
  def updatable?(%__MODULE__{flags: flags}) do
    cond do
      flag_match?(flags, 0x04) -> :read_only
      flag_match?(flags, 0x08) -> :read_write
      true -> :unknown
    end
  end

  @doc """
  fIdentity. If true, the column is identity column.
  """
  @spec identity?(Tds.Token.ColumnData.t()) :: boolean
  def identity?(%__MODULE__{flags: flags}),
    do: flag_match?(flags, 0x10)



  defp flag_match?(all_flags, flag),
    do: (all_flags &&& flag) == flag

  # defp decode_flags(flags) do
  #   %{
  #     nullable: if(band(flags, 0x01) == 0x01, do: true, else: false),
  #     case_sensitive: if(band(flags, 0x02) == 0x02, do: true, else: false),
  #     updatable:
  #       cond do
  #         band(flags, 0x04) == 0x04 -> :read_only
  #         band(flags, 0x08) == 0x08 -> :read_write
  #         true -> :unused
  #       end,
  #     identity: if(band(flags, 0x10) == 0x10, do: true, else: false),
  #     computed: if(band(flags, 0x20) == 0x20, do: true, else: false),
  #     sparse_column_set: if(band(flags, 0x40) == 0x40, do: true, else: false),
  #     encrypted: if(band(flags, 0x80) == 0x80, do: true, else: false),
  #     fixed_len_clr_type: if(band(flags, 0x100) == 0x100, do: true, else: false),
  #     hidden: if(band(flags, 0x200) == 0x200, do: true, else: false),
  #     key: if(band(flags, 0x400) == 0x400, do: true, else: false),
  #     nullable_unknown: if(band(flags, 0x800) == 0x800, do: true, else: false)
  #   }
  # end

  defp decode_full_table_name(<<num_parts::byte(1), rest::binary>>) do
    decode_table_name(num_parts, rest, [])
  end

  defp decode_table_name(0, token_stream, table_name_list),
    do: {Enum.reverse(table_name_list), token_stream}

  defp decode_table_name(num_parts, token_stream, table_name_list) do
    <<
      table_name_part_length::byte(1),
      table_name_part::binary-size(table_name_part_length),
      rest::binary
    >> = token_stream

    decode_table_name(num_parts - 1, rest, [table_name_part | table_name_list])
  end
end
