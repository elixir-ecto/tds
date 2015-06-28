# defmodule Tds.Date do
#   @moduledoc """
#   Struct for MSSQL date. https://msdn.microsoft.com/en-us/library/bb630352.aspx
#   ## Fields
#     * `year`
#     * `month`
#     * `day`
#   """
#   @type t :: %__MODULE__{year: 1..9999, month: 1..12, day: 1..31}
#   defstruct [
#     year: 1900,
#     month: 1,
#     day: 1
#   ]
# end


# defmodule Tds.Time do
#   @moduledoc """
#   Struct for MSSQL time. https://msdn.microsoft.com/en-us/library/bb677243.aspx
#   ## Fields
#     * `hour`
#     * `min`
#     * `sec`
#     * `fsec`
#     * `scale`
#   """
#   @type t :: %__MODULE__{hour: 0..23, min: 0..59, sec: 0..59,
#                           fsec: 0..9_999_999, scale: 0..7}
#   defstruct [
#     hour: 0,
#     min: 0,
#     sec: 0,
#     fsec: 0,
#     scale: 0
#   ]
# end

# defmodule Tds.DateTime do
#   @moduledoc """
#   Struct for MSSQL DateTime. https://msdn.microsoft.com/en-us/library/ms187819.aspx
#   ## Fields
#     * `year`
#     * `month`
#     * `day`
#     * `hour`
#     * `min`
#     * `sec`
#     * `300sec`
#   """

#   @type t :: %__MODULE__{year: 1753..9999, month: 1..12, day: 1..31,
#                          hour: 0..23, min: 0..59, sec: 0..999}
#   defstruct [
#     year: 1900,
#     month: 1,
#     day: 1,
#     hour: 0,
#     min: 0,
#     sec: 0,
#     ms: 0
#   ]
# end

# defmodule Tds.DateTime2 do
#   @moduledoc """
#   Struct for MSSQL DateTime2. https://msdn.microsoft.com/en-us/library/bb677335.aspx
#   ## Fields
#     * `year`
#     * `month`
#     * `day`
#     * `hour`
#     * `min`
#     * `sec`
#     * `fsec`
#     * `scale`
#   """

#   @type t :: %__MODULE__{year: 1..9999, month: 1..12, day: 1..31,
#                          hour: 0..23, min: 0..59, sec: 0..59, fsec: 0..9_999_999, scale: 1..7}
#   defstruct [
#     year: 1900,
#     month: 1,
#     day: 1,
#     hour: 0,
#     min: 0,
#     sec: 0,
#     fsec: 0, #fractional secs
#     scale: 0
#   ]
# end

# defmodule Tds.DateTimeOffset do
#   @moduledoc """
#   Struct for MSSQL DateTimeOffset.
#   https://msdn.microsoft.com/en-us/library/bb630289.aspx
#   ## Fields
#     * `year`
#     * `month`
#     * `day`
#     * `hour`
#     * `min`
#     * `sec`
#     * `fsec`
#     * `scale`
#     * `offset_hour`
#     * `offset_min`
#   """

#   @type t :: %__MODULE__{year: 1..9999, month: 1..12, day: 1..31,
#                          hour: 0..23, min: 0..59, sec: 0..59, fsec: 0..9_999_999, scale: 1..7
#                          offset_hour: -14..14, offset_min: 0..59 }
#   defstruct [
#     year: 1900,
#     month: 1,
#     day: 1,
#     hour: 0,
#     min: 0,
#     sec: 0,
#     fsec: 0, #fractional secs
#     offset_hour: 0,
#     offset_min: 0
#   ]
# end

# defmodule Tds.SmallDateTime do
#   @moduledoc """
#   Struct for MSSQL SmallDateTime.
#   https://msdn.microsoft.com/en-us/library/ms182418.aspx
#   ## Fields
#     * `year`
#     * `month`
#     * `day`
#     * `hour`
#     * `min`
#     * `sec`
#   """

#   @type t :: %__MODULE__{year: 1900..2079, month: 1..12, day: 1..12,
#                          hour: 0..23, min: 0..59, sec: 0..59}
#   defstruct [
#     year: 1900,
#     month: 1,
#     day: 1,
#     hour: 0,
#     min: 0,
#     sec: 0,
#   ]
# end
