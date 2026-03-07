defmodule Tds.Protocol.ConstantsTest do
  use ExUnit.Case, async: true

  require Tds.Protocol.Constants
  alias Tds.Protocol.Constants

  describe "packet_type/1" do
    test "prelogin" do
      assert Constants.packet_type(:prelogin) == 0x12
    end

    test "sql_batch" do
      assert Constants.packet_type(:sql_batch) == 0x01
    end

    test "rpc" do
      assert Constants.packet_type(:rpc) == 0x03
    end

    test "tabular_result" do
      assert Constants.packet_type(:tabular_result) == 0x04
    end

    test "attention" do
      assert Constants.packet_type(:attention) == 0x06
    end

    test "transaction_manager" do
      assert Constants.packet_type(:transaction_manager) == 0x0E
    end

    test "login7" do
      assert Constants.packet_type(:login7) == 0x10
    end

    test "bulk" do
      assert Constants.packet_type(:bulk) == 0x07
    end

    test "fedauth_token" do
      assert Constants.packet_type(:fedauth_token) == 0x08
    end

    test "sspi" do
      assert Constants.packet_type(:sspi) == 0x11
    end

    test "usable in binary pattern match" do
      packet = <<0x12, 0x01, 0x00, 0x08, 0x00, 0x00, 0x01, 0x00>>
      <<type::unsigned-8, _rest::binary>> = packet
      assert type == Constants.packet_type(:prelogin)
    end
  end

  describe "packet_size/1" do
    test "header_size" do
      assert Constants.packet_size(:header_size) == 8
    end

    test "max_data_size" do
      assert Constants.packet_size(:max_data_size) == 4088
    end

    test "max_packet_size" do
      assert Constants.packet_size(:max_packet_size) == 4096
    end
  end

  describe "tds_type/1 - fixed types" do
    test "null type code" do
      assert Constants.tds_type(:null) == 0x1F
    end

    test "tinyint type code" do
      assert Constants.tds_type(:tinyint) == 0x30
    end

    test "bit type code" do
      assert Constants.tds_type(:bit) == 0x32
    end

    test "int type code" do
      assert Constants.tds_type(:int) == 0x38
    end

    test "bigint type code" do
      assert Constants.tds_type(:bigint) == 0x7F
    end

    test "datetime type code" do
      assert Constants.tds_type(:datetime) == 0x3D
    end

    test "float type code" do
      assert Constants.tds_type(:float) == 0x3E
    end

    test "money type code" do
      assert Constants.tds_type(:money) == 0x3C
    end

    test "smallmoney type code" do
      assert Constants.tds_type(:smallmoney) == 0x7A
    end
  end

  describe "tds_type/1 - variable types" do
    test "uniqueidentifier type code" do
      assert Constants.tds_type(:uniqueidentifier) == 0x24
    end

    test "intn type code" do
      assert Constants.tds_type(:intn) == 0x26
    end

    test "nvarchar type code" do
      assert Constants.tds_type(:nvarchar) == 0xE7
    end

    test "nchar type code" do
      assert Constants.tds_type(:nchar) == 0xEF
    end

    test "varchar type code" do
      assert Constants.tds_type(:varchar) == 0x27
    end

    test "xml type code" do
      assert Constants.tds_type(:xml) == 0xF1
    end

    test "image type code" do
      assert Constants.tds_type(:image) == 0x22
    end

    test "text type code" do
      assert Constants.tds_type(:text) == 0x23
    end

    test "ntext type code" do
      assert Constants.tds_type(:ntext) == 0x63
    end

    test "variant type code" do
      assert Constants.tds_type(:variant) == 0x62
    end

    test "daten type code" do
      assert Constants.tds_type(:daten) == 0x28
    end

    test "timen type code" do
      assert Constants.tds_type(:timen) == 0x29
    end

    test "datetime2n type code" do
      assert Constants.tds_type(:datetime2n) == 0x2A
    end

    test "datetimeoffsetn type code" do
      assert Constants.tds_type(:datetimeoffsetn) == 0x2B
    end

    test "bigvarbinary type code" do
      assert Constants.tds_type(:bigvarbinary) == 0xA5
    end

    test "bigvarchar type code" do
      assert Constants.tds_type(:bigvarchar) == 0xA7
    end

    test "bigbinary type code" do
      assert Constants.tds_type(:bigbinary) == 0xAD
    end

    test "bigchar type code" do
      assert Constants.tds_type(:bigchar) == 0xAF
    end

    test "udt type code" do
      assert Constants.tds_type(:udt) == 0xF0
    end

    test "json type code" do
      assert Constants.tds_type(:json) == 0xF4
    end

    test "vector type code" do
      assert Constants.tds_type(:vector) == 0xF5
    end

    test "decimal legacy type code" do
      assert Constants.tds_type(:decimal) == 0x37
    end

    test "numeric legacy type code" do
      assert Constants.tds_type(:numeric) == 0x3F
    end

    test "usable in binary pattern match" do
      data = <<0x26, 0x04, 0x01, 0x00, 0x00, 0x00>>
      <<type_code::unsigned-8, _rest::binary>> = data
      assert type_code == Constants.tds_type(:intn)
    end
  end

  describe "fixed_data_types/0" do
    test "returns a map of type code to byte length" do
      types = Constants.fixed_data_types()
      assert is_map(types)
      assert Map.get(types, 0x1F) == 0
      assert Map.get(types, 0x30) == 1
      assert Map.get(types, 0x32) == 1
      assert Map.get(types, 0x34) == 2
      assert Map.get(types, 0x38) == 4
      assert Map.get(types, 0x3C) == 8
      assert Map.get(types, 0x7F) == 8
    end
  end

  describe "is_fixed_type?/1" do
    test "returns true for fixed type codes" do
      assert Constants.is_fixed_type?(0x1F) == true
      assert Constants.is_fixed_type?(0x30) == true
      assert Constants.is_fixed_type?(0x38) == true
      assert Constants.is_fixed_type?(0x7F) == true
    end

    test "returns false for variable type codes" do
      assert Constants.is_fixed_type?(0x26) == false
      assert Constants.is_fixed_type?(0xE7) == false
      assert Constants.is_fixed_type?(0x24) == false
    end

    test "returns false for unknown type codes" do
      assert Constants.is_fixed_type?(0x00) == false
      assert Constants.is_fixed_type?(0xFF) == false
    end
  end

  describe "fixed_type_length/1" do
    test "returns length for known fixed types" do
      assert Constants.fixed_type_length(0x1F) == 0
      assert Constants.fixed_type_length(0x30) == 1
      assert Constants.fixed_type_length(0x34) == 2
      assert Constants.fixed_type_length(0x38) == 4
      assert Constants.fixed_type_length(0x3D) == 8
    end

    test "returns nil for non-fixed types" do
      assert Constants.fixed_type_length(0x26) == nil
      assert Constants.fixed_type_length(0xE7) == nil
    end
  end

  describe "token/1" do
    test "offset" do
      assert Constants.token(:offset) == 0x78
    end

    test "returnstatus" do
      assert Constants.token(:returnstatus) == 0x79
    end

    test "colmetadata" do
      assert Constants.token(:colmetadata) == 0x81
    end

    test "altmetadata" do
      assert Constants.token(:altmetadata) == 0x88
    end

    test "dataclassification" do
      assert Constants.token(:dataclassification) == 0xA3
    end

    test "tabname" do
      assert Constants.token(:tabname) == 0xA4
    end

    test "colinfo" do
      assert Constants.token(:colinfo) == 0xA5
    end

    test "order" do
      assert Constants.token(:order) == 0xA9
    end

    test "error" do
      assert Constants.token(:error) == 0xAA
    end

    test "info" do
      assert Constants.token(:info) == 0xAB
    end

    test "returnvalue" do
      assert Constants.token(:returnvalue) == 0xAC
    end

    test "loginack" do
      assert Constants.token(:loginack) == 0xAD
    end

    test "featureextack" do
      assert Constants.token(:featureextack) == 0xAE
    end

    test "row" do
      assert Constants.token(:row) == 0xD1
    end

    test "nbcrow" do
      assert Constants.token(:nbcrow) == 0xD2
    end

    test "altrow" do
      assert Constants.token(:altrow) == 0xD3
    end

    test "envchange" do
      assert Constants.token(:envchange) == 0xE3
    end

    test "sessionstate" do
      assert Constants.token(:sessionstate) == 0xE4
    end

    test "sspi" do
      assert Constants.token(:sspi) == 0xED
    end

    test "fedauthinfo" do
      assert Constants.token(:fedauthinfo) == 0xEE
    end

    test "done" do
      assert Constants.token(:done) == 0xFD
    end

    test "doneproc" do
      assert Constants.token(:doneproc) == 0xFE
    end

    test "doneinproc" do
      assert Constants.token(:doneinproc) == 0xFF
    end

    test "usable in binary pattern match" do
      stream = <<0xFD, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>
      <<tok::unsigned-8, _rest::binary>> = stream
      assert tok == Constants.token(:done)
    end
  end

  describe "encryption/1" do
    test "off" do
      assert Constants.encryption(:off) == 0x00
    end

    test "on" do
      assert Constants.encryption(:on) == 0x01
    end

    test "not_supported" do
      assert Constants.encryption(:not_supported) == 0x02
    end

    test "required" do
      assert Constants.encryption(:required) == 0x03
    end
  end

  describe "prelogin_token_type/1" do
    test "version" do
      assert Constants.prelogin_token_type(:version) == 0x00
    end

    test "encryption" do
      assert Constants.prelogin_token_type(:encryption) == 0x01
    end

    test "terminator" do
      assert Constants.prelogin_token_type(:terminator) == 0xFF
    end

    test "fed_auth_required" do
      assert Constants.prelogin_token_type(:fed_auth_required) == 0x06
    end

    test "nonce_opt" do
      assert Constants.prelogin_token_type(:nonce_opt) == 0x07
    end
  end

  describe "time_byte_length/1" do
    test "scale 0 maps to 3 bytes" do
      assert Constants.time_byte_length(0) == 3
    end

    test "scale 1 maps to 3 bytes" do
      assert Constants.time_byte_length(1) == 3
    end

    test "scale 2 maps to 3 bytes" do
      assert Constants.time_byte_length(2) == 3
    end

    test "scale 3 maps to 4 bytes" do
      assert Constants.time_byte_length(3) == 4
    end

    test "scale 4 maps to 4 bytes" do
      assert Constants.time_byte_length(4) == 4
    end

    test "scale 5 maps to 5 bytes" do
      assert Constants.time_byte_length(5) == 5
    end

    test "scale 6 maps to 5 bytes" do
      assert Constants.time_byte_length(6) == 5
    end

    test "scale 7 maps to 5 bytes" do
      assert Constants.time_byte_length(7) == 5
    end
  end

  describe "plp/1" do
    test "plp_null" do
      assert Constants.plp(:null) == 0xFFFFFFFFFFFFFFFF
    end

    test "plp_unknown_length" do
      assert Constants.plp(:unknown_length) == 0xFFFFFFFFFFFFFFFE
    end

    test "plp_marker_length" do
      assert Constants.plp(:marker_length) == 0xFFFF
    end

    test "max_short_data_size" do
      assert Constants.plp(:max_short_data_size) == 8000
    end
  end

  describe "envchange_type/1" do
    test "database" do
      assert Constants.envchange_type(:database) == 0x01
    end

    test "packet_size" do
      assert Constants.envchange_type(:packet_size) == 0x04
    end

    test "begin_transaction" do
      assert Constants.envchange_type(:begin_transaction) == 0x08
    end

    test "commit_transaction" do
      assert Constants.envchange_type(:commit_transaction) == 0x09
    end

    test "rollback_transaction" do
      assert Constants.envchange_type(:rollback_transaction) == 0x0A
    end

    test "routing_info" do
      assert Constants.envchange_type(:routing_info) == 0x14
    end

    test "sql_collation" do
      assert Constants.envchange_type(:sql_collation) == 0x07
    end

    test "transaction_ended" do
      assert Constants.envchange_type(:transaction_ended) == 0x11
    end
  end

  describe "isolation_level/1" do
    test "read_uncommitted" do
      assert Constants.isolation_level(:read_uncommitted) == 0x01
    end

    test "read_committed" do
      assert Constants.isolation_level(:read_committed) == 0x02
    end

    test "repeatable_read" do
      assert Constants.isolation_level(:repeatable_read) == 0x03
    end

    test "snapshot" do
      assert Constants.isolation_level(:snapshot) == 0x04
    end

    test "serializable" do
      assert Constants.isolation_level(:serializable) == 0x05
    end
  end

  describe "tds_version/1" do
    test "tds_7_0" do
      assert Constants.tds_version(:tds_7_0) == 0x70000000
    end

    test "tds_7_1" do
      assert Constants.tds_version(:tds_7_1) == 0x71000001
    end

    test "tds_7_2" do
      assert Constants.tds_version(:tds_7_2) == 0x72090002
    end

    test "tds_7_3a" do
      assert Constants.tds_version(:tds_7_3a) == 0x730A0003
    end

    test "tds_7_3b" do
      assert Constants.tds_version(:tds_7_3b) == 0x730B0003
    end

    test "tds_7_4" do
      assert Constants.tds_version(:tds_7_4) == 0x74000004
    end

    test "usable in binary pattern match" do
      data = <<0x74, 0x00, 0x00, 0x04>>
      <<ver::unsigned-big-32>> = data
      assert ver == Constants.tds_version(:tds_7_4)
    end
  end

  describe "feature_id/1" do
    test "sessionrecovery" do
      assert Constants.feature_id(:sessionrecovery) == 0x01
    end

    test "fedauth" do
      assert Constants.feature_id(:fedauth) == 0x02
    end

    test "columnencryption" do
      assert Constants.feature_id(:columnencryption) == 0x04
    end

    test "globaltransactions" do
      assert Constants.feature_id(:globaltransactions) == 0x05
    end

    test "azuresqlsupport" do
      assert Constants.feature_id(:azuresqlsupport) == 0x08
    end

    test "dataclassification" do
      assert Constants.feature_id(:dataclassification) == 0x09
    end

    test "utf8_support" do
      assert Constants.feature_id(:utf8_support) == 0x0A
    end

    test "azuresqldnscaching" do
      assert Constants.feature_id(:azuresqldnscaching) == 0x0B
    end

    test "jsonsupport" do
      assert Constants.feature_id(:jsonsupport) == 0x0D
    end

    test "vectorsupport" do
      assert Constants.feature_id(:vectorsupport) == 0x0E
    end

    test "enhancedroutingsupport" do
      assert Constants.feature_id(:enhancedroutingsupport) == 0x0F
    end

    test "useragent" do
      assert Constants.feature_id(:useragent) == 0x10
    end

    test "terminator" do
      assert Constants.feature_id(:terminator) == 0xFF
    end
  end
end
