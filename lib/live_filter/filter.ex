defmodule LiveFilter.Filter do
  @moduledoc """
  Represents an individual filter with field, operator, value, and type.

  A Filter defines a single filtering condition that can be applied to data queries.
  Filters are typically collected into FilterGroups for complex filtering logic.

  ## Fields

    * `:field` - The field name to filter on (atom, e.g., `:title`, `:status`)
    * `:operator` - The comparison operator (atom, e.g., `:equals`, `:contains`, `:greater_than`)
    * `:value` - The value to compare against (any type, depends on operator and field type)
    * `:type` - The field type for proper value handling (atom, e.g., `:string`, `:integer`, `:date`)

  ## Examples

      # String contains filter
      %Filter{
        field: :title,
        operator: :contains,
        value: "elixir",
        type: :string
      }
      
      # Integer comparison filter
      %Filter{
        field: :price,
        operator: :greater_than,
        value: 100,
        type: :integer
      }
      
      # Date range filter
      %Filter{
        field: :created_at,
        operator: :between,
        value: {~D[2024-01-01], ~D[2024-12-31]},
        type: :date
      }
      
      # Array membership filter
      %Filter{
        field: :tags,
        operator: :contains_any,
        value: ["urgent", "bug"],
        type: :array
      }
      
      # Boolean filter
      %Filter{
        field: :is_active,
        operator: :is_true,
        value: nil,  # Value ignored for boolean operators
        type: :boolean
      }

  ## Supported Operators by Type

  ### String Types (`:string`, `:text`)
  - `:equals`, `:not_equals` - Exact matching
  - `:contains`, `:not_contains` - Substring search
  - `:starts_with`, `:ends_with` - Prefix/suffix matching
  - `:is_empty`, `:is_not_empty` - Null/empty checks

  ### Numeric Types (`:integer`, `:float`)
  - `:equals`, `:not_equals` - Exact comparison
  - `:greater_than`, `:less_than` - Numeric comparison
  - `:greater_than_or_equal`, `:less_than_or_equal` - Inclusive comparison
  - `:between` - Range comparison (value should be `{min, max}` tuple)

  ### Date/Time Types (`:date`, `:datetime`, `:utc_datetime`)
  - `:equals`, `:not_equals` - Exact date comparison
  - `:before`, `:after` - Date comparison
  - `:on_or_before`, `:on_or_after` - Inclusive date comparison
  - `:between` - Date range (value should be `{start_date, end_date}` tuple)

  ### Boolean Type (`:boolean`)
  - `:is_true`, `:is_false` - Boolean value checks
  - `:is_empty`, `:is_not_empty` - Null checks

  ### Array Types (`:array`, `:multi_select`)
  - `:contains_any` - Array overlap (PostgreSQL: `&&` operator)
  - `:contains_all` - Array contains (PostgreSQL: `@>` operator)
  - `:not_contains_any` - No array overlap
  - `:in`, `:not_in` - Membership checks

  ### Enum Types (`:enum`)
  - `:equals`, `:not_equals` - Exact matching
  - `:in`, `:not_in` - Multiple choice selection
  """

  defstruct [:field, :operator, :value, :type]

  @type t :: %__MODULE__{
          field: atom(),
          operator: atom(),
          value: any(),
          type: atom()
        }

  @doc """
  Creates a new filter struct.

  ## Parameters

    * `attrs` - A map or keyword list of filter attributes

  ## Examples

      iex> Filter.new(%{field: :title, operator: :contains, value: "test", type: :string})
      %Filter{field: :title, operator: :contains, value: "test", type: :string}
      
      iex> Filter.new(field: :status, operator: :equals, value: "active", type: :enum)
      %Filter{field: :status, operator: :equals, value: "active", type: :enum}
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs \\ %{}) do
    struct(__MODULE__, attrs)
  end
end

defmodule LiveFilter.FilterGroup do
  @moduledoc """
  Represents a group of filters with a conjunction (AND/OR) and can contain nested groups.
  """

  defstruct filters: [], groups: [], conjunction: :and

  @type t :: %__MODULE__{
          filters: [LiveFilter.Filter.t()],
          groups: [t()],
          conjunction: :and | :or
        }

  @doc """
  Creates a new filter group.

  ## Parameters

    * `attrs` - A map or keyword list of filter group attributes

  ## Examples

      iex> FilterGroup.new()
      %FilterGroup{filters: [], groups: [], conjunction: :and}
      
      iex> FilterGroup.new(%{conjunction: :or})
      %FilterGroup{filters: [], groups: [], conjunction: :or}
  """
  @spec new(map() | keyword()) :: t()
  def new(attrs \\ %{}) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Adds a filter to the group.

  ## Examples

      iex> group = %FilterGroup{}
      iex> filter = %Filter{field: :title, operator: :contains, value: "test", type: :string}
      iex> FilterGroup.add_filter(group, filter)
      %FilterGroup{filters: [%Filter{field: :title, operator: :contains, value: "test", type: :string}]}
  """
  @spec add_filter(t(), LiveFilter.Filter.t()) :: t()
  def add_filter(%__MODULE__{} = group, %LiveFilter.Filter{} = filter) do
    %{group | filters: group.filters ++ [filter]}
  end

  @doc """
  Removes a filter from the group by index.

  ## Examples

      iex> filter = %Filter{field: :title, operator: :contains, value: "test", type: :string}
      iex> group = %FilterGroup{filters: [filter]}
      iex> FilterGroup.remove_filter(group, 0)
      %FilterGroup{filters: []}
  """
  @spec remove_filter(t(), non_neg_integer()) :: t()
  def remove_filter(%__MODULE__{} = group, index) when is_integer(index) do
    %{group | filters: List.delete_at(group.filters, index)}
  end

  @doc """
  Updates a filter in the group by index.

  ## Examples

      iex> old_filter = %Filter{field: :title, operator: :contains, value: "test", type: :string}
      iex> new_filter = %Filter{field: :title, operator: :equals, value: "exact", type: :string}
      iex> group = %FilterGroup{filters: [old_filter]}
      iex> FilterGroup.update_filter(group, 0, new_filter)
      %FilterGroup{filters: [%Filter{field: :title, operator: :equals, value: "exact", type: :string}]}
  """
  @spec update_filter(t(), non_neg_integer(), LiveFilter.Filter.t()) :: t()
  def update_filter(%__MODULE__{} = group, index, %LiveFilter.Filter{} = filter)
      when is_integer(index) do
    %{group | filters: List.replace_at(group.filters, index, filter)}
  end

  @doc """
  Adds a nested group.

  ## Examples

      iex> parent = %FilterGroup{conjunction: :and}
      iex> child = %FilterGroup{conjunction: :or, filters: [%Filter{field: :status, operator: :equals, value: "active", type: :enum}]}
      iex> FilterGroup.add_group(parent, child)
      %FilterGroup{conjunction: :and, groups: [%FilterGroup{conjunction: :or, filters: [...]}]}
  """
  @spec add_group(t(), t()) :: t()
  def add_group(%__MODULE__{} = group, %__MODULE__{} = nested_group) do
    %{group | groups: group.groups ++ [nested_group]}
  end

  @doc """
  Checks if the group has any active filters.

  Recursively checks nested groups for filters.

  ## Examples

      iex> FilterGroup.has_filters?(%FilterGroup{})
      false
      
      iex> filter = %Filter{field: :title, operator: :contains, value: "test", type: :string}
      iex> FilterGroup.has_filters?(%FilterGroup{filters: [filter]})
      true
  """
  @spec has_filters?(t()) :: boolean()
  def has_filters?(%__MODULE__{} = group) do
    Enum.any?(group.filters) || Enum.any?(group.groups, &has_filters?/1)
  end

  @doc """
  Counts total filters including nested groups.

  ## Examples

      iex> FilterGroup.count_filters(%FilterGroup{})
      0
      
      iex> filter = %Filter{field: :title, operator: :contains, value: "test", type: :string}
      iex> FilterGroup.count_filters(%FilterGroup{filters: [filter]})
      1
  """
  @spec count_filters(t()) :: non_neg_integer()
  def count_filters(%__MODULE__{} = group) do
    filter_count = length(group.filters)
    nested_count = Enum.sum(Enum.map(group.groups, &count_filters/1))
    filter_count + nested_count
  end
end
