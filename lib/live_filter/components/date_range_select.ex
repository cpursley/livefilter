defmodule LiveFilter.Components.DateRangeSelect do
  @moduledoc """
  A reusable date range selector component for LiveFilter.
  Provides preset date ranges and custom date range selection with a calendar picker.

  ## JavaScript Hook Dependency

  This component requires the LiveFilter JavaScript hook to function properly.
  The hook handles positioning of the calendar dropdown to prevent viewport overflow and
  maintains stable positioning during date selection.

  ### Installation

  When using LiveFilter as a library, run the following to install JavaScript assets:

      mix live_filter.install.assets

  Then import the hook in your `app.js`:

      import LiveFilter from "./hooks/live_filter/live_filter"
      
      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { LiveFilter }
      })

  ### Hook Details

  The LiveFilter hook automatically detects this component and:
  - Calculates optimal calendar position to stay within viewport
  - Handles window resize events
  - Maintains position stability during date selection
  - Uses `phx-hook="LiveFilter"` with `data-livefilter-component="date-range-select"`
  """
  use Phoenix.LiveComponent
  alias Phoenix.LiveView.JS
  import SaladUI.Button
  import SaladUI.Icon
  import SaladUI.Separator
  import SaladUI.DropdownMenu

  @default_date_presets %{
    today: {"today", "Today"},
    tomorrow: {"tomorrow", "Tomorrow"},
    yesterday: {"yesterday", "Yesterday"},
    last_7_days: {"last_7_days", "Last 7 days"},
    next_7_days: {"next_7_days", "Next 7 days"},
    last_30_days: {"last_30_days", "Last 30 days"},
    next_30_days: {"next_30_days", "Next 30 days"},
    this_month: {"this_month", "This month"},
    last_month: {"last_month", "Last month"},
    this_year: {"this_year", "This year"}
  }

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_calendar, false)
     |> assign(:selecting_start, true)
     |> assign(:temp_start_date, nil)
     |> assign(:temp_end_date, nil)
     |> assign(:current_month, Date.utc_today())}
  end

  @impl true
  def update(assigns, socket) do
    # Handle preset configuration
    enabled_presets = assigns[:enabled_presets] || Map.keys(@default_date_presets)

    date_presets =
      if enabled_presets == [] do
        []
      else
        # Build the list of presets based on enabled keys, in logical chronological order
        [
          :last_month,
          :last_30_days,
          :last_7_days,
          :yesterday,
          :today,
          :tomorrow,
          :next_7_days,
          :this_month,
          :next_30_days,
          :this_year
        ]
        |> Enum.filter(&(&1 in enabled_presets))
        |> Enum.map(&Map.get(@default_date_presets, &1))
        |> Enum.reject(&is_nil/1)
      end

    # Set default values for optional assigns
    assigns =
      Map.merge(
        %{
          value: nil,
          label: "Date",
          icon: "hero-calendar-days",
          size: "sm",
          class: nil,
          date_presets: date_presets,
          enabled_presets: enabled_presets,
          # :date | :datetime | :utc_datetime | :naive_datetime
          timestamp_type: :date,
          # {past_years, future_years} from current year
          year_range: {-100, 20}
        },
        assigns
      )

    {:ok,
     socket
     |> assign(assigns)
     |> assign_display_value()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-wrapper"} class="relative" }>
      <%= if @date_presets == [] do %>
        <.button
          variant="outline"
          size={@size}
          class={[
            @class,
            "gap-1 items-center"
          ]}
          phx-click="show_calendar"
          phx-target={@myself}
        >
          <div class="flex items-center gap-1">
            <.icon name={@icon} class="h-4 w-4" />
            <span class="flex items-center gap-2">
              <span>{@label}</span>
              <%= if @value do %>
                <.separator orientation="vertical" class="mx-0.5 h-4" />
                <span>{@display_value}</span>
                <div
                  role="button"
                  aria-label="Clear date filter"
                  tabindex="0"
                  class="ml-1 inline-flex h-4 w-4 items-center justify-center rounded-sm text-muted-foreground opacity-70 transition-opacity hover:opacity-100 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                  phx-click="clear"
                  phx-target={@myself}
                >
                  <.icon name="hero-x-mark" class="h-4 w-4 text-current" />
                </div>
              <% end %>
            </span>
          </div>
        </.button>
      <% else %>
        <.dropdown_menu id={@id}>
          <.dropdown_menu_trigger>
            <.button
              variant="outline"
              size={@size}
              class={[
                @class,
                "gap-1 items-center"
              ]}
            >
              <div class="flex items-center gap-1">
                <.icon name={@icon} class="h-4 w-4" />
                <span class="flex items-center gap-2">
                  <span>{@label}</span>
                  <%= if @value do %>
                    <.separator orientation="vertical" class="mx-0.5 h-4" />
                    <span>{@display_value}</span>
                    <div
                      role="button"
                      aria-label="Clear date filter"
                      tabindex="0"
                      class="ml-1 inline-flex h-4 w-4 items-center justify-center rounded-sm text-muted-foreground opacity-70 transition-opacity hover:opacity-100 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring"
                      phx-click="clear"
                      phx-target={@myself}
                    >
                      <.icon name="hero-x-mark" class="h-4 w-4 text-current" />
                    </div>
                  <% end %>
                </span>
              </div>
            </.button>
          </.dropdown_menu_trigger>

          <.dropdown_menu_content align="start" class="w-[200px]">
            <.dropdown_menu_label>Select date range</.dropdown_menu_label>
            <.dropdown_menu_separator />

            <.dropdown_menu_item
              :for={{value, label} <- @date_presets}
              on-select={JS.push("select_preset", value: %{preset: value}, target: @myself)}
            >
              {label}
            </.dropdown_menu_item>

            <.dropdown_menu_separator />

            <.dropdown_menu_item on-select={JS.push("show_calendar", target: @myself)}>
              Custom range...
            </.dropdown_menu_item>

            <%= if @value do %>
              <.dropdown_menu_separator />
              <.dropdown_menu_item on-select={JS.push("clear", target: @myself)}>
                Clear filter
              </.dropdown_menu_item>
            <% end %>
          </.dropdown_menu_content>
        </.dropdown_menu>
      <% end %>

      <%= if @show_calendar do %>
        <div class="fixed inset-0 z-40" phx-click="cancel_calendar" phx-target={@myself} />
        <div
          id={"#{@id}-calendar-container"}
          class="absolute z-50 left-0 top-0"
          phx-hook="LiveFilter"
          data-livefilter-component="date-range-select"
          data-positioned={@show_calendar}
        >
          <div
            class="fixed bg-popover rounded-lg border shadow-lg p-0 w-auto min-w-[600px]"
            data-calendar-content
          >
            <div class="flex">
              <.render_calendar
                month={@current_month}
                selected_start={@temp_start_date}
                selected_end={@temp_end_date}
                selecting_start={@selecting_start}
                myself={@myself}
                year_range={@year_range}
              />
              <div class="h-[300px] w-[1px] bg-border" />
              <.render_calendar
                month={Date.add(@current_month, Date.days_in_month(@current_month))}
                selected_start={@temp_start_date}
                selected_end={@temp_end_date}
                selecting_start={@selecting_start}
                myself={@myself}
                year_range={@year_range}
              />
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  attr(:month, Date, required: true)
  attr(:selected_start, Date, default: nil)
  attr(:selected_end, Date, default: nil)
  attr(:selecting_start, :boolean, default: true)
  attr(:myself, :any, required: true)
  attr(:year_range, :any, default: {-100, 20})
  attr(:class, :string, default: "")

  defp render_calendar(assigns) do
    current_year = assigns.month.year
    current_month = assigns.month.month

    month_options = [
      {"1", "Jan"},
      {"2", "Feb"},
      {"3", "Mar"},
      {"4", "Apr"},
      {"5", "May"},
      {"6", "Jun"},
      {"7", "Jul"},
      {"8", "Aug"},
      {"9", "Sep"},
      {"10", "Oct"},
      {"11", "Nov"},
      {"12", "Dec"}
    ]

    # Generate year options based on configurable range
    this_year = Date.utc_today().year
    {past_years, future_years} = assigns.year_range

    year_options =
      for year <- (this_year + past_years)..(this_year + future_years),
          do: {to_string(year), to_string(year)}

    assigns =
      assigns
      |> assign(:current_month, current_month)
      |> assign(:current_year, current_year)
      |> assign(:month_options, month_options)
      |> assign(:year_options, year_options)

    ~H"""
    <div class={["p-3 w-[280px]", @class]}>
      <div class="space-y-4">
        <div class="flex items-center justify-center relative">
          <button
            type="button"
            class="inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 hover:bg-accent hover:text-accent-foreground h-7 w-7 bg-transparent p-0 opacity-50 hover:opacity-100 absolute left-1"
            phx-click="prev_month"
            phx-target={@myself}
            aria-label="Go to previous month"
          >
            <.icon name="hero-chevron-left" class="h-4 w-4" />
          </button>

          <div class="flex items-center gap-2 text-sm font-medium">
            <select
              class="h-7 rounded-md border border-transparent bg-transparent pl-2 pr-8 py-1 text-sm shadow-sm hover:bg-accent hover:text-accent-foreground focus:outline-none cursor-pointer"
              phx-change="change_month"
              phx-target={@myself}
              value={to_string(@current_month)}
            >
              <option
                :for={{value, label} <- @month_options}
                value={value}
                selected={value == to_string(@current_month)}
              >
                {label}
              </option>
            </select>

            <select
              class="h-7 rounded-md border border-transparent bg-transparent pl-2 pr-8 py-1 text-sm shadow-sm hover:bg-accent hover:text-accent-foreground focus:outline-none cursor-pointer"
              phx-change="change_year"
              phx-target={@myself}
              value={to_string(@current_year)}
            >
              <option
                :for={{value, label} <- @year_options}
                value={value}
                selected={value == to_string(@current_year)}
              >
                {label}
              </option>
            </select>
          </div>

          <button
            type="button"
            class="inline-flex items-center justify-center rounded-md text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 hover:bg-accent hover:text-accent-foreground h-7 w-7 bg-transparent p-0 opacity-50 hover:opacity-100 absolute right-1"
            phx-click="next_month"
            phx-target={@myself}
            aria-label="Go to next month"
          >
            <.icon name="hero-chevron-right" class="h-4 w-4" />
          </button>
        </div>

        <table class="w-full border-collapse space-y-1">
          <thead>
            <tr class="flex w-full">
              <th
                :for={day <- ~w(S M T W T F S)}
                class="text-muted-foreground rounded-md w-9 font-normal text-[0.8rem]"
              >
                {day}
              </th>
            </tr>
          </thead>
          <tbody class="[&>tr>td]:relative">
            <%= for {week, _week_idx} <- Enum.with_index(calendar_weeks(@month)) do %>
              <tr class="flex w-full mt-2">
                <%= for {day, day_idx} <- Enum.with_index(week) do %>
                  <td class={[
                    "h-9 w-9 text-center text-sm p-0 relative",
                    day && @selected_start && @selected_end &&
                      is_in_range?(day, @selected_start, @selected_end) &&
                      !is_selected?(day, @selected_start, @selected_end) && "bg-accent",
                    day && @selected_start && @selected_end &&
                      is_in_range?(day, @selected_start, @selected_end) && day_idx == 0 &&
                      !is_selected?(day, @selected_start, @selected_end) && "rounded-l-md",
                    day && @selected_start && @selected_end &&
                      is_in_range?(day, @selected_start, @selected_end) && day_idx == 6 &&
                      !is_selected?(day, @selected_start, @selected_end) && "rounded-r-md"
                  ]}>
                    <%= if day && day.month == @month.month do %>
                      <button
                        type="button"
                        class={[
                          "inline-flex h-9 w-9 items-center justify-center text-sm ring-offset-background transition-colors rounded-md",
                          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2",
                          "disabled:pointer-events-none disabled:opacity-50",
                          is_selected?(day, @selected_start, @selected_end) &&
                            "bg-primary text-primary-foreground hover:bg-primary hover:text-primary-foreground",
                          !is_selected?(day, @selected_start, @selected_end) &&
                            is_in_range?(day, @selected_start, @selected_end) &&
                            "hover:bg-accent hover:text-accent-foreground",
                          !is_selected?(day, @selected_start, @selected_end) &&
                            !is_in_range?(day, @selected_start, @selected_end) &&
                            "hover:bg-accent hover:text-accent-foreground",
                          day == Date.utc_today() &&
                            !is_selected?(day, @selected_start, @selected_end) &&
                            !is_in_range?(day, @selected_start, @selected_end) &&
                            "bg-accent text-accent-foreground"
                        ]}
                        phx-click="select_date"
                        phx-value-date={Date.to_iso8601(day)}
                        phx-target={@myself}
                        aria-selected={is_selected?(day, @selected_start, @selected_end)}
                        aria-label={Calendar.strftime(day, "%A, %B %d, %Y")}
                      >
                        <time datetime={Date.to_iso8601(day)}>{day.day}</time>
                      </button>
                    <% else %>
                      <%= if day do %>
                        <span class="inline-flex h-9 w-9 items-center justify-center text-sm text-muted-foreground opacity-50">
                          {day.day}
                        </span>
                      <% end %>
                    <% end %>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_preset", %{"preset" => preset}, socket) do
    # Convert preset to appropriate timestamp type
    date_range = LiveFilter.DateUtils.parse_date_range(preset, socket.assigns.timestamp_type)

    # Send message with field if provided, otherwise just the date range
    message =
      if socket.assigns[:field] do
        {:date_range_selected, socket.assigns.field, date_range}
      else
        {:date_range_selected, date_range}
      end

    send(self(), message)
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_calendar", _, socket) do
    {:noreply,
     socket
     |> assign(:show_calendar, true)
     |> assign(:selecting_start, true)
     |> assign(:temp_start_date, nil)
     |> assign(:temp_end_date, nil)
     |> push_event("show_calendar", %{})}
  end

  @impl true
  def handle_event("cancel_calendar", _, socket) do
    {:noreply,
     socket
     |> assign(:show_calendar, false)
     |> assign(:selecting_start, true)
     |> assign(:temp_start_date, nil)
     |> assign(:temp_end_date, nil)
     |> push_event("hide_calendar", %{})}
  end

  @impl true
  def handle_event("select_date", %{"date" => date_string}, socket) do
    {:ok, date} = Date.from_iso8601(date_string)

    if socket.assigns.selecting_start do
      socket =
        socket
        |> assign(:temp_start_date, date)
        |> assign(:temp_end_date, nil)
        |> assign(:selecting_start, false)

      {:noreply, socket}
    else
      start_date = socket.assigns.temp_start_date
      end_date = date

      # Swap if end is before start
      {start_date, end_date} =
        if Date.compare(end_date, start_date) == :lt do
          {end_date, start_date}
        else
          {start_date, end_date}
        end

      # Auto-apply the date range when second date is selected
      date_range =
        LiveFilter.DateUtils.convert_range_to_type(
          {start_date, end_date},
          socket.assigns.timestamp_type
        )

      # Send message with field if provided, otherwise just the date range
      message =
        if socket.assigns[:field] do
          {:date_range_selected, socket.assigns.field, date_range}
        else
          {:date_range_selected, date_range}
        end

      send(self(), message)

      {:noreply, assign(socket, :show_calendar, false)}
    end
  end

  @impl true
  def handle_event("clear", _, socket) do
    # Send message with field if provided, otherwise just the date range
    message =
      if socket.assigns[:field] do
        {:date_range_selected, socket.assigns.field, nil}
      else
        {:date_range_selected, nil}
      end

    send(self(), message)
    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_month", _, socket) do
    new_month =
      Date.add(
        socket.assigns.current_month,
        -Date.days_in_month(Date.add(socket.assigns.current_month, -1))
      )

    {:noreply, assign(socket, :current_month, new_month)}
  end

  @impl true
  def handle_event("next_month", _, socket) do
    new_month =
      Date.add(socket.assigns.current_month, Date.days_in_month(socket.assigns.current_month))

    {:noreply, assign(socket, :current_month, new_month)}
  end

  @impl true
  def handle_event("change_month", %{"value" => month}, socket) do
    current_date = socket.assigns.current_month
    new_date = %{current_date | month: String.to_integer(month)}
    {:noreply, assign(socket, :current_month, new_date)}
  end

  @impl true
  def handle_event("change_year", %{"value" => year}, socket) do
    current_date = socket.assigns.current_month
    new_date = %{current_date | year: String.to_integer(year)}
    {:noreply, assign(socket, :current_month, new_date)}
  end

  # Helper functions

  defp assign_display_value(socket) do
    display_value =
      case socket.assigns[:value] do
        nil ->
          nil

        {start_val, end_val} ->
          # Convert to dates for display if timestamps
          start_date = to_display_date(start_val)
          end_date = to_display_date(end_val)

          if start_date == end_date do
            format_date(start_date)
          else
            "#{format_date(start_date)} - #{format_date(end_date)}"
          end

        preset when is_binary(preset) ->
          # Find the preset in the configured date_presets
          case List.keyfind(socket.assigns.date_presets, preset, 0) do
            {_, label} -> label
            nil -> preset
          end
      end

    assign(socket, :display_value, display_value)
  end

  defp to_display_date(%Date{} = date), do: date
  defp to_display_date(%DateTime{} = datetime), do: DateTime.to_date(datetime)
  defp to_display_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)

  defp to_display_date(date_string) when is_binary(date_string) do
    # Handle ISO8601 datetime strings
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} ->
        DateTime.to_date(datetime)

      {:error, _} ->
        # Try parsing as date
        case Date.from_iso8601(date_string) do
          {:ok, date} -> date
          {:error, _} -> nil
        end
    end
  end

  defp to_display_date(_), do: nil

  defp calendar_weeks(month) do
    first_day = %{month | day: 1}
    last_day = %{month | day: Date.days_in_month(month)}

    # Start from Sunday before the first day
    start_date = Date.add(first_day, -Date.day_of_week(first_day))

    # End on Saturday after the last day
    days_after = 6 - Date.day_of_week(last_day)
    end_date = Date.add(last_day, days_after)

    Date.range(start_date, end_date)
    |> Enum.chunk_every(7)
  end

  defp is_selected?(date, start_date, end_date) do
    date == start_date || date == end_date
  end

  defp is_in_range?(date, start_date, end_date) do
    start_date && end_date &&
      Date.compare(date, start_date) in [:gt, :eq] &&
      Date.compare(date, end_date) in [:lt, :eq]
  end

  defp format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end
end
