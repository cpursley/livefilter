defmodule LiveFilter.Components.QuickFilter do
  @moduledoc """
  A dynamic filter component that renders the appropriate input based on filter type.

  This component automatically detects the filter type and renders the appropriate
  UI element (text input, select, date picker, etc.) with consistent styling and
  behavior across all filter types.

  ## Supported Types
  - `:string` - Text input
  - `:integer`, `:float` - Number input
  - `:boolean` - Toggle/checkbox
  - `:date` - Date picker
  - `:datetime` - DateTime picker
  - `:enum` - Single select dropdown
  - `:array` - Multi-select dropdown

  ## Usage

      <.live_component
        module={LiveFilter.Components.QuickFilter}
        id="filter-title"
        field={:title}
        label="Title"
        type={:string}
        value={@title_filter}
        icon="hero-document"
      />

  Sends messages to parent LiveView:
  - `{:quick_filter_changed, field, value}` when value changes
  - `{:quick_filter_cleared, field}` when filter is cleared
  """
  use Phoenix.LiveComponent
  import SaladUI.{Button, Icon, Input}
  import LiveFilter.Components.SearchSelect
  alias LiveFilter.Components.DateRangeSelect
  alias Phoenix.LiveView.JS

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Set defaults based on type
    defaults =
      Map.merge(
        # Add default class
        %{class: nil},
        default_assigns_for_type(assigns[:type])
      )

    assigns = Map.merge(defaults, assigns)

    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class={["flex items-center gap-2", @class]}>
      {render_filter_input(assigns)}
    </div>
    """
  end

  # Render different input types based on filter type
  defp render_filter_input(%{type: :string} = assigns) do
    ~H"""
    <div class="relative">
      <.icon :if={@icon} name={@icon} class="absolute left-2 top-2 h-4 w-4 text-muted-foreground" />
      <.input
        type="text"
        value={@value || ""}
        placeholder={@placeholder || "Filter #{@label}..."}
        class={["h-8", @icon && "pl-8", @value && @value != "" && "pr-8"]}
        phx-change={JS.push("value_changed", target: @myself)}
        phx-debounce="300"
        name="value"
      />
      <button
        :if={@value && @value != ""}
        type="button"
        class="absolute right-2 top-2 h-4 w-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
        phx-click={JS.push("clear_filter", target: @myself)}
      >
        <.icon name="hero-x-mark" class="h-4 w-4" />
        <span class="sr-only">Clear filter</span>
      </button>
    </div>
    """
  end

  defp render_filter_input(%{type: type} = assigns) when type in [:integer, :float] do
    ~H"""
    <div class="relative">
      <.icon :if={@icon} name={@icon} class="absolute left-2 top-2 h-4 w-4 text-muted-foreground" />
      <.input
        type="number"
        value={@value || ""}
        placeholder={@placeholder || @label}
        class={["h-8 w-32", @icon && "pl-8", @value && "pr-8"]}
        phx-change={JS.push("value_changed", target: @myself)}
        phx-debounce="300"
        name="value"
        step={if @type == :float, do: "0.1", else: "1"}
      />
      <button
        :if={@value}
        type="button"
        class="absolute right-2 top-2 h-4 w-4 rounded-sm opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2"
        phx-click={JS.push("clear_filter", target: @myself)}
      >
        <.icon name="hero-x-mark" class="h-4 w-4" />
        <span class="sr-only">Clear filter</span>
      </button>
    </div>
    """
  end

  defp render_filter_input(%{type: :boolean} = assigns) do
    ~H"""
    <.button
      variant={if @value, do: "default", else: "outline"}
      size="sm"
      phx-click={JS.push("toggle_boolean", target: @myself)}
    >
      <.icon :if={@icon} name={@icon} class="mr-2 h-4 w-4" />
      <%= if @value do %>
        {@label}
        <.icon name="hero-check" class="ml-2 h-4 w-4" />
      <% else %>
        {@label}?
      <% end %>
    </.button>
    """
  end

  defp render_filter_input(%{type: :date} = assigns) do
    ~H"""
    <.live_component
      module={DateRangeSelect}
      id={"#{@id}-date"}
      value={@value}
      label={@label}
      icon={@icon}
      size="sm"
      timestamp_type={:date}
      enabled_presets={[]}
    />
    """
  end

  defp render_filter_input(%{type: type} = assigns)
       when type in [:datetime, :utc_datetime, :naive_datetime] do
    ~H"""
    <.live_component
      module={DateRangeSelect}
      id={"#{@id}-datetime"}
      value={@value}
      label={@label}
      icon={@icon}
      size="sm"
      timestamp_type={@type}
      field={@field}
      enabled_presets={[]}
    />
    """
  end

  defp render_filter_input(%{type: :enum} = assigns) do
    ~H"""
    <.search_select
      id={"#{@id}-select"}
      options={@options || []}
      selected={if @value, do: [@value], else: []}
      on_change={"quick_filter_#{@field}_changed"}
      label={@label}
      icon={@icon}
      multiple={false}
      clearable={true}
      size="sm"
    />
    """
  end

  defp render_filter_input(%{type: :array} = assigns) do
    ~H"""
    <.search_select
      id={"#{@id}-multiselect"}
      options={@options || []}
      selected={@value || []}
      on_change={"quick_filter_#{@field}_changed"}
      label={@label}
      icon={@icon}
      multiple={true}
      clearable={true}
      searchable={true}
      display_count={2}
      size="sm"
    />
    """
  end

  defp render_filter_input(assigns) do
    # Fallback for unknown types
    ~H"""
    <div class="text-sm text-muted-foreground">
      Unsupported filter type: {@type}
    </div>
    """
  end

  @impl true
  def handle_event("value_changed", %{"value" => value}, socket) do
    value =
      case socket.assigns.type do
        :integer -> if value == "", do: nil, else: String.to_integer(value)
        :float -> if value == "", do: nil, else: String.to_float(value)
        _ -> if value == "", do: nil, else: value
      end

    send(self(), {:quick_filter_changed, socket.assigns.field, value})
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filter", _, socket) do
    send(self(), {:quick_filter_cleared, socket.assigns.field})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_boolean", _, socket) do
    new_value = !socket.assigns.value
    send(self(), {:quick_filter_changed, socket.assigns.field, new_value})
    {:noreply, socket}
  end

  @impl true
  def handle_event("enum_changed", params, socket) do
    value =
      case params do
        %{"select" => value} -> value
        %{"clear" => true} -> nil
        _ -> nil
      end

    send(self(), {:quick_filter_changed, socket.assigns.field, value})
    {:noreply, socket}
  end

  @impl true
  def handle_event("array_changed", params, socket) do
    values =
      case params do
        %{"toggle" => value} ->
          current = socket.assigns.value || []

          if value in current do
            List.delete(current, value)
          else
            [value | current]
          end

        %{"clear" => true} ->
          []

        _ ->
          socket.assigns.value || []
      end

    send(self(), {:quick_filter_changed, socket.assigns.field, values})
    {:noreply, socket}
  end

  def handle_info({:date_range_selected, date_range}, socket) do
    send(self(), {:quick_filter_changed, socket.assigns.field, date_range})
    {:noreply, socket}
  end

  # Default assigns based on type
  defp default_assigns_for_type(type) do
    case type do
      :string -> %{placeholder: "Search...", icon: "hero-magnifying-glass"}
      :integer -> %{placeholder: "Number", icon: "hero-hashtag"}
      :float -> %{placeholder: "0.0", icon: "hero-calculator"}
      :boolean -> %{icon: "hero-exclamation-circle"}
      :date -> %{icon: "hero-calendar-days"}
      :datetime -> %{icon: "hero-clock"}
      :utc_datetime -> %{icon: "hero-clock"}
      :naive_datetime -> %{icon: "hero-clock"}
      :enum -> %{icon: "hero-chevron-down"}
      :array -> %{icon: "hero-tag"}
      _ -> %{}
    end
  end
end
