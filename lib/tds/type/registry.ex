defmodule Tds.Type.Registry do
  @moduledoc """
  Maps TDS type codes and Elixir type names to handler modules.

  Stored in connection state, built once at connection init.
  User-provided handler modules override built-in handlers
  for the same type codes or names.
  """

  @type t :: %__MODULE__{
          by_code: %{byte() => module()},
          by_name: %{atom() => module()},
          user_types: [module()]
        }

  @enforce_keys [:by_code, :by_name, :user_types]
  defstruct [:by_code, :by_name, :user_types]

  @doc """
  Build registry from user-provided and built-in handler lists.

  User handlers override built-ins for the same type code or name
  because `builtin_types ++ extra_types` means later entries win
  in the map comprehension.
  """
  @spec new(
          extra_types :: [module()],
          builtin_types :: [module()]
        ) :: t()
  def new(extra_types \\ [], builtin_types \\ default_builtins()) do
    all = builtin_types ++ extra_types

    by_code =
      for handler <- all,
          code <- handler.type_codes(),
          into: %{},
          do: {code, handler}

    by_name =
      for handler <- all,
          name <- handler.type_names(),
          into: %{},
          do: {name, handler}

    %__MODULE__{
      by_code: by_code,
      by_name: by_name,
      user_types: extra_types
    }
  end

  @doc "Decode path: type code -> handler module."
  @spec handler_for_code(t(), byte()) :: {:ok, module()} | :error
  def handler_for_code(%__MODULE__{by_code: by_code}, code) do
    Map.fetch(by_code, code)
  end

  @doc "Encode path: atom type name -> handler module."
  @spec handler_for_name(t(), atom()) :: {:ok, module()} | :error
  def handler_for_name(%__MODULE__{by_name: by_name}, name) do
    Map.fetch(by_name, name)
  end

  @doc """
  Encode path: infer handler from Elixir value.

  Tries user types first (linear scan), then falls back
  to guard-based type name lookup in the by_name map.
  """
  @spec infer(t(), term()) ::
          {:ok, module(), Tds.Type.metadata()} | :error
  def infer(%__MODULE__{} = reg, value) do
    case try_handlers(reg.user_types, value) do
      {:ok, _mod, _meta} = hit ->
        hit

      :skip ->
        infer_from_name(reg.by_name, value)
    end
  end

  defp infer_from_name(by_name, value) do
    name = value_to_type_name(value)

    case Map.fetch(by_name, name) do
      {:ok, handler} -> call_infer(handler, value)
      :error -> :error
    end
  end

  # Boolean MUST come before integer (booleans are integers)
  defp value_to_type_name(v) when is_boolean(v), do: :boolean
  defp value_to_type_name(v) when is_integer(v), do: :integer
  defp value_to_type_name(v) when is_float(v), do: :float

  defp value_to_type_name(v) when is_binary(v) do
    if String.valid?(v), do: :string, else: :binary
  end

  defp value_to_type_name(%Decimal{}), do: :decimal
  defp value_to_type_name(%Date{}), do: :date
  defp value_to_type_name(%Time{}), do: :time
  defp value_to_type_name(%NaiveDateTime{}), do: :datetime2
  defp value_to_type_name(%DateTime{}), do: :datetimeoffset
  defp value_to_type_name(nil), do: :binary
  defp value_to_type_name(_), do: nil

  defp call_infer(handler, value) do
    case handler.infer(value) do
      {:ok, meta} -> {:ok, handler, meta}
      :skip -> :error
    end
  end

  defp try_handlers([], _value), do: :skip

  defp try_handlers([handler | rest], value) do
    case handler.infer(value) do
      {:ok, meta} -> {:ok, handler, meta}
      :skip -> try_handlers(rest, value)
    end
  end

  defp default_builtins do
    [
      Tds.Type.Boolean,
      Tds.Type.Integer,
      Tds.Type.Float,
      Tds.Type.Decimal,
      Tds.Type.Money,
      Tds.Type.String,
      Tds.Type.Binary,
      Tds.Type.DateTime,
      Tds.Type.UUID,
      Tds.Type.Xml,
      Tds.Type.Variant,
      Tds.Type.UDT
    ]
  end
end
