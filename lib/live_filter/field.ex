defprotocol LiveFilter.Field do
  @moduledoc """
  Protocol for defining custom field types in LiveFilter.

  This protocol allows users to define completely custom field types with their own
  conversion logic, operators, and validation rules. It's entirely optional - users
  can work with LiveFilter without ever implementing this protocol.

  ## Example Implementation

      defmodule MyApp.PriorityField do
        defstruct [:levels, :default]

        def new(opts \\ []) do
          %__MODULE__{
            levels: Keyword.get(opts, :levels, [:low, :medium, :high, :urgent]),
            default: Keyword.get(opts, :default, :medium)
          }
        end
      end

      defimpl LiveFilter.Field, for: MyApp.PriorityField do
        def to_filter_value(%{levels: levels}, ui_value) do
          # Convert UI selection to filter value
          case ui_value do
            "urgent_only" -> [:urgent]
            "high_and_up" -> [:high, :urgent]
            level when level in levels -> [level]
            _ -> nil
          end
        end

        def to_ui_value(_, filter_value) do
          # Convert filter value back to UI representation
          case filter_value do
            [:urgent] -> "urgent_only"
            [:high, :urgent] -> "high_and_up"
            [level] -> level
            _ -> nil
          end
        end

        def default_operator(_), do: :in

        def validate(%{levels: levels}, value) do
          if Enum.all?(value, &(&1 in levels)) do
            :ok
          else
            {:error, "Invalid priority level"}
          end
        end

        def operators(_) do
          [:in, :not_in, :equals]
        end

        def ui_component(_) do
          :custom_priority_selector
        end
      end
  """

  @doc """
  Convert a UI value (from form input, API, etc.) to a filter value.

  This function handles the transformation from user input to the internal
  filter representation.

  ## Parameters

    * `field_type` - The field type struct
    * `ui_value` - The value from the UI/form

  ## Returns

  The transformed value suitable for use in a LiveFilter.Filter struct,
  or nil if the value should be ignored.
  """
  @spec to_filter_value(t, any()) :: any() | nil
  def to_filter_value(field_type, ui_value)

  @doc """
  Convert a filter value back to UI representation.

  This is the inverse of `to_filter_value/2` and is used when restoring
  UI state from URL parameters or saved filters.

  ## Parameters

    * `field_type` - The field type struct
    * `filter_value` - The value from a LiveFilter.Filter

  ## Returns

  The value suitable for display/selection in the UI.
  """
  @spec to_ui_value(t, any()) :: any()
  def to_ui_value(field_type, filter_value)

  @doc """
  Get the default operator for this field type.

  Used when creating filters without an explicit operator.

  ## Parameters

    * `field_type` - The field type struct

  ## Returns

  An atom representing the default operator (e.g., `:equals`, `:contains`, `:in`)
  """
  @spec default_operator(t) :: atom()
  def default_operator(field_type)

  @doc """
  Validate a value for this field type.

  ## Parameters

    * `field_type` - The field type struct
    * `value` - The value to validate

  ## Returns

    * `:ok` if valid
    * `{:error, reason}` if invalid
  """
  @spec validate(t, any()) :: :ok | {:error, String.t()}
  def validate(field_type, value)

  @doc """
  Get available operators for this field type.

  ## Parameters

    * `field_type` - The field type struct

  ## Returns

  List of operator atoms that are valid for this field type.
  """
  @spec operators(t) :: [atom()]
  def operators(field_type)

  @doc """
  Get the suggested UI component for this field type.

  This is just a hint - the actual UI implementation can use any component.

  ## Parameters

    * `field_type` - The field type struct

  ## Returns

  An atom identifying the suggested component type, or a map with component details.
  """
  @spec ui_component(t) :: atom() | map()
  def ui_component(field_type)
end

# Built-in implementations for common Elixir types

