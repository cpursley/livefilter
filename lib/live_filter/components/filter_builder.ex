defmodule LiveFilter.Components.FilterBuilder do
  @moduledoc """
  A component for building complex filter queries with a UI.

  Accepts:
  - filter_group: The FilterGroup struct
  - field_options: List of {field, label, type, opts} tuples
  - field_value_options: Map of field => options list for enum/array fields
  - ui_components: Optional UI component configuration
  """
  use Phoenix.LiveComponent
  alias LiveFilter.{FilterGroup, Filter}

  @impl true
  def render(assigns) do
    ~H"""
    <form phx-submit="apply_filters" phx-target={@myself} class="space-y-4">
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-semibold">Filters</h3>
        <div class="flex gap-2">
          <button
            phx-click="add_filter"
            phx-target={@myself}
            class="px-3 py-1 text-sm border border-gray-300 rounded hover:bg-gray-50"
            type="button"
          >
            + Add Filter
          </button>
          <%= if FilterGroup.has_filters?(@filter_group) do %>
            <button
              phx-click="clear_filters"
              phx-target={@myself}
              class="px-3 py-1 text-sm text-gray-600 hover:text-gray-900"
              type="button"
            >
              Clear All
            </button>
          <% end %>
        </div>
      </div>

      <div class="space-y-2">
        <%= for {filter, index} <- Enum.with_index(@filter_group.filters) do %>
          <.live_component
            module={LiveFilter.Components.FilterItem}
            id={"filter-#{index}"}
            filter={filter}
            index={index}
            field_options={@field_options}
            field_value_options={Map.get(assigns, :field_value_options, %{})}
          />
        <% end %>
      </div>

      <%= if FilterGroup.has_filters?(@filter_group) do %>
        <div class="flex justify-end">
          <button type="submit" class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">
            Apply Filters
          </button>
        </div>
      <% end %>
    </form>
    """
  end

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Ensure field_value_options has a default
    assigns = Map.put_new(assigns, :field_value_options, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:filter_group, fn -> %FilterGroup{} end)}
  end

  @impl true
  def handle_event("add_filter", _params, socket) do
    {field, _label, type, _opts} = List.first(socket.assigns.field_options)
    operators = LiveFilter.FilterTypes.operators_for_type(type)
    operator = List.first(operators)

    filter = %Filter{
      field: field,
      operator: operator,
      type: type,
      value: nil
    }

    updated_group = FilterGroup.add_filter(socket.assigns.filter_group, filter)

    send(self(), {:filter_group_updated, updated_group})
    {:noreply, assign(socket, :filter_group, updated_group)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    updated_group = %FilterGroup{}
    send(self(), {:filter_group_updated, updated_group})
    {:noreply, assign(socket, :filter_group, updated_group)}
  end

  @impl true
  def handle_event("apply_filters", _params, socket) do
    send(self(), {:apply_filters, socket.assigns.filter_group})
    {:noreply, socket}
  end

  # Note: LiveComponents don't have handle_info, these messages will be sent to the parent LiveView
  # The parent LiveView should handle {:filter_updated, index, filter} and {:filter_removed, index}
end
