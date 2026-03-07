defmodule Tds.Protocol.Constants do
  @moduledoc """
  All TDS protocol constants (or type tokens if you like).

  Provides macros that expand to integer literals at compile time,
  making them usable in binary pattern matching and guard clauses.

  ## Usage

      require Tds.Protocol.Constants
      alias Tds.Protocol.Constants

      # In a function head / binary match:
      def decode(<<Constants.token(:done), rest::binary>>), do: ...

      # As a plain value:
      type = Constants.packet_type(:login7)
  """

  # ---------------------------------------------------------------------------
  # Packet Types
  # ---------------------------------------------------------------------------

  @packet_types %{
    sql_batch: 0x01,
    rpc: 0x03,
    tabular_result: 0x04,
    attention: 0x06,
    bulk: 0x07,
    fedauth_token: 0x08,
    transaction_manager: 0x0E,
    login7: 0x10,
    sspi: 0x11,
    prelogin: 0x12
  }

  @doc "Returns the numeric packet type code for the given atom."
  defmacro packet_type(name) do
    Map.fetch!(@packet_types, name)
  end

  # ---------------------------------------------------------------------------
  # Packet Sizes
  # ---------------------------------------------------------------------------

  @packet_sizes %{
    header_size: 8,
    max_data_size: 4088,
    max_packet_size: 4096
  }

  @doc "Returns the packet size constant for the given atom."
  defmacro packet_size(name) do
    Map.fetch!(@packet_sizes, name)
  end

  # ---------------------------------------------------------------------------
  # TDS Data Type Codes
  # ---------------------------------------------------------------------------

  # Fixed-length data types (zero-length null is included here)
  @fixed_types %{
    null: 0x1F,
    tinyint: 0x30,
    bit: 0x32,
    smallint: 0x34,
    int: 0x38,
    smalldatetime: 0x3A,
    real: 0x3B,
    money: 0x3C,
    datetime: 0x3D,
    float: 0x3E,
    smallmoney: 0x7A,
    bigint: 0x7F
  }

  # Variable-length data types
  @variable_types %{
    uniqueidentifier: 0x24,
    intn: 0x26,
    # Legacy types
    decimal: 0x37,
    numeric: 0x3F,
    bitn: 0x68,
    decimaln: 0x6A,
    numericn: 0x6C,
    floatn: 0x6D,
    moneyn: 0x6E,
    datetimen: 0x6F,
    daten: 0x28,
    timen: 0x29,
    datetime2n: 0x2A,
    datetimeoffsetn: 0x2B,
    # Legacy short types
    char: 0x2F,
    varchar: 0x27,
    binary: 0x2D,
    varbinary: 0x25,
    # Big types (used for actual protocol encoding)
    bigvarbinary: 0xA5,
    bigvarchar: 0xA7,
    bigbinary: 0xAD,
    bigchar: 0xAF,
    nvarchar: 0xE7,
    nchar: 0xEF,
    xml: 0xF1,
    udt: 0xF0,
    json: 0xF4,
    vector: 0xF5,
    text: 0x23,
    image: 0x22,
    ntext: 0x63,
    variant: 0x62
  }

  @all_types Map.merge(@fixed_types, @variable_types)

  @doc "Returns the numeric TDS data type code for the given atom."
  defmacro tds_type(name) do
    Map.fetch!(@all_types, name)
  end

  # Fixed data types mapped by code -> byte length
  @fixed_data_types_map %{
    0x1F => 0,
    0x30 => 1,
    0x32 => 1,
    0x34 => 2,
    0x38 => 4,
    0x3A => 4,
    0x3B => 4,
    0x3C => 8,
    0x3D => 8,
    0x3E => 8,
    0x7A => 4,
    0x7F => 8
  }

  @doc "Returns a map of fixed type code => byte length."
  @spec fixed_data_types() :: %{non_neg_integer() => non_neg_integer()}
  def fixed_data_types, do: @fixed_data_types_map

  @doc "Returns true if the given type code is a fixed-length data type."
  @spec is_fixed_type?(non_neg_integer()) :: boolean()
  def is_fixed_type?(code), do: Map.has_key?(@fixed_data_types_map, code)

  @doc "Returns the byte length for a fixed type code, or nil if not a fixed type."
  @spec fixed_type_length(non_neg_integer()) :: non_neg_integer() | nil
  def fixed_type_length(code), do: Map.get(@fixed_data_types_map, code)

  # ---------------------------------------------------------------------------
  # Token Codes
  # ---------------------------------------------------------------------------

  @tokens %{
    offset: 0x78,
    returnstatus: 0x79,
    colmetadata: 0x81,
    altmetadata: 0x88,
    dataclassification: 0xA3,
    tabname: 0xA4,
    colinfo: 0xA5,
    order: 0xA9,
    error: 0xAA,
    info: 0xAB,
    returnvalue: 0xAC,
    loginack: 0xAD,
    featureextack: 0xAE,
    row: 0xD1,
    nbcrow: 0xD2,
    altrow: 0xD3,
    envchange: 0xE3,
    sessionstate: 0xE4,
    sspi: 0xED,
    fedauthinfo: 0xEE,
    done: 0xFD,
    doneproc: 0xFE,
    doneinproc: 0xFF
  }

  @doc "Returns the numeric token code for the given atom."
  defmacro token(name) do
    Map.fetch!(@tokens, name)
  end

  # ---------------------------------------------------------------------------
  # Encryption Flags
  # ---------------------------------------------------------------------------

  @encryption_flags %{
    off: 0x00,
    on: 0x01,
    not_supported: 0x02,
    required: 0x03
  }

  @doc "Returns the numeric encryption flag for the given atom."
  defmacro encryption(name) do
    Map.fetch!(@encryption_flags, name)
  end

  # ---------------------------------------------------------------------------
  # Prelogin Token Types
  # ---------------------------------------------------------------------------

  @prelogin_token_types %{
    version: 0x00,
    encryption: 0x01,
    instopt: 0x02,
    thread_id: 0x03,
    mars: 0x04,
    trace_id: 0x05,
    fed_auth_required: 0x06,
    nonce_opt: 0x07,
    terminator: 0xFF
  }

  @doc "Returns the numeric prelogin token type for the given atom."
  defmacro prelogin_token_type(name) do
    Map.fetch!(@prelogin_token_types, name)
  end

  # ---------------------------------------------------------------------------
  # Time Scale to Byte Length
  # ---------------------------------------------------------------------------

  @time_scale_lengths %{
    0 => 3,
    1 => 3,
    2 => 3,
    3 => 4,
    4 => 4,
    5 => 5,
    6 => 5,
    7 => 5
  }

  @doc "Returns the byte length needed to store a time value at the given scale (0..7)."
  @spec time_byte_length(0..7) :: 3 | 4 | 5
  def time_byte_length(scale) when scale in 0..7 do
    Map.fetch!(@time_scale_lengths, scale)
  end

  # ---------------------------------------------------------------------------
  # PLP (Partially Length-Prefixed) Constants
  # ---------------------------------------------------------------------------

  @plp_constants %{
    null: 0xFFFFFFFFFFFFFFFF,
    unknown_length: 0xFFFFFFFFFFFFFFFE,
    marker_length: 0xFFFF,
    max_short_data_size: 8000
  }

  @doc "Returns the PLP constant for the given atom."
  defmacro plp(name) do
    Map.fetch!(@plp_constants, name)
  end

  # ---------------------------------------------------------------------------
  # Environment Change Types
  # ---------------------------------------------------------------------------

  @envchange_types %{
    database: 0x01,
    language: 0x02,
    charset: 0x03,
    packet_size: 0x04,
    unicode_data_sorting_local_id: 0x05,
    unicode_data_sorting_comparison_flags: 0x06,
    sql_collation: 0x07,
    begin_transaction: 0x08,
    commit_transaction: 0x09,
    rollback_transaction: 0x0A,
    enlist_dtc_transaction: 0x0B,
    defect_transaction: 0x0C,
    real_time_log_shipping: 0x0D,
    promote_transaction: 0x0F,
    transaction_manager_address: 0x10,
    transaction_ended: 0x11,
    reset_completion_acknowledgement: 0x12,
    user_instance_started: 0x13,
    routing_info: 0x14
  }

  @doc "Returns the numeric environment change type for the given atom."
  defmacro envchange_type(name) do
    Map.fetch!(@envchange_types, name)
  end

  # ---------------------------------------------------------------------------
  # Isolation Levels
  # ---------------------------------------------------------------------------

  @isolation_levels %{
    read_uncommitted: 0x01,
    read_committed: 0x02,
    repeatable_read: 0x03,
    snapshot: 0x04,
    serializable: 0x05
  }

  @doc "Returns the numeric isolation level for the given atom."
  defmacro isolation_level(name) do
    Map.fetch!(@isolation_levels, name)
  end

  # ---------------------------------------------------------------------------
  # TDS Protocol Versions
  # ---------------------------------------------------------------------------

  @tds_versions %{
    tds_7_0: 0x70000000,
    tds_7_1: 0x71000001,
    tds_7_2: 0x72090002,
    tds_7_3a: 0x730A0003,
    tds_7_3b: 0x730B0003,
    tds_7_4: 0x74000004
  }

  @doc "Returns the 4-byte TDS version code for the given atom."
  defmacro tds_version(name) do
    Map.fetch!(@tds_versions, name)
  end

  # ---------------------------------------------------------------------------
  # Login7 Feature Extension IDs
  # ---------------------------------------------------------------------------

  @feature_ids %{
    sessionrecovery: 0x01,
    fedauth: 0x02,
    columnencryption: 0x04,
    globaltransactions: 0x05,
    azuresqlsupport: 0x08,
    dataclassification: 0x09,
    utf8_support: 0x0A,
    azuresqldnscaching: 0x0B,
    jsonsupport: 0x0D,
    vectorsupport: 0x0E,
    enhancedroutingsupport: 0x0F,
    useragent: 0x10,
    terminator: 0xFF
  }

  @doc "Returns the numeric feature extension ID for the given atom."
  defmacro feature_id(name) do
    Map.fetch!(@feature_ids, name)
  end
end
