defmodule LiveFilter.QueryBuilderTest do
  use ExUnit.Case, async: true
  import Ecto.Query

  alias LiveFilter.{Filter, FilterGroup, QueryBuilder, Sort}

  # Simple test schema for query building tests
  defmodule TestSchema do
    use Ecto.Schema

    schema "test_items" do
      field(:title, :string)
      field(:status, Ecto.Enum, values: [:pending, :active, :completed])
      field(:tags, {:array, :string})
      field(:priority, :integer)
      field(:due_date, :date)
      field(:is_urgent, :boolean)
      field(:created_at, :utc_datetime)
    end
  end

  setup do
    # Set up base query for testing
    base_query = from(t in TestSchema)
    %{base_query: base_query}
  end

  describe "build_query/2" do
    test "returns original query when filter group has no filters", %{base_query: base_query} do
      filter_group = %FilterGroup{filters: []}
      result = QueryBuilder.build_query(base_query, filter_group)
      assert result == base_query
    end

    test "adds where clause for single filter", %{base_query: base_query} do
      filter = %Filter{
        field: :title,
        operator: :equals,
        value: "test",
        type: :string
      }

      filter_group = %FilterGroup{filters: [filter]}

      result = QueryBuilder.build_query(base_query, filter_group)

      # Verify a where clause was added
      assert %Ecto.Query{wheres: [_where_clause]} = result
    end

    test "handles multiple filters with AND conjunction", %{base_query: base_query} do
      filters = [
        %Filter{field: :title, operator: :contains, value: "test", type: :string},
        %Filter{field: :status, operator: :equals, value: "pending", type: :enum}
      ]

      filter_group = %FilterGroup{filters: filters, conjunction: :and}

      result = QueryBuilder.build_query(base_query, filter_group)

      # Verify where clause was added
      assert %Ecto.Query{wheres: [_where_clause]} = result
    end
  end

  describe "apply_sort/2" do
    test "returns original query when sorts is nil", %{base_query: base_query} do
      result = QueryBuilder.apply_sort(base_query, nil)
      assert result == base_query
    end

    test "returns original query when sorts is empty list", %{base_query: base_query} do
      result = QueryBuilder.apply_sort(base_query, [])
      assert result == base_query
    end

    test "adds order_by clause for single sort", %{base_query: base_query} do
      sort = %Sort{field: :title, direction: :asc}
      result = QueryBuilder.apply_sort(base_query, sort)

      # Verify order_by clause was added
      assert %Ecto.Query{order_bys: [order_by]} = result
      assert order_by.expr == [asc: {{:., [], [{:&, [], [0]}, :title]}, [], []}]
    end

    test "adds order_by clause for multiple sorts", %{base_query: base_query} do
      sorts = [
        %Sort{field: :priority, direction: :desc},
        %Sort{field: :title, direction: :asc}
      ]

      result = QueryBuilder.apply_sort(base_query, sorts)

      # Verify order_by clauses were added
      assert %Ecto.Query{order_bys: order_bys} = result
      assert length(order_bys) == 2
    end
  end
end
