defmodule LiveFilter.Components.FilterSelector do
  @moduledoc """
  A dropdown component for selecting filters to add to the active filter set.

  This component provides a clean UI for adding optional filters without taking up
  toolbar space for filters that aren't actively in use.

  ## Features
  - Shows only inactive filters in the dropdown
  - Supports custom icons for each filter
  - Sends standardized events when filters are selected
  - Fully optional - can be used alongside or instead of FilterBuilder

  ## Usage

      <.live_component
        module={LiveFilter.Components.FilterSelector}
        id="add-filter"
        available_filters={[
          {:description, "Description", "hero-document-text"},
          {:tags, "Tags", "hero-tag"},
          {:estimated_hours, "Est. Hours", "hero-clock"}
        ]}
        active_filters={[:tags]}
        label="Add Filter"
        class="my-custom-class"
      />

  When a filter is selected, it sends a message to the parent LiveView:

      {:filter_selected, filter_field}
  """
  use Phoenix.LiveComponent
  import SaladUI.Button
  import SaladUI.Icon
  import SaladUI.DropdownMenu

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Set defaults
    assigns =
      Map.merge(
        %{
          available_filters: [],
          active_filters: [],
          label: "Add Filter",
          icon: "hero-plus",
          size: "sm",
          variant: "ghost",
          class: nil
        },
        assigns
      )

    # Calculate which filters are available to add (not currently active)
    inactive_filters =
      Enum.reject(assigns.available_filters, fn filter ->
        field =
          case filter do
            {field, _label, _type, _opts} -> field
            {field, _label, _type} -> field
            _ -> nil
          end

        field in assigns.active_filters
      end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:inactive_filters, inactive_filters)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id}>
      <%= if @inactive_filters != [] do %>
        <.dropdown_menu id={"#{@id}-dropdown"}>
          <.dropdown_menu_trigger>
            <.button variant={@variant} size={@size} class={@class}>
              <.icon name={@icon} class="mr-2 h-4 w-4" />
              {@label}
            </.button>
          </.dropdown_menu_trigger>

          <.dropdown_menu_content align="start" class="w-[200px]">
            <.dropdown_menu_label>Available Filters</.dropdown_menu_label>
            <.dropdown_menu_separator />

            <.dropdown_menu_item
              :for={filter <- @inactive_filters}
              on-select={
                Phoenix.LiveView.JS.push("select_filter",
                  value: %{field: to_string(elem(filter, 0))},
                  target: @myself
                )
              }
            >
              <.icon
                :if={get_filter_icon(filter)}
                name={get_filter_icon(filter)}
                class="mr-2 h-4 w-4"
              />
              {get_filter_label(filter)}
            </.dropdown_menu_item>
          </.dropdown_menu_content>
        </.dropdown_menu>
      <% else %>
        <.button variant={@variant} size={@size} class={@class} disabled={true}>
          <.icon name={@icon} class="mr-2 h-4 w-4" />
          {@label}
        </.button>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("select_filter", %{"field" => field_string}, socket) do
    field = String.to_existing_atom(field_string)
    # Send to parent LiveView, not to self (the LiveComponent)
    send(self(), {:filter_selected, field})
    {:noreply, socket}
  end

  # Helper functions
  defp get_filter_label(filter) do
    case filter do
      {_field, label, _type, _opts} -> label
      {_field, label, _type} -> label
      _ -> "Unknown"
    end
  end

  defp get_filter_icon(filter) do
    case filter do
      {_field, _label, _type, %{icon: icon}} -> icon
      _ -> nil
    end
  end
end
