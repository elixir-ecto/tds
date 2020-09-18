defmodule Tds.Types.DateTimeOffset do
  @moduledoc """
  Support for [`datetimeoffset(n)`](https://docs.microsoft.com/en-us/sql/t-sql/data-types/datetimeoffset-transact-sql).atom()

  Columns can be defined as a `datetimeoffset(n)` in an Ecto migration.

      create table(:datetimeoffsets) do
        add :dto,   :"datetimeoffset"
        add :zero,  :"datetimeoffset(0)"
        add :one,   :"datetimeoffset(1)"
        add :two,   :"datetimeoffset(2)"
        ...
        add :seven, :"datetimeoffset(7)"
      end

  And referenced in an Ecto schema.

      schema "datetimeoffsets" do
        field :dto,   Tds.Types.DateTimeOffset
        field :zero,  Tds.Types.DateTimeOffset
        field :one,   Tds.Types.DateTimeOffset
        field :two,   Tds.Types.DateTimeOffset
        ...
        field :seven, Tds.Types.DateTimeOffset

        timestamps type: Tds.Types.DateTimeOffset
      end

  This will store the `inserted_at` and `updated_at` [timestamps](https://hexdocs.pm/ecto/Ecto.Schema.html#timestamps/1) in UTC.
  If you prefer to store them in local time you can specify the autogenerate MFA in the Ecto schema definition.

  Configure the application to use a timezone aware time zone database in `config.exs`:

      config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

  Create a module to generate local timestamps.

      defmodule LocalTimestamps do

        def local_now do
          case Timex.local() do
            {:error, _} ->
              :error

            %DateTime{} = dt ->
              dt

            %Timex.AmbiguousDateTime{after: dt} ->
              dt
          end
        end
      end

  And a schema that uses the local timestamps.

      defmodule Something do
        schema "something" do
          ...
          timestamps(type: :utc_datetime_usec, autogenerate: {LocalTimestamps, :local_now, []})
        end
      end

  or with `@timestamps_opts` schema attribute.

      @timestamps_opts [type: :utc_datetime_usec, autogenerate: {LocalTimestamps, :local_now, []}]
      schema "something" do
        ...
      end


  """

  @type t :: {date, time | time_us, offset}
  @type date :: {non_neg_integer, non_neg_integer, non_neg_integer}
  @type time :: {non_neg_integer, non_neg_integer, non_neg_integer}
  @type time_us ::
          {non_neg_integer, non_neg_integer, non_neg_integer, non_neg_integer}
  @type offset :: -840..840

  def type, do: :datetimeoffset

  @doc """
  Cast to DateTime.
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
  Handle casting to DateTime without returning a tuple.
  """
  def cast!(input) do
    case cast(input) do
      {:ok, dt} -> dt
      :error -> :error
    end
  end

  @doc """
  Load from the native representation to a `DateTime`.

  If the connection is configured with `use_elixir_calendar_types: true`, `load()` will receive a DateTime.
  Otherwise, a `{date, time, offset_min}` tuple is returned.
  """

  def load(%DateTime{} = dt) do
    {:ok, dt}
  end

  def load({{y, mth, d}, {h, min, s}, offset_mins}) do
    load({{y, mth, d}, {h, min, s, 0}, offset_mins})
  end

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
  Dump the data to the Ecto native type.
  """
  def dump(%DateTime{} = dt) do
    {:ok, datetimeoffset_tuple(dt)}
  end

  def dump({{_, _, _}, {_, _, _}, _} = dtt) do
    {:ok, dtt}
  end

  def dump({{_, _, _}, {_, _, _, _}, _} = dtt) do
    {:ok, dtt}
  end

  def dump(_), do: :error

  def equal?(a, b) do
    a == b
  end

  @spec autogenerate :: t | :error
  @doc """
  Generates a datetimeoffset tuple for a timestamp() column.
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
