defmodule LiveFilter.Components.SortSelector do
  @moduledoc """
  A component for selecting and managing sort options.
  Can be used in toolbars or dialogs for single or multi-field sorting.

  ## Examples

      <.sort_selector
        id="sort-selector"
        current_sorts={@current_sorts}
        field_options={@field_options}
        target={@myself}
      />
  """
  use Phoenix.LiveComponent
  import SaladUI.Button
  import SaladUI.Icon
  import SaladUI.DropdownMenu
  alias LiveFilter.Sort
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_display_value()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.dropdown_menu id={@id}>
        <.dropdown_menu_trigger>
          <.button variant="outline" size="sm">
            <.icon name="hero-arrows-up-down" class="h-4 w-4 mr-2" />
            {@display_value}
          </.button>
        </.dropdown_menu_trigger>

        <.dropdown_menu_content align="start" class="w-[250px]">
          <.dropdown_menu_label>Sort by</.dropdown_menu_label>
          <.dropdown_menu_separator />

          <%= for {field, label} <- @field_options do %>
            <% sort = get_active_sort(@current_sorts, field) %>
            <.dropdown_menu_item on-select={
              JS.push("sort_by", value: %{field: field, direction: "asc"}, target: @myself)
            }>
              <div class="flex items-center justify-between w-full">
                <div class="flex items-center">
                  <.icon name="hero-chevron-up" class="h-4 w-4 mr-2 text-muted-foreground" />
                  <span>{label} (A-Z)</span>
                </div>
                <%= if sort && sort.direction == :asc do %>
                  <.icon name="hero-check" class="h-4 w-4" />
                <% end %>
              </div>
            </.dropdown_menu_item>

            <.dropdown_menu_item on-select={
              JS.push("sort_by", value: %{field: field, direction: "desc"}, target: @myself)
            }>
              <div class="flex items-center justify-between w-full">
                <div class="flex items-center">
                  <.icon name="hero-chevron-down" class="h-4 w-4 mr-2 text-muted-foreground" />
                  <span>{label} (Z-A)</span>
                </div>
                <%= if sort && sort.direction == :desc do %>
                  <.icon name="hero-check" class="h-4 w-4" />
                <% end %>
              </div>
            </.dropdown_menu_item>

            <%= if get_active_sort(@current_sorts, field) do %>
              <.dropdown_menu_separator />
            <% end %>
          <% end %>

          <%= if @current_sorts not in [nil, []] do %>
            <.dropdown_menu_separator />
            <.dropdown_menu_item on-select={JS.push("clear_sorts", target: @myself)}>
              <.icon name="hero-x-mark" class="h-4 w-4 mr-2" /> Clear sort
            </.dropdown_menu_item>
          <% end %>
        </.dropdown_menu_content>
      </.dropdown_menu>
    </div>
    """
  end

  @impl true
  def handle_event("sort_by", %{"field" => field, "direction" => direction}, socket) do
    field_atom = String.to_existing_atom(field)
    direction_atom = String.to_existing_atom(direction)

    new_sort = Sort.new(field_atom, direction_atom)

    # For now, single sort only - can be extended for multi-sort
    send(self(), {:sort_changed, new_sort})

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_sort", %{"field" => field}, socket) do
    field_atom = String.to_existing_atom(field)

    current_sorts = List.wrap(socket.assigns.current_sorts)
    new_sorts = Enum.reject(current_sorts, &(&1.field == field_atom))

    sort_value =
      case new_sorts do
        [] -> nil
        [single] -> single
        multiple -> multiple
      end

    send(self(), {:sort_changed, sort_value})

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_sorts", _, socket) do
    send(self(), {:sort_changed, nil})
    {:noreply, socket}
  end

  defp assign_display_value(socket) do
    display_value =
      case socket.assigns.current_sorts do
        nil ->
          "Sort"

        [] ->
          "Sort"

        %Sort{field: field} = sort ->
          label = get_field_label(socket.assigns.field_options, field)
          direction = if sort.direction == :asc, do: "↑", else: "↓"
          "#{label} #{direction}"

        sorts when is_list(sorts) ->
          count = length(sorts)
          "#{count} sorts"
      end

    assign(socket, :display_value, display_value)
  end

  defp get_active_sort(nil, _field), do: nil
  defp get_active_sort(%Sort{field: field} = sort, field), do: sort
  defp get_active_sort(%Sort{}, _field), do: nil

  defp get_active_sort(sorts, field) when is_list(sorts) do
    Enum.find(sorts, &(&1.field == field))
  end

  defp get_field_label(field_options, field) do
    case List.keyfind(field_options, field, 0) do
      {_, label} -> label
      nil -> Phoenix.Naming.humanize(field)
    end
  end
end
