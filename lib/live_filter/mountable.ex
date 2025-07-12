defmodule LiveFilter.Mountable do
  @moduledoc """
  Optional LiveView integration for LiveFilter.

  This module provides a `use` macro that adds common filter-related functionality
  to your LiveView modules. Everything is overridable and customizable.

  ## Usage

      defmodule MyAppWeb.ProductLive do
        use MyAppWeb, :live_view
        use LiveFilter.Mountable

        def mount(params, session, socket) do
          socket =
            socket
            |> mount_filters()  # Adds default filter assigns
            |> assign(:products, [])

          {:ok, socket}
        end

        def handle_params(params, _uri, socket) do
          socket = handle_filter_params(socket, params)
          {:noreply, load_products(socket)}
        end
      end

  ## Customization

  You can customize every aspect:

      use LiveFilter.Mountable,
        mount_assigns: [:custom_filter_state],
        param_handler: &MyApp.custom_param_handler/3,
        url_updater: &MyApp.custom_url_updater/2

  Or override the generated functions:

      use LiveFilter.Mountable

      # Override completely
      def mount_filters(socket, opts) do
        # Your custom implementation
      end
  """

  defmacro __using__(opts) do
    quote location: :keep do
      import LiveFilter.Mountable

      @mountable_opts unquote(opts)

      @doc """
      Initialize filter-related assigns in the socket.

      This function can be completely overridden or customized via options.

      ## Options

        * `:initializer` - Custom initialization function
        * `:assigns` - List of assigns to set (default: standard filter assigns)
        * `:registry` - Field registry to use
      """
      def mount_filters(socket, opts \\ []) do
        opts = Keyword.merge(@mountable_opts, opts)

        initializer =
          Keyword.get(opts, :initializer, &LiveFilter.Mountable.default_mount_filters/2)

        initializer.(socket, opts)
      end

      @doc """
      Handle filter parameters from the URL.

      Parses filter params and updates socket assigns accordingly.

      ## Options

        * `:param_handler` - Custom parameter handler function
        * `:fields` - Field configuration for parsing
        * `:restore_ui` - Whether to restore UI state (default: true)
      """
      def handle_filter_params(socket, params, opts \\ []) do
        opts = Keyword.merge(@mountable_opts, opts)
        handler = Keyword.get(opts, :param_handler, &LiveFilter.Mountable.default_param_handler/3)
        handler.(socket, params, opts)
      end

      @doc """
      Update URL with current filter state.

      ## Options

        * `:url_updater` - Custom URL update function
        * `:include_pagination` - Include pagination params (default: true)
        * `:include_sort` - Include sort params (default: true)
      """
      def update_filter_url(socket, opts \\ []) do
        opts = Keyword.merge(@mountable_opts, opts)
        updater = Keyword.get(opts, :url_updater, &LiveFilter.Mountable.default_url_updater/2)
        updater.(socket, opts)
      end

      @doc """
      Apply filters and reload data.

      This is a convenience function that combines building filters and updating URL.

      ## Options

        * `:reload_callback` - Function to call after filters are applied
        * `:update_url` - Whether to update URL (default: true)
      """
      def apply_filters_and_reload(socket, filter_group, opts \\ []) do
        opts = Keyword.merge(@mountable_opts, opts)

        socket = Phoenix.Component.assign(socket, :filter_group, filter_group)

        # Call reload callback if provided
        socket =
          case Keyword.get(opts, :reload_callback) do
            nil -> socket
            callback when is_function(callback, 1) -> callback.(socket)
          end

        # Update URL if requested
        if Keyword.get(opts, :update_url, true) do
          update_filter_url(socket, opts)
        else
          socket
        end
      end

      # Function specs for generated functions
      @spec mount_filters(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
      @spec mount_filters(Phoenix.LiveView.Socket.t(), keyword()) :: Phoenix.LiveView.Socket.t()
      @spec handle_filter_params(Phoenix.LiveView.Socket.t(), map()) ::
              Phoenix.LiveView.Socket.t()
      @spec handle_filter_params(Phoenix.LiveView.Socket.t(), map(), keyword()) ::
              Phoenix.LiveView.Socket.t()
      @spec update_filter_url(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
      @spec update_filter_url(Phoenix.LiveView.Socket.t(), keyword()) ::
              Phoenix.LiveView.Socket.t()
      @spec apply_filters_and_reload(Phoenix.LiveView.Socket.t(), LiveFilter.FilterGroup.t()) ::
              Phoenix.LiveView.Socket.t()
      @spec apply_filters_and_reload(
              Phoenix.LiveView.Socket.t(),
              LiveFilter.FilterGroup.t(),
              keyword()
            ) :: Phoenix.LiveView.Socket.t()

      # Make all functions overridable
      defoverridable mount_filters: 1,
                     mount_filters: 2,
                     handle_filter_params: 2,
                     handle_filter_params: 3,
                     update_filter_url: 1,
                     update_filter_url: 2,
                     apply_filters_and_reload: 2,
                     apply_filters_and_reload: 3
    end
  end

  @doc false
  def default_mount_filters(socket, opts) do
    # Get assigns to set
    assigns = Keyword.get(opts, :assigns, default_filter_assigns())

    # Set each assign
    Enum.reduce(assigns, socket, fn
      {key, value}, acc -> Phoenix.Component.assign(acc, key, value)
      key, acc when is_atom(key) -> Phoenix.Component.assign(acc, key, default_value_for(key))
    end)
  end

  @doc false
  def default_param_handler(socket, params, opts) do
    alias LiveFilter.UrlSerializer

    # Parse filter group from params
    filter_group = UrlSerializer.from_params(params)

    # Parse sort if sort tracking is enabled
    socket =
      if Keyword.get(opts, :track_sort, true) do
        sorts = UrlSerializer.sorts_from_params(params)
        Phoenix.Component.assign(socket, :current_sort, sorts)
      else
        socket
      end

    # Parse pagination if enabled
    socket =
      if Keyword.get(opts, :track_pagination, true) do
        pagination = UrlSerializer.pagination_from_params(params)

        socket
        |> Phoenix.Component.assign(:current_page, pagination.page)
        |> Phoenix.Component.assign(:per_page, pagination.per_page)
      else
        socket
      end

    # Restore UI state if custom converter provided
    ui_converter = Keyword.get(opts, :ui_converter)

    socket =
      if ui_converter && is_function(ui_converter, 2) do
        ui_converter.(socket, filter_group)
      else
        socket
      end

    Phoenix.Component.assign(socket, :filter_group, filter_group)
  end

  @doc false
  def default_url_updater(socket, opts) do
    alias LiveFilter.{UrlSerializer, UrlUtils}

    # Build params based on what's being tracked
    params = %{}

    # Add filters
    filter_group = socket.assigns[:filter_group] || %LiveFilter.FilterGroup{}
    params = UrlSerializer.update_params(params, filter_group)

    # Add sort if tracked
    params =
      if Keyword.get(opts, :include_sort, true) && socket.assigns[:current_sort] do
        UrlSerializer.update_params(params, filter_group, socket.assigns.current_sort)
      else
        params
      end

    # Add pagination if tracked
    params =
      if Keyword.get(opts, :include_pagination, true) do
        pagination = %{
          page: socket.assigns[:current_page] || 1,
          per_page: socket.assigns[:per_page] || 10
        }

        UrlSerializer.update_params(
          params,
          filter_group,
          socket.assigns[:current_sort],
          pagination
        )
      else
        params
      end

    # Get the path function (default to current path)
    path_fn =
      case Keyword.get(opts, :path) do
        nil ->
          fn params ->
            # Convert nested params to flat query string using UrlUtils
            query_string =
              if params == %{}, do: "", else: UrlUtils.flatten_and_encode_params(params)

            # Use a basic path - in practice this should be overridden
            path = if query_string == "", do: "/", else: "/?#{query_string}"
            path
          end

        path when is_binary(path) ->
          fn params ->
            query_string =
              if params == %{}, do: "", else: UrlUtils.flatten_and_encode_params(params)

            full_path = if query_string == "", do: path, else: "#{path}?#{query_string}"
            full_path
          end

        fun when is_function(fun, 1) ->
          fun
      end

    Phoenix.LiveView.push_patch(socket, to: path_fn.(params))
  end

  # Private helpers

  defp default_filter_assigns do
    [
      filter_group: %LiveFilter.FilterGroup{},
      field_registry: nil,
      current_sort: nil,
      current_page: 1,
      per_page: 10,
      total_pages: 1,
      total_count: 0
    ]
  end

  defp default_value_for(:filter_group), do: %LiveFilter.FilterGroup{}
  defp default_value_for(:field_registry), do: nil
  defp default_value_for(:current_sort), do: nil
  defp default_value_for(:current_page), do: 1
  defp default_value_for(:per_page), do: 10
  defp default_value_for(:total_pages), do: 1
  defp default_value_for(:total_count), do: 0
  defp default_value_for(_), do: nil
end
