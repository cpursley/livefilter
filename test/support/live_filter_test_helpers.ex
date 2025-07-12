defmodule LiveFilter.TestHelpers do
  @moduledoc """
  Helper functions for testing LiveFilter functionality.
  """

  import ExUnit.Assertions
  alias LiveFilter.{Filter, FilterGroup, Sort}

  @doc """
  Creates a filter group from a simplified format.

  ## Examples
      
      build_filter_group(status: :pending)
      build_filter_group(status: [:pending, :in_progress], assignee: "john_doe")
      build_filter_group(due_date: {~D[2025-01-01], ~D[2025-01-31]})
  """
  def build_filter_group(filters) when is_list(filters) do
    filter_structs =
      Enum.map(filters, fn {field, value} ->
        build_filter(field, value)
      end)

    %FilterGroup{filters: filter_structs}
  end

  @doc """
  Creates a filter based on field and value, inferring operator and type.
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

  @doc """
  Builds URL parameters from filter specifications.

  ## Examples

      build_url_params(status: :pending)
      # => %{"filters[status][operator]" => "equals", ...}
  """
  def build_url_params(filters) when is_list(filters) do
    filter_group = build_filter_group(filters)
    LiveFilter.UrlSerializer.update_params(%{}, filter_group)
  end

  @doc """
  Builds URL parameters with sorting.
  """
  def build_url_params(filters, sort_field, sort_direction \\ :asc) do
    filter_params = build_url_params(filters)
    sort = Sort.new(sort_field, sort_direction)

    LiveFilter.UrlSerializer.update_params(filter_params, build_filter_group(filters), sort)
  end

  @doc """
  Asserts that a filter is present in the URL.
  """
  def assert_filter_in_url(url, field, value) do
    uri = URI.parse(url)
    params = URI.decode_query(uri.query || "")

    field_str = to_string(field)
    value_str = to_string(value)

    assert params["filters[#{field_str}][value]"] == value_str ||
             value_str in (params["filters[#{field_str}][values]"] || []),
           "Expected filter #{field}=#{value} in URL"
  end

  @doc """
  Asserts that todos are displayed in the HTML.
  """
  def assert_todos_displayed(html, todos) when is_list(todos) do
    Enum.each(todos, fn todo ->
      assert html =~ todo.title
    end)
  end

  @doc """
  Asserts that todos are NOT displayed in the HTML.
  """
  def refute_todos_displayed(html, todos) when is_list(todos) do
    Enum.each(todos, fn todo ->
      refute html =~ todo.title
    end)
  end

  @doc """
  Creates a complex filter group with nested groups.
  """
  def build_complex_filter_group do
    %FilterGroup{
      filters: [
        build_filter(:status, :pending),
        build_filter(:is_urgent, true)
      ],
      groups: [
        %FilterGroup{
          filters: [
            build_filter(:assigned_to, "john_doe"),
            build_filter(:assigned_to, "jane_smith")
          ],
          conjunction: :or
        }
      ],
      conjunction: :and
    }
  end

  @doc """
  Simulates filter changes in a LiveView.
  """
  def apply_filter(view, field, value) do
    filter_params = build_filter_params(field, value)

    view
    |> Phoenix.LiveViewTest.element("#filter-#{field}")
    |> Phoenix.LiveViewTest.render_change(filter_params)
  end

  @doc """
  Gets the count of displayed todos from the HTML.
  """
  def get_todo_count(html) do
    case Regex.run(~r/(\d+) todos?/, html) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  # Private functions

  defp infer_operator_and_type(field, value) do
    cond do
      # Boolean fields
      field in [:is_urgent, :is_recurring] ->
        {:equals, :boolean}

      # Enum fields with list values
      field in [:status, :assigned_to, :project] && is_list(value) ->
        {:in, :enum}

      # Enum fields with single values
      field in [:status, :assigned_to, :project] ->
        {:equals, :enum}

      # Date range
      is_tuple(value) && tuple_size(value) == 2 ->
        {:between, :date}

      # Array fields
      field == :tags ->
        {:contains_any, :array}

      # Numeric fields
      field in [:estimated_hours, :actual_hours, :complexity] ->
        {:equals, :float}

      # String fields
      true ->
        {:contains, :string}
    end
  end

  defp build_filter_params(field, value) do
    case field do
      :search -> %{"search" => %{"query" => value}}
      :status -> %{"status" => %{"select" => to_string(value)}}
      :assigned_to -> %{"assignee" => %{"select" => value}}
      :due_date -> %{"due_date" => format_date_range(value)}
      :is_urgent -> %{"urgent" => %{"toggle" => value}}
      _ -> %{to_string(field) => %{"value" => value}}
    end
  end

  defp format_date_range({start_date, end_date}) do
    %{
      "start" => Date.to_string(start_date),
      "end" => Date.to_string(end_date)
    }
  end
end
