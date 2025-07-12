defmodule LiveFilter do
  @moduledoc """
  LiveFilter is a comprehensive, reusable filtering library for Phoenix LiveView applications.

  Inspired by modern tools like Notion and Airtable, it provides a complete solution for 
  filtering, sorting, and pagination with clean URL state management and a modern UI 
  built on SaladUI.

  ## Key Features

  - **Complete Filter System**: 20+ operators across all data types (string, numeric, boolean, date, enum, array)
  - **Database Pagination**: Efficient queries that scale to any dataset size
  - **URL State Management**: Shareable, bookmarkable URLs with complete state restoration
  - **Table Sorting**: Multi-column sorting with visual indicators
  - **Column Management**: Dynamic column visibility
  - **Modern UI**: Built on SaladUI with shadcn/ui design system
  - **Production Ready**: Comprehensive validation, error handling, and performance optimization

  ## Quick Start

  Add LiveFilter to your Phoenix LiveView:

      defmodule MyAppWeb.ProductLive do
        use MyAppWeb, :live_view
        use LiveFilter.Mountable

        def mount(_params, _session, socket) do
          socket = mount_filters(socket, registry: my_field_registry())
          {:ok, socket}
        end

        def handle_params(params, _url, socket) do
          socket = handle_filter_params(socket, params)
          {:noreply, socket}
        end
      end

  ## JavaScript Assets

  Some components require JavaScript hooks. Install them with:

      mix live_filter.install.assets

  Then add to your app.js:

      import LiveFilter from "./hooks/live_filter/live_filter"
      
      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { LiveFilter }
      })

  ## Main Modules

  - `LiveFilter.Mountable` - LiveView integration
  - `LiveFilter.Components.*` - UI components
  - `LiveFilter.QueryBuilder` - Ecto query generation
  - `LiveFilter.UrlSerializer` - URL state management
  - `LiveFilter.Field` - Field type system
  """

  @doc """
  Returns the current version of LiveFilter.
  """
  def version, do: "0.1.0"
end
