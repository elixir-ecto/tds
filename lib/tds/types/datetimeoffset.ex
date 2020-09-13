defmodule Tds.Types.DateTimeOffset do
  @moduledoc false

  def type, do: :datetimeoffset

  @doc """
  Cast to DateTime
  """
  def cast(%DateTime{microsecond: {us, _}} = dt) do
    {:ok, dt}
  end

  def cast(_), do: :error

  @doc """
  Load from the native Ecto representation to a `DateTime`.

  If the connection is configured with `use_elixir_calendar_types: true`, `load()` will receive a DateTime.
  Otherwise, a `{date, time, offset_min}` tuple is returned.
  """
  def load(nil), do: {:ok, nil}

  def load(%DateTime{} = dt) do
    {:ok, dt}
  end

  def load({{y, mth, d}, {h, min, s, fsec}, offset_mins}) do
    dt =
      %DateTime{
        :year => y,
        :month => mth,
        :day => d,
        :hour => h,
        :minute => min,
        :second => s,
        :microsecond => construct_microseconds({us, p}),
        :time_zone => "Etc/UTC",
        :zone_abbr => "UTC",
        :utc_offset => 0,
        :std_offset => 0
      }
      |> DateTime.add(offset_mins * 60, :second)

    {:ok, dt}
  end

  def load(_, _, _), do: :error

  @impl true

  @doc """
  Convert to the native Ecto representation, which for `Tds` is
  `{{year, month, day}, {hr, min, s, fsec}, offset_in_minutes}`
  or `{{year, month, day}, {hr, min, s}, offset_in_minutes}`
  as per `https://github.com/livehelpnow/tds/blob/master/lib/tds/parameter.ex#L162`.

  **Note that the date and time are in UTC and the offset is in minutes.**
  """
  def dump(%DateTime{} = dt) do
    tds_representation = datetime_to_datetimeoffset(dt, p)

    {:ok, tds_representation}
  end

  @impl true

  def equal?(a, b, _params) do
    a == b
  end

  def datetime_to_datetimeoffset(%DateTime{utc_offset: utc_offset} = dt, p) do
    utc_dt = DateTime.add(dt, utc_offset)

    %DateTime{
      year: y,
      month: mth,
      day: d,
      hour: h,
      minute: min,
      second: s,
      microsecond: {us, _},
      utc_offset: utc_offset
    } = dt

    offset_mins = div(utc_offset, 60)
    fsec = construct_fsec(us, p)
    {{y, mth, d}, {h, min, s, fsec}, offset_mins}
  end

  def construct_fsec(us, p) do
    # fsec = div(us, 1000)
    x = trunc(:math.pow(10, p))
    div(us * x, 1_000_000)

    us
    |> div(1_000_000)
    |> div(x)
    |> (&(&1 * x)).()
  end

  # lifted from Timex datetime/helpers.ex
  def construct_microseconds({us, p}) when is_integer(us) and is_integer(p) do
    construct_microseconds(us, p)
  end

  def construct_microseconds(0, p), do: {0, p}
  def construct_microseconds(n, p), do: {to_precision(n, p), p}

  def to_precision(us, p) do
    case precision(us) do
      detected_p when detected_p > p ->
        # Convert to lower precision
        pow = trunc(:math.pow(10, detected_p - p))
        Integer.floor_div(us, pow) * pow

      _detected_p ->
        # Already correct precision or less precise
        us
    end
  end

  def precision(0), do: 0

  def precision(n) when is_integer(n) do
    ns = Integer.to_string(n)
    n_width = byte_size(ns)
    trimmed = byte_size(String.trim_trailing(ns, "0"))
    new_p = 6 - (n_width - trimmed)

    if new_p >= 6 do
      6
    else
      new_p
    end
  end
end
