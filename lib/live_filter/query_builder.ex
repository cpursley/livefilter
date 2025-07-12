defmodule LiveFilter.QueryBuilder do
  @moduledoc """
  Converts filter configurations to Ecto queries using dynamic query building.

  This module is the core of LiveFilter's database integration. It takes FilterGroup
  and Sort structures and converts them into efficient Ecto queries that can be 
  executed against your database.

  ## Features

  - **Dynamic Query Building**: Uses Ecto.Query.dynamic/2 for efficient query composition
  - **20+ Operators**: Supports comprehensive filtering operations for all data types
  - **Nested Logic**: Handles complex AND/OR combinations with FilterGroups
  - **PostgreSQL Arrays**: Special support for array operations (contains_any, contains_all)
  - **Null Handling**: Proper handling of nil values and empty checks
  - **Multi-column Sorting**: Supports single and multiple sort columns

  ## Database Compatibility

  - **PostgreSQL**: Full support including array operations
  - **MySQL**: Supports all operators except array operations
  - **SQLite**: Supports all operators except array operations

  ## Performance Notes

  This module generates efficient SQL queries with proper WHERE clauses. For best
  performance, ensure your database has appropriate indexes on filtered fields.

  ## Examples

      # Simple filter
      query = from p in Product
      filter_group = %FilterGroup{
        filters: [
          %Filter{field: :name, operator: :contains, value: "phone", type: :string}
        ]
      }
      QueryBuilder.build_query(query, filter_group)
      
      # Complex nested filters with sorting
      filter_group = %FilterGroup{
        filters: [
          %Filter{field: :status, operator: :equals, value: "active", type: :enum}
        ],
        groups: [
          %FilterGroup{
            filters: [
              %Filter{field: :price, operator: :greater_than, value: 100, type: :integer},
              %Filter{field: :category, operator: :in, value: ["electronics", "gadgets"], type: :array}
            ],
            conjunction: :or
          }
        ],
        conjunction: :and
      }
      
      sorts = [
        %Sort{field: :priority, direction: :desc},
        %Sort{field: :created_at, direction: :asc}
      ]
      
      query
      |> QueryBuilder.build_query(filter_group)
      |> QueryBuilder.apply_sort(sorts)
  """

  import Ecto.Query
  alias LiveFilter.Sort

  @doc """
  Builds an Ecto query from a filter group.

  Converts a FilterGroup into dynamic Ecto query conditions using Ecto.Query.dynamic/2.
  Returns the original query unchanged if no filters are present.

  ## Parameters

    * `query` - The base Ecto query to add conditions to
    * `filter_group` - A FilterGroup struct containing filters and nested groups

  ## Returns

  The query with WHERE conditions applied, or the original query if no filters.

  ## Examples

      iex> query = from p in Product
      iex> filter_group = %FilterGroup{
      ...>   filters: [
      ...>     %Filter{field: :name, operator: :contains, value: "phone", type: :string}
      ...>   ]
      ...> }
      iex> QueryBuilder.build_query(query, filter_group)
      #Ecto.Query<from p0 in Product, where: ilike(p0.name, "%phone%")>
      
      iex> empty_group = %FilterGroup{filters: []}
      iex> QueryBuilder.build_query(query, empty_group) == query
      true
  """
  @spec build_query(Ecto.Query.t(), LiveFilter.FilterGroup.t()) :: Ecto.Query.t()
  def build_query(query, %LiveFilter.FilterGroup{} = filter_group) do
    dynamic = build_dynamic(filter_group)

    if dynamic do
      where(query, ^dynamic)
    else
      query
    end
  end

  @doc """
  Applies sorting to a query.

  Accepts a single Sort struct, a list of Sort structs, or nil. When multiple
  sorts are provided, they are applied in order, creating a multi-column sort.

  ## Parameters

    * `query` - The Ecto query to add sorting to
    * `sorts` - A Sort struct, list of Sort structs, or nil

  ## Returns

  The query with ORDER BY clauses applied, or the original query if no sorts.

  ## Examples

      # Single sort
      apply_sort(query, %Sort{field: :due_date, direction: :asc})
      
      # Multiple sorts (applied in order - priority desc, then due_date asc)
      apply_sort(query, [
        %Sort{field: :priority, direction: :desc},
        %Sort{field: :due_date, direction: :asc}
      ])
      
      # No sorting
      apply_sort(query, nil)  # Returns original query unchanged
  """
  @spec apply_sort(Ecto.Query.t(), Sort.t() | [Sort.t()] | nil) :: Ecto.Query.t()
  def apply_sort(query, nil), do: query
  def apply_sort(query, []), do: query

  def apply_sort(query, %Sort{} = sort) do
    apply_sort(query, [sort])
  end

  def apply_sort(query, sorts) when is_list(sorts) do
    Enum.reduce(sorts, query, fn %Sort{field: field, direction: direction}, acc ->
      order_by(acc, [t], [{^direction, field(t, ^field)}])
    end)
  end

  defp build_dynamic(%LiveFilter.FilterGroup{
         filters: filters,
         groups: groups,
         conjunction: conjunction
       }) do
    filter_dynamics = Enum.map(filters, &build_filter_dynamic/1)
    group_dynamics = Enum.map(groups, &build_dynamic/1)

    all_dynamics = (filter_dynamics ++ group_dynamics) |> Enum.reject(&is_nil/1)

    case all_dynamics do
      [] ->
        nil

      [single] ->
        single

      multiple ->
        combine_dynamics(multiple, conjunction)
    end
  end

  defp build_filter_dynamic(%LiveFilter.Filter{
         field: field,
         operator: operator,
         value: value,
         type: type
       }) do
    # Skip filters with nil values unless the operator specifically handles nil
    if value == nil and operator not in [:is_empty, :is_not_empty] do
      nil
    else
      build_operator_dynamic(operator, field, value, type)
    end
  end

  defp build_operator_dynamic(operator, field, value, type) do
    case operator do
      :equals ->
        if value == nil do
          dynamic([t], is_nil(field(t, ^field)))
        else
          dynamic([t], field(t, ^field) == ^value)
        end

      :not_equals ->
        if value == nil do
          dynamic([t], not is_nil(field(t, ^field)))
        else
          dynamic([t], field(t, ^field) != ^value)
        end

      :contains ->
        pattern = "%#{value}%"
        dynamic([t], ilike(field(t, ^field), ^pattern))

      :not_contains ->
        pattern = "%#{value}%"
        dynamic([t], not ilike(field(t, ^field), ^pattern))

      :starts_with ->
        pattern = "#{value}%"
        dynamic([t], ilike(field(t, ^field), ^pattern))

      :ends_with ->
        pattern = "%#{value}"
        dynamic([t], ilike(field(t, ^field), ^pattern))

      :is_empty ->
        case type do
          t when t in [:string, :text] ->
            dynamic([t], is_nil(field(t, ^field)) or field(t, ^field) == "")

          t when t in [:array, :multi_select] ->
            dynamic([t], is_nil(field(t, ^field)) or field(t, ^field) == [])

          _ ->
            dynamic([t], is_nil(field(t, ^field)))
        end

      :is_not_empty ->
        case type do
          t when t in [:string, :text] ->
            dynamic([t], not is_nil(field(t, ^field)) and field(t, ^field) != "")

          t when t in [:array, :multi_select] ->
            dynamic([t], not is_nil(field(t, ^field)) and field(t, ^field) != [])

          _ ->
            dynamic([t], not is_nil(field(t, ^field)))
        end

      :greater_than ->
        dynamic([t], field(t, ^field) > ^value)

      :less_than ->
        dynamic([t], field(t, ^field) < ^value)

      :greater_than_or_equal ->
        dynamic([t], field(t, ^field) >= ^value)

      :less_than_or_equal ->
        dynamic([t], field(t, ^field) <= ^value)

      :between ->
        case value do
          {min_val, max_val} ->
            dynamic([t], field(t, ^field) >= ^min_val and field(t, ^field) <= ^max_val)

          _ ->
            nil
        end

      :is_true ->
        dynamic([t], field(t, ^field) == true)

      :is_false ->
        dynamic([t], field(t, ^field) == false)

      :before ->
        dynamic([t], field(t, ^field) < ^value)

      :after ->
        dynamic([t], field(t, ^field) > ^value)

      :on_or_before ->
        dynamic([t], field(t, ^field) <= ^value)

      :on_or_after ->
        dynamic([t], field(t, ^field) >= ^value)

      :in ->
        dynamic([t], field(t, ^field) in ^value)

      :not_in ->
        dynamic([t], field(t, ^field) not in ^value)

      :contains_any ->
        # PostgreSQL array overlap operator
        dynamic([t], fragment("? && ?", field(t, ^field), ^value))

      :contains_all ->
        # PostgreSQL array contains operator
        dynamic([t], fragment("? @> ?", field(t, ^field), ^value))

      :not_contains_any ->
        dynamic([t], not fragment("? && ?", field(t, ^field), ^value))

      :matches ->
        pattern = "%#{value}%"
        dynamic([t], ilike(field(t, ^field), ^pattern))

      _ ->
        nil
    end
  end

  defp combine_dynamics(dynamics, :and) do
    Enum.reduce(dynamics, fn dynamic, acc ->
      dynamic([t], ^acc and ^dynamic)
    end)
  end

  defp combine_dynamics(dynamics, :or) do
    Enum.reduce(dynamics, fn dynamic, acc ->
      dynamic([t], ^acc or ^dynamic)
    end)
  end
end
