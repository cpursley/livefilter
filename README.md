# LiveFilter

A flexible and composable filtering library for Phoenix LiveView applications, inspired by Linear, Notion and Airtable. Provides filtering, sorting, and pagination with clean URL state management and a modern UI built on [SaladUI](https://salad-storybook.fly.dev/) and inspired by [shadcn/ui data tables](https://tablecn.com/).

[![Hex.pm](https://img.shields.io/hexpm/v/livefilter.svg)](https://hex.pm/packages/livefilter)
[![Documentation](https://img.shields.io/badge/documentation-hexdocs-blue.svg)](https://hexdocs.pm/livefilter)

**Demo**: [https://livefilter.fly.dev](https://livefilter.fly.dev/) - source: [https://github.com/cpursley/livefilter-demo](https://github.com/cpursley/livefilter-demo)

## Features

- Filter operators for all data types (string, numeric, boolean, date, enum, array)
- URL state management with shareable filter links
- Autogeneration of database-efficient queries
- Sorting and column management
- Components built on shadcn-inspired [SaladUI](https://salad-storybook.fly.dev/)

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:livefilter, "~> 0.1.4"}
  ]
end
```

Install JavaScript assets:

```bash
mix live_filter.install.assets
```

Add to your `app.js`:

```javascript
import LiveFilter from "./hooks/live_filter/live_filter"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { LiveFilter }
})
```

## Basic Usage

### 1. Minimal Setup

```elixir
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view
  alias LiveFilter.{Filter, FilterGroup, QueryBuilder}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :products, load_products())}
  end

  defp load_products(filter_group \\ %FilterGroup{}) do
    from(p in Product)
    |> QueryBuilder.build_query(filter_group)
    |> Repo.all()
  end
end
```

### 2. URL-Persisted Filters

```elixir
defmodule MyAppWeb.ProductLive do
  use MyAppWeb, :live_view
  use LiveFilter.Mountable  # Adds filter helpers

  def mount(_params, _session, socket) do
    socket = mount_filters(socket)
    {:ok, assign(socket, :products, [])}
  end

  def handle_params(params, _url, socket) do
    socket = handle_filter_params(socket, params)
    {:noreply, assign(socket, :products, load_products(socket.assigns.filter_group))}
  end

  defp load_products(filter_group) do
    from(p in Product)
    |> QueryBuilder.build_query(filter_group)
    |> Repo.all()
  end
end
```

## Advanced Example

Here's a complete implementation with UI components (similar to our [demo app](https://livefilter.fly.dev/)):

```elixir
defmodule MyAppWeb.TodoLive do
  use MyAppWeb, :live_view
  use LiveFilter.Mountable

  def mount(_params, _session, socket) do
    socket = 
      socket
      |> mount_filters(registry: field_registry())
      |> assign(:todos, [])
    
    {:ok, socket}
  end

  def handle_params(params, _url, socket) do
    socket = handle_filter_params(socket, params)
    {:noreply, assign(socket, :todos, load_todos(socket.assigns.filter_group))}
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Search and quick filters -->
      <div class="flex gap-4">
        <form phx-change="search" class="flex-1">
          <input name="q" value={@search} placeholder="Search todos..." />
        </form>
        
        <.live_component 
          module={LiveFilter.Components.SearchSelect}
          id="status-filter"
          field={:status}
          value={get_filter_value(@filter_group, :status)}
          options={[
            {"pending", "Pending"},
            {"in_progress", "In Progress"}, 
            {"completed", "Completed"}
          ]}
        />
      </div>

      <!-- Advanced filter builder -->
      <.live_component
        module={LiveFilter.Components.FilterBuilder}
        id="filter-builder"
        filter_group={@filter_group}
        field_options={field_options()}
      />

      <!-- Results table -->
      <table>
        <thead>
          <tr>
            <.live_component 
              module={LiveFilter.Components.SortableHeader}
              id="sort-title"
              field={:title}
              label="Title"
              current_sort={@current_sort}
            />
            <th>Status</th>
            <th>Due Date</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={todo <- @todos}>
            <td><%= todo.title %></td>
            <td><%= todo.status %></td>
            <td><%= todo.due_date %></td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  def handle_event("search", %{"q" => query}, socket) do
    filter = %Filter{field: :title, operator: :contains, value: query, type: :string}
    filter_group = %FilterGroup{filters: [filter]}
    socket = apply_filters_and_reload(socket, filter_group)
    {:noreply, assign(socket, :search, query)}
  end

  defp field_registry do
    LiveFilter.FieldRegistry.new()
    |> LiveFilter.FieldRegistry.put(:title, :string, "Title")
    |> LiveFilter.FieldRegistry.put(:status, :enum, "Status", 
         options: [{"pending", "Pending"}, {"in_progress", "In Progress"}, {"completed", "Completed"}])
    |> LiveFilter.FieldRegistry.put(:due_date, :date, "Due Date")
    |> LiveFilter.FieldRegistry.put(:tags, :array, "Tags")
  end

  defp load_todos(filter_group) do
    from(t in Todo)
    |> QueryBuilder.build_query(filter_group)
    |> QueryBuilder.apply_sort(socket.assigns.current_sort)
    |> Repo.all()
  end
end
```

## Documentation

- [API Documentation](https://hexdocs.pm/livefilter)
- [Demo Application](https://github.com/cpursley/livefilter-demo)

## License

MIT