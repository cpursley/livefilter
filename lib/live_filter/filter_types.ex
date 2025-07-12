defmodule LiveFilter.FilterTypes do
  @moduledoc """
  Defines available filter types and their operators.
  Maps field types to appropriate UI components.
  """

  @type_operators %{
    string: [
      :equals,
      :not_equals,
      :contains,
      :not_contains,
      :starts_with,
      :ends_with,
      :is_empty,
      :is_not_empty
    ],
    text: [
      :equals,
      :not_equals,
      :contains,
      :not_contains,
      :starts_with,
      :ends_with,
      :is_empty,
      :is_not_empty
    ],
    integer: [
      :equals,
      :not_equals,
      :greater_than,
      :less_than,
      :greater_than_or_equal,
      :less_than_or_equal,
      :between,
      :is_empty,
      :is_not_empty
    ],
    float: [
      :equals,
      :not_equals,
      :greater_than,
      :less_than,
      :greater_than_or_equal,
      :less_than_or_equal,
      :between,
      :is_empty,
      :is_not_empty
    ],
    boolean: [:is_true, :is_false],
    date: [
      :equals,
      :before,
      :after,
      :on_or_before,
      :on_or_after,
      :between,
      :is_empty,
      :is_not_empty
    ],
    datetime: [
      :equals,
      :before,
      :after,
      :on_or_before,
      :on_or_after,
      :between,
      :is_empty,
      :is_not_empty
    ],
    enum: [:equals, :not_equals, :in, :not_in, :is_empty, :is_not_empty],
    array: [:contains_any, :contains_all, :not_contains_any, :is_empty, :is_not_empty],
    multi_select: [:contains_any, :contains_all, :not_contains_any, :is_empty, :is_not_empty],
    text_search: [:matches],
    select_search: [:equals, :not_equals]
  }

  @operator_labels %{
    equals: "equals",
    not_equals: "does not equal",
    contains: "contains",
    not_contains: "does not contain",
    starts_with: "starts with",
    ends_with: "ends with",
    is_empty: "is empty",
    is_not_empty: "is not empty",
    greater_than: "greater than",
    less_than: "less than",
    greater_than_or_equal: "greater than or equal to",
    less_than_or_equal: "less than or equal to",
    between: "between",
    is_true: "is true",
    is_false: "is false",
    before: "before",
    after: "after",
    on_or_before: "on or before",
    on_or_after: "on or after",
    in: "in",
    not_in: "not in",
    contains_any: "contains any of",
    contains_all: "contains all of",
    not_contains_any: "does not contain any of",
    matches: "matches"
  }

  @doc """
  Returns available operators for a given field type.
  """
  def operators_for_type(type) when is_atom(type) do
    Map.get(@type_operators, type, [])
  end

  @doc """
  Returns human-readable label for an operator.
  """
  def operator_label(operator) when is_atom(operator) do
    Map.get(@operator_labels, operator, to_string(operator))
  end

  @doc """
  Determines if an operator requires a value input.
  """
  def operator_requires_value?(operator) when is_atom(operator) do
    operator not in [:is_empty, :is_not_empty, :is_true, :is_false]
  end

  @doc """
  Maps a type and operator combination to an appropriate input component.
  """
  def input_component_for(type, operator) do
    cond do
      operator in [:is_empty, :is_not_empty] -> nil
      operator == :between -> :range_input
      type == :boolean -> :boolean_filter
      type in [:date, :datetime] && operator == :between -> :date_range_selector
      type in [:date, :datetime] -> :date_selector
      type in [:enum, :select_search] && operator in [:in, :not_in] -> :multi_select_search
      type in [:enum, :select_search] -> :search_select
      type in [:array, :multi_select] -> :multi_select_search
      type == :text_search -> :search_input
      type in [:integer, :float] -> :number_input
      true -> :text_input
    end
  end

  @doc """
  Returns all available field types.
  """
  def field_types do
    Map.keys(@type_operators)
  end

  @doc """
  Validates if a given operator is valid for a field type.
  """
  def valid_operator?(type, operator) do
    operator in operators_for_type(type)
  end

  @doc """
  Returns preset date ranges for date filters.
  """
  def date_presets do
    [
      %{label: "Today", value: :today},
      %{label: "Yesterday", value: :yesterday},
      %{label: "Last 7 days", value: :last_7_days},
      %{label: "Last 30 days", value: :last_30_days},
      %{label: "This month", value: :this_month},
      %{label: "Last month", value: :last_month},
      %{label: "This year", value: :this_year},
      %{label: "Last year", value: :last_year}
    ]
  end
end
