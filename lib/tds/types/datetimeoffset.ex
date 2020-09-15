defmodule Tds.Types.DateTimeOffset do
  @moduledoc false

  import Tds.Utils, only: [use_elixir_calendar_types?: 0]

  @type t :: {date, time | time_us, offset}
  @type date :: {non_neg_integer, non_neg_integer, non_neg_integer}
  @type time :: {non_neg_integer, non_neg_integer, non_neg_integer}
  @type time_us ::
          {non_neg_integer, non_neg_integer, non_neg_integer, non_neg_integer}
  @type offset :: -840..840

  def type, do: :datetimeoffset

  @doc """
  Cast to DateTime
  """
  def cast(%DateTime{} = dt) do
    {:ok, dt}
  end

  def cast(input) when is_binary(input) do
    case DateTime.from_iso8601(input) do
      {:ok, dt, _offset} -> {:ok, dt}
      {:error, _} -> :error
    end
  end

  def cast(_), do: :error

  @doc """
  Load from the native representation to a `DateTime`.

  If the connection is configured with `use_elixir_calendar_types: true`, `load()` will receive a DateTime.
  Otherwise, a `{date, time, offset_min}` tuple is returned.
  """

  # def load(nil), do: {:ok, nil}

  def load(%DateTime{} = dt) do
    {:ok, dt}
  end

  def load({{y, mth, d}, {h, min, s}, _offset_mins}) do
    dt = %DateTime{
      :year => y,
      :month => mth,
      :day => d,
      :hour => h,
      :minute => min,
      :second => s,
      :microsecond => {0, 0},
      :time_zone => "Etc/UTC",
      :zone_abbr => "UTC",
      :utc_offset => 0,
      :std_offset => 0
    }

    {:ok, dt}
  end

  # we don't know the scale of the column at this juncture, so we guess the scale of the fsec...  Use Elixir calendar types or the parameterized type.
  def load({{y, mth, d}, {h, min, s, fsec}, _offset_mins}) do
    dt = %DateTime{
      :year => y,
      :month => mth,
      :day => d,
      :hour => h,
      :minute => min,
      :second => s,
      :microsecond => fsec_to_microsecond(fsec),
      :time_zone => "Etc/UTC",
      :zone_abbr => "UTC",
      :utc_offset => 0,
      :std_offset => 0
    }

    {:ok, dt}
  end

  def load(_), do: :error

  @doc """
  Dump the data to the Ecto native type.  If using Elixir calendary types, this will be the DateTime, otherwise
  we convert to the datetimeoffset tuple of `{{year, month, day}, {hr, min, sec, fsec}, offset_in_minutes}`
  or `{{year, month, day}, {hr, min, sec}, offset_in_minutes}`.

  Note that the date and time are in UTC and the offset is in minutes.
  """
  def dump(%DateTime{} = dt) do
    if use_elixir_calendar_types?() do
      {:ok, dt}
    else
      {:ok, datetimeoffset_tuple(dt)}
    end
  end

  def equal?(a, b) do
    a == b
  end

  @spec autogenerate :: t | :error
  @doc """
  Generates a datetimeoffset tuple for a timestamp() column.

  If you prefer to store the [timestamp](https://hexdocs.pm/ecto/Ecto.Schema.html#timestamps/1) in the local time
  you can specify the autogenerate MFA in the Ecto schema definition.

      defmodule MyTimestamps do
        def local_now do
          case Timex.local() do
            {:error, _} ->
              :error

            %DateTime{} = dt ->
              datetimeoffset_tuple(dt)

            %AmbiguousDateTime{after: dt} ->
              datetimeoffset_tuple(dt)
          end

      schema "something" do
        ...
        timestamps(type: :utc_datetime, autogenerate: {MyTimestamps, local_now, []})
      end

  or with `@timestamps_opts` schema attribute.

      @timestamps_opts [type: :utc_datetime, autogenerate: {MyTimestamps, local_now, []}]
      schema "something" do
        ...
      end

  """
  def autogenerate do
    DateTime.utc_now()
    |> datetimeoffset_tuple()
  end

  # required for timestamps() columns
  def from_unix!(t, unit) do
    DateTime.from_unix!(t, unit)
  end

  def datetimeoffset_tuple(%DateTime{utc_offset: utc_offset} = dt) do
    utc_dt = DateTime.add(dt, -utc_offset)

    %DateTime{
      year: y,
      month: mth,
      day: d,
      hour: h,
      minute: min,
      second: s,
      microsecond: {us, scale}
    } = utc_dt

    offset_mins = div(utc_offset, 60)

    case scale do
      0 ->
        {{y, mth, d}, {h, min, s}, offset_mins}

      _ ->
        fsec = Tds.Types.microsecond_to_fsec({us, scale})
        {{y, mth, d}, {h, min, s, fsec}, offset_mins}
    end

    # case Tds.Types.microsecond_to_fsec({us, scale}) do
    #   0 -> {{y, mth, d}, {h, min, s}, offset_mins}
    #   fsec -> {{y, mth, d}, {h, min, s, fsec}, offset_mins}
    # end
  end

  def fsec_to_microsecond(0), do: {0, 0}

  def fsec_to_microsecond(fsec) do
    scale = length(Integer.digits(fsec))
    us = trunc(fsec * :math.pow(10, 6 - scale))

    p =
      if scale >= 6 do
        6
      else
        scale
      end

    {us, p}
  end
end
