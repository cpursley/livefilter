defmodule LiveFilter.FilterFactory do
  @moduledoc """
  Factory functions for creating LiveFilter test data.
  """

  alias LiveFilter.{Filter, FilterGroup, Sort}

  @doc """
  Creates common filter configurations for testing.
  """
  def filter_configs do
    %{
      # String filters
      title_contains: %Filter{
        field: :title,
        operator: :contains,
        value: "bug",
        type: :string
      },
      title_starts_with: %Filter{
        field: :title,
        operator: :starts_with,
        value: "Fix",
        type: :string
      },
      title_equals: %Filter{
        field: :title,
        operator: :equals,
        value: "Exact title match",
        type: :string
      },

      # Enum filters
      status_pending: %Filter{
        field: :status,
        operator: :equals,
        value: :pending,
        type: :enum
      },
      status_multiple: %Filter{
        field: :status,
        operator: :in,
        value: [:pending, :in_progress],
        type: :enum
      },

      # Boolean filters
      is_urgent: %Filter{
        field: :is_urgent,
        operator: :is_true,
        value: true,
        type: :boolean
      },
      not_urgent: %Filter{
        field: :is_urgent,
        operator: :is_false,
        value: false,
        type: :boolean
      },

      # Date filters
      due_today: %Filter{
        field: :due_date,
        operator: :equals,
        value: Date.utc_today(),
        type: :date
      },
      due_this_week: %Filter{
        field: :due_date,
        operator: :between,
        value: {Date.utc_today(), Date.add(Date.utc_today(), 7)},
        type: :date
      },
      overdue: %Filter{
        field: :due_date,
        operator: :before,
        value: Date.utc_today(),
        type: :date
      },

      # Numeric filters
      high_complexity: %Filter{
        field: :complexity,
        operator: :greater_than,
        value: 7,
        type: :integer
      },
      estimated_hours_range: %Filter{
        field: :estimated_hours,
        operator: :between,
        value: {10.0, 40.0},
        type: :float
      },

      # Array filters
      has_tags: %Filter{
        field: :tags,
        operator: :contains_any,
        value: ["bug", "urgent"],
        type: :array
      },

      # Special search filter
      search: %Filter{
        field: :_search,
        operator: :custom,
        value: "authentication",
        type: :string
      }
    }
  end

  @doc """
  Creates predefined filter groups for common scenarios.
  """
  def filter_groups do
    %{
      # Simple single filter
      pending_only: %FilterGroup{
        filters: [filter_configs().status_pending]
      },

      # Multiple filters with AND
      urgent_pending: %FilterGroup{
        filters: [
          filter_configs().status_pending,
          filter_configs().is_urgent
        ],
        conjunction: :and
      },

      # OR condition
      pending_or_in_progress: %FilterGroup{
        filters: [filter_configs().status_multiple],
        conjunction: :and
      },

      # Complex nested groups
      complex_query: %FilterGroup{
        filters: [filter_configs().is_urgent],
        groups: [
          %FilterGroup{
            filters: [
              filter_configs().status_pending,
              filter_configs().overdue
            ],
            conjunction: :and
          }
        ],
        conjunction: :and
      },

      # Empty filter group
      empty: %FilterGroup{
        filters: [],
        groups: [],
        conjunction: :and
      }
    }
  end

  @doc """
  Creates sort configurations.
  """
  def sort_configs do
    %{
      due_date_asc: %Sort{field: :due_date, direction: :asc},
      due_date_desc: %Sort{field: :due_date, direction: :desc},
      title_asc: %Sort{field: :title, direction: :asc},
      created_at_desc: %Sort{field: :inserted_at, direction: :desc},
      priority_desc: %Sort{field: :priority, direction: :desc}
    }
  end

  @doc """
  Creates URL parameter maps for testing serialization.
  """
  def url_params do
    %{
      # Simple filter
      simple: %{
        "filters[status][operator]" => "equals",
        "filters[status][type]" => "enum",
        "filters[status][value]" => "pending"
      },

      # Multiple filters
      multiple: %{
        "filters[status][operator]" => "in",
        "filters[status][type]" => "enum",
        "filters[status][values][]" => ["pending", "in_progress"],
        "filters[is_urgent][operator]" => "equals",
        "filters[is_urgent][type]" => "boolean",
        "filters[is_urgent][value]" => "true"
      },

      # With sorting
      with_sort: %{
        "filters[status][operator]" => "equals",
        "filters[status][type]" => "enum",
        "filters[status][value]" => "pending",
        "sort[field]" => "due_date",
        "sort[direction]" => "desc"
      },

      # With pagination
      with_pagination: %{
        "page" => "2",
        "per_page" => "20"
      },

      # Date range
      date_range: %{
        "filters[due_date][operator]" => "between",
        "filters[due_date][type]" => "date",
        "filters[due_date][start]" => "2025-01-01",
        "filters[due_date][end]" => "2025-01-31"
      },

      # Search query
      search: %{
        "filters[_search][operator]" => "custom",
        "filters[_search][type]" => "string",
        "filters[_search][value]" => "bug fix"
      },

      # Invalid/malformed params for edge case testing
      invalid: %{
        "filters[status][operator]" => "invalid_op",
        "filters[status][value]" => "",
        "sort[field]" => "nonexistent_field",
        "page" => "-1"
      }
    }
  end

  @doc """
  Creates a filter group from a keyword list for convenience.
  """
  def build_filter_group(filters) when is_list(filters) do
    filter_structs =
      Enum.map(filters, fn
        {field, value} -> build_filter(field, value)
      end)

    %FilterGroup{filters: filter_structs}
  end

  @doc """
  Builds a filter with sensible defaults based on field and value.
  """
  def build_filter(field, value) do
    {operator, type} = infer_operator_and_type(field, value)

    %Filter{
      field: field,
      operator: operator,
      value: value,
      type: type
    }
  end

  # Private functions

  defp infer_operator_and_type(:status, value) when is_list(value), do: {:in, :enum}
  defp infer_operator_and_type(:status, _value), do: {:equals, :enum}
  defp infer_operator_and_type(:assigned_to, value) when is_list(value), do: {:in, :enum}
  defp infer_operator_and_type(:assigned_to, _value), do: {:equals, :enum}
  defp infer_operator_and_type(:project, _value), do: {:equals, :enum}
  defp infer_operator_and_type(:priority, _value), do: {:equals, :enum}

  defp infer_operator_and_type(:is_urgent, true), do: {:is_true, :boolean}
  defp infer_operator_and_type(:is_urgent, false), do: {:is_false, :boolean}
  defp infer_operator_and_type(:is_recurring, true), do: {:is_true, :boolean}
  defp infer_operator_and_type(:is_recurring, false), do: {:is_false, :boolean}

  defp infer_operator_and_type(:due_date, {_start, _end}), do: {:between, :date}
  defp infer_operator_and_type(:due_date, _value), do: {:equals, :date}
  defp infer_operator_and_type(:completed_at, {_start, _end}), do: {:between, :datetime}
  defp infer_operator_and_type(:completed_at, _value), do: {:equals, :datetime}

  defp infer_operator_and_type(:tags, _value), do: {:contains_any, :array}

  defp infer_operator_and_type(:complexity, _value), do: {:equals, :integer}
  defp infer_operator_and_type(:estimated_hours, {_min, _max}), do: {:between, :float}
  defp infer_operator_and_type(:estimated_hours, _value), do: {:equals, :float}
  defp infer_operator_and_type(:actual_hours, _value), do: {:equals, :float}

  defp infer_operator_and_type(:title, _value), do: {:contains, :string}
  defp infer_operator_and_type(:description, _value), do: {:contains, :string}
  defp infer_operator_and_type(:_search, _value), do: {:custom, :string}

  defp infer_operator_and_type(_field, _value), do: {:equals, :string}
end