defimpl LiveFilter.Field, for: Atom do
  def to_filter_value(:string, value) when is_binary(value) and value != "", do: value
  def to_filter_value(:string, ""), do: nil
  def to_filter_value(:string, nil), do: nil

  def to_filter_value(:integer, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  def to_filter_value(:integer, value) when is_integer(value), do: value
  def to_filter_value(:integer, _), do: nil

  def to_filter_value(:float, value) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> float
      _ -> nil
    end
  end

  def to_filter_value(:float, value) when is_float(value), do: value
  def to_filter_value(:float, value) when is_integer(value), do: value * 1.0
  def to_filter_value(:float, _), do: nil

  def to_filter_value(:boolean, "true"), do: true
  def to_filter_value(:boolean, "false"), do: false
  def to_filter_value(:boolean, true), do: true
  def to_filter_value(:boolean, false), do: false
  def to_filter_value(:boolean, _), do: nil

  def to_filter_value(:date, %Date{} = date), do: date

  def to_filter_value(:date, value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  def to_filter_value(:date, _), do: nil

  def to_filter_value(:enum, value) when is_binary(value), do: value
  def to_filter_value(:enum, value) when is_atom(value), do: value
  def to_filter_value(:enum, values) when is_list(values), do: values
  def to_filter_value(:enum, _), do: nil

  def to_filter_value(:array, values) when is_list(values), do: values
  def to_filter_value(:array, value) when is_binary(value), do: [value]
  def to_filter_value(:array, _), do: []

  def to_filter_value(_, value), do: value

  def to_ui_value(:string, value), do: to_string(value || "")
  def to_ui_value(:integer, value), do: value
  def to_ui_value(:float, value), do: value
  def to_ui_value(:boolean, value), do: value == true
  def to_ui_value(:date, %Date{} = date), do: Date.to_iso8601(date)
  def to_ui_value(:enum, value), do: value
  def to_ui_value(:array, value), do: value || []
  def to_ui_value(_, value), do: value

  def default_operator(:string), do: :contains
  def default_operator(:integer), do: :equals
  def default_operator(:float), do: :equals
  def default_operator(:boolean), do: :equals
  def default_operator(:date), do: :equals
  def default_operator(:enum), do: :equals
  def default_operator(:array), do: :contains_any
  def default_operator(_), do: :equals

  def validate(:string, value) when is_binary(value), do: :ok
  def validate(:integer, value) when is_integer(value), do: :ok
  def validate(:float, value) when is_number(value), do: :ok
  def validate(:boolean, value) when is_boolean(value), do: :ok
  def validate(:date, %Date{}), do: :ok
  def validate(:enum, value) when is_binary(value) or is_atom(value), do: :ok
  def validate(:array, value) when is_list(value), do: :ok
  def validate(type, _value), do: {:error, "Invalid value for type #{type}"}

  def operators(:string),
    do: [
      :equals,
      :not_equals,
      :contains,
      :not_contains,
      :starts_with,
      :ends_with,
      :is_empty,
      :is_not_empty
    ]

  def operators(:integer),
    do: [
      :equals,
      :not_equals,
      :greater_than,
      :less_than,
      :greater_than_or_equal,
      :less_than_or_equal,
      :between,
      :is_empty,
      :is_not_empty
    ]

  def operators(:float),
    do: [
      :equals,
      :not_equals,
      :greater_than,
      :less_than,
      :greater_than_or_equal,
      :less_than_or_equal,
      :between,
      :is_empty,
      :is_not_empty
    ]

  def operators(:boolean), do: [:is_true, :is_false, :equals]

  def operators(:date),
    do: [
      :equals,
      :before,
      :after,
      :on_or_before,
      :on_or_after,
      :between,
      :is_empty,
      :is_not_empty
    ]

  def operators(:enum), do: [:equals, :not_equals, :in, :not_in, :is_empty, :is_not_empty]

  def operators(:array),
    do: [:contains_any, :contains_all, :not_contains_any, :is_empty, :is_not_empty]

  def operators(_), do: [:equals, :not_equals]

  def ui_component(:string), do: :text_input
  def ui_component(:integer), do: :number_input
  def ui_component(:float), do: :number_input
  def ui_component(:boolean), do: :checkbox
  def ui_component(:date), do: :date_picker
  def ui_component(:enum), do: :select
  def ui_component(:array), do: :multi_select
  def ui_component(_), do: :text_input
end
