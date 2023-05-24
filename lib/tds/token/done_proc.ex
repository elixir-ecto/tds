defmodule Tds.Token.DoneProc do
  @moduledoc """
  """
  import Tds.Protocol.Grammar
  import Bitwise

  defstruct status: nil,
            curcmd: nil,
            done_count: nil

  @typedoc """
  Copletition status of the stored procedure.

  It is returned when all the SQL statements in the stored procedure have completed.
  Can be followed by another DONEPROC token  or a DONEINPROC token only if the `:done_more` flag is set
  as part of `:status` value.
  """
  @type t :: %__MODULE__{
          status: nil | non_neg_integer,
          curcmd: nil | non_neg_integer,
          done_count: nil | non_neg_integer
        }

  def decode(<<
        status::little-ushort(),
        curcmd::little-ushort(),
        done_count::little-ushort(),
        rest::binary
      >>, col_metadata) do
    {
      %__MODULE__{
        status: status,
        curcmd: curcmd,
        done_count: done_count
      },
      rest
    }
  end

  @doc """
  DONE_FINAL is the final DONEPROC in the request.
  """
  @spec done_final?(Tds.Token.DoneProc.t()) :: boolean
  def done_final?(%__MODULE__{status: status}) do
    status?(status, 0x00)
  end

  @doc """
  DONE_MORE. This DONEPROC message is not the final DONEPROC message in the
  response; more data streams are to follow.
  """
  @spec done_more?(Tds.Token.DoneProc.t()) :: boolean
  def done_more?(%__MODULE__{status: status}) do
    status?(status, 0x01)
  end

  @doc """
  DONE_ERROR. An error occurred on the current stored procedure. A preceding ERROR
  token SHOULD be sent when this bit is set.
  """
  @spec done_error?(Tds.Token.DoneProc.t()) :: boolean
  def done_error?(%__MODULE__{status: status}) do
    status?(status, 0x02)
  end

  @doc """
  DONE_INXACT. A transaction is in progress.
  """
  @spec done_in_xact?(Tds.Token.DoneProc.t()) :: boolean
  def done_in_xact?(%__MODULE__{status: status}) do
    status?(status, 0x04)
  end

  @doc """
  DONE_COUNT. The DoneRowCount value is valid. This is used to distinguish between
  a valid value of 0 for DoneRowCount or just an initialized variable.
  """
  @spec done_count?(Tds.Token.DoneProc.t()) :: boolean
  def done_count?(%__MODULE__{status: status}) do
    status?(status, 0x10)
  end

  @doc """
  DONE_RPCINBATCH. This DONEPROC message is associated with an RPC within a
  set of batched RPCs. This flag is not set on the last RPC in the RPC batch.
  """
  @spec done_rpcinbatch?(Tds.Token.DoneProc.t()) :: boolean
  def done_rpcinbatch?(%__MODULE__{status: status}) do
    status?(status, 0x80)
  end

  @doc """
  DONE_SRVERROR used in place of DONE_ERROR when an error occurred on the
  current stored procedure, which is severe enough to require the result set,
  if any, to be discarded.
  """
  @spec done_srverror?(Tds.Token.DoneProc.t()) :: boolean
  def done_srverror?(%__MODULE__{status: status}) do
    status?(status, 0x100)
  end

  defp status?(status, flag) do
    (status &&& flag) == flag
  end

end
