defmodule Tds.Date do
  @moduledoc """
  Struct for MSSQL date.
  ## Fields
    * `year`
    * `month`
    * `day`
  """
  @type t :: %__MODULE__{year: 0..10000, month: 1..12, day: 1..12}
  defstruct [
    year: 1900,
    month: 1,
    day: 1
  ]
end


defmodule Tds.Time do
  @moduledoc """
  Struct for MSSQL time.
  ## Fields
    * `hour`
    * `min`
    * `sec`
    * `usec`
  """
  @type t :: %__MODULE__{hour: 0..23, min: 0..59, sec: 0..59, usec: 0..999_999}
  defstruct [
    hour: 0,
    min: 0,
    sec: 0,
    usec: 0
  ]
end

defmodule Tds.DateTime do
  @moduledoc """
  Struct for MSSQL DateTime.
  ## Fields
    * `year`
    * `month`
    * `day`
    * `hour`
    * `min`
    * `sec`
  """

  @type t :: %__MODULE__{year: 0..10000, month: 1..12, day: 1..12,
                         hour: 0..23, min: 0..59, sec: 0..59}
  defstruct [
    year: 1900,
    month: 1,
    day: 1,
    hour: 0,
    min: 0,
    sec: 0
  ]
end

defmodule Tds.DateTime2 do
  @moduledoc """
  Struct for MSSQL DateTime2.
  ## Fields
    * `year`
    * `month`
    * `day`
    * `hour`
    * `min`
    * `sec`
    * `usec`
  """

  @type t :: %__MODULE__{year: 0..10000, month: 1..12, day: 1..12,
                         hour: 0..23, min: 0..59, sec: 0..59, usec: 0..999_999}
  defstruct [
    year: 1900,
    month: 1,
    day: 1,
    hour: 0,
    min: 0,
    sec: 0,
    usec: 0
  ]
end