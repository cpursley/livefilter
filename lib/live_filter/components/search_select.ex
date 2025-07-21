defmodule LiveFilter.Components.SearchSelect do
  @moduledoc """
  A search-enabled select component with single and multi-select support.

  Features:
  - In-dropdown search filtering
  - Single or multi-select modes
  - Configurable display of selected values
  - Item count badges
  - Clear all functionality
  - Keyboard navigation
  """
  use Phoenix.Component
  import SaladUI.DropdownMenu
  import SaladUI.Button
  import SaladUI.Icon
  import SaladUI.Input
  import SaladUI.Separator
  import SaladUI.Badge

  alias Phoenix.LiveView.JS

  @doc """
  Renders a search-enabled select dropdown.

  ## Options Format

  Options should be a list of tuples: `[{value, label}, ...]` or `[{value, label, count}, ...]`

  ## Examples

      <.search_select
        id="status-filter"
        options={[
          {:pending, "Pending", 12},
          {:in_progress, "In Progress", 8},
          {:completed, "Completed", 45}
        ]}
        selected={[:pending, :in_progress]}
        on_change="update_status_filter"
      />
  """
  attr(:id, :string, required: true)
  attr(:options, :list, required: true)
  attr(:selected, :list, default: [])
  attr(:on_change, :any, required: true)
  attr(:multiple, :boolean, default: true)
  attr(:placeholder, :string, default: "Select...")
  attr(:display_count, :integer, default: 3)
  attr(:searchable, :boolean, default: true)
  attr(:clearable, :boolean, default: true)
  attr(:label, :string, default: nil)
  attr(:icon, :string, default: nil)
  attr(:class, :string, default: nil)
  attr(:size, :string, default: "sm", values: ~w(sm md lg))
  attr(:show_label_in_selection, :boolean, default: false)
  attr(:clear_icon, :string, default: "hero-x-circle")
  attr(:plus_icon, :string, default: "hero-plus-circle")

  def search_select(assigns) do
    search_id = "#{assigns.id}-search"
    assigns = assign(assigns, :search_id, search_id)

    ~H"""
    <div id={"#{@id}-wrapper"}>
      <.dropdown_menu id={@id} on-open={JS.focus(to: "##{@search_id}")}>
        <.dropdown_menu_trigger>
          <.button
            variant="outline"
            size={@size}
            class={[
              @class,
              "gap-1 items-center"
            ]}
            data-selected={inspect(@selected)}
            data-selected-count={length(@selected)}
          >
            <.icon :if={@icon} name={@icon} class="h-4 w-4" />
            {render_button_content(assigns)}
          </.button>
        </.dropdown_menu_trigger>

        <.dropdown_menu_content align="start" class="p-0">
          <div :if={@searchable} class="p-2 pb-0">
            <div class="relative">
              <.icon
                name="hero-magnifying-glass"
                class="absolute left-2 top-[10px] h-4 w-4 text-muted-foreground"
              />
              <.input
                id={@search_id}
                type="text"
                placeholder="Search..."
                class="h-8 pl-8"
                phx-keyup={JS.dispatch("livefilter:search", detail: %{id: @id})}
                phx-debounce="200"
              />
            </div>
          </div>

          <div class="max-h-[300px] overflow-auto p-2">
            <div id={"#{@id}-options"} phx-update="ignore">
              <%= for option <- @options do %>
                <div data-search-value={elem(option, 1) |> String.downcase()}>
                  <%= if @multiple do %>
                    <.dropdown_menu_checkbox_item
                      checked={elem(option, 0) in @selected}
                      on-checked-change={JS.push(@on_change, value: %{toggle: elem(option, 0)})}
                      class={"pr-2 " <> if(elem(option, 0) in @selected, do: "bg-muted", else: "")}
                    >
                      <span>{elem(option, 1)}</span>
                    </.dropdown_menu_checkbox_item>
                  <% else %>
                    <.dropdown_menu_item
                      on-select={JS.push(@on_change, value: %{select: elem(option, 0)})}
                      class={"pr-2 " <> if(elem(option, 0) in @selected, do: "bg-accent", else: "")}
                    >
                      <span>{elem(option, 1)}</span>
                    </.dropdown_menu_item>
                  <% end %>
                </div>
              <% end %>
            </div>

            <%= if @clearable && @selected != [] do %>
              <.dropdown_menu_separator class="my-2" />
              <.dropdown_menu_item
                on-select={JS.push(@on_change, value: %{clear: true})}
                class="text-muted-foreground"
              >
                <.icon name={@clear_icon} class="mr-2 h-4 w-4" /> Clear selection
              </.dropdown_menu_item>
            <% end %>
          </div>
        </.dropdown_menu_content>
      </.dropdown_menu>

      <script>
        // Search functionality
        window.addEventListener("livefilter:search", (e) => {
          if (e.detail.id !== "<%= @id %>") return;
          
          const searchInput = document.getElementById("<%= @search_id %>");
          const searchTerm = searchInput.value.toLowerCase();
          const optionsContainer = document.getElementById("<%= @id %>-options");
          const options = optionsContainer.querySelectorAll("[data-search-value]");
          
          options.forEach(option => {
            const value = option.dataset.searchValue;
            if (searchTerm === "" || value.includes(searchTerm)) {
              option.style.display = "block";
            } else {
              option.style.display = "none";
            }
          });
        });
      </script>
    </div>
    """
  end

  defp render_button_content(assigns) do
    cond do
      assigns.selected == [] || assigns.selected == nil ->
        ~H"""
        {@label || @placeholder}
        """

      length(assigns.selected) <= assigns.display_count ->
        selected_labels =
          assigns.selected
          |> Enum.map(fn value ->
            option = Enum.find(assigns.options, fn opt -> elem(opt, 0) == value end)
            if option, do: elem(option, 1), else: nil
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.join(", ")

        if selected_labels == "" do
          ~H"{@placeholder}"
        else
          # Show label on left, selected values on right
          assigns = assign(assigns, :selected_labels, selected_labels)

          ~H"""
          <span class="flex items-center gap-1">
            <span>{@label || ""}</span>
            <.separator orientation="vertical" class="mx-0.5 h-4" />
            <%= if @multiple do %>
              <%= if length(@selected) <= 2 do %>
                <%= for label <- String.split(@selected_labels, ", ") do %>
                  <.badge variant="secondary" class="rounded-sm px-1 font-normal">
                    {label}
                  </.badge>
                <% end %>
              <% else %>
                <.badge variant="secondary" class="rounded-sm px-1 font-normal">
                  {length(@selected)} selected
                </.badge>
              <% end %>
            <% else %>
              <.badge variant="secondary" class="rounded-sm px-1 font-normal">
                {@selected_labels}
              </.badge>
            <% end %>
            <div
              role="button"
              aria-label={"Clear #{@label} filter"}
              tabindex="0"
              class="ml-1 inline-flex h-4 w-4 items-center justify-center rounded-sm text-muted-foreground opacity-70 transition-opacity hover:opacity-100 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
              phx-click={JS.push(@on_change, value: %{clear: true})}
            >
              <.icon name="hero-x-mark" class="h-4 w-4 text-current" />
            </div>
          </span>
          """
        end

      true ->
        # Show "X selected" when more than display_count items are selected
        ~H"""
        <span class="flex items-center gap-1">
          <span>{@label || ""}</span>
          <.separator orientation="vertical" class="mx-0.5 h-4" />
          <.badge variant="secondary" class="rounded-sm px-1 font-normal">
            {length(@selected)} selected
          </.badge>
          <div
            role="button"
            aria-label={"Clear #{@label} filter"}
            tabindex="0"
            class="ml-1 inline-flex h-4 w-4 items-center justify-center rounded-sm text-muted-foreground opacity-70 transition-opacity hover:opacity-100 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
            phx-click={JS.push(@on_change, value: %{clear: true})}
          >
            <.icon name="hero-x-mark" class="h-4 w-4 text-current" />
          </div>
        </span>
        """
    end
  end
end
