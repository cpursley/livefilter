defmodule Mix.Tasks.LiveFilter.Install.Assets do
  @moduledoc """
  Installs LiveFilter JavaScript assets to your Phoenix application.

  This task copies JavaScript hooks from the LiveFilter library to your
  application's assets directory so they can be imported and used with
  Phoenix LiveView.

  ## Usage

      $ mix live_filter.install.assets

  This will copy the LiveFilter JavaScript hooks to:

      assets/js/hooks/live_filter/

  ## Integration

  After running this task, add the unified hook to your app.js:

      import LiveFilter from "./hooks/live_filter/live_filter"
      
      let liveSocket = new LiveSocket("/live", Socket, {
        hooks: { LiveFilter }
      })

  ## Included Files

  - `live_filter.js` - Unified hook for all LiveFilter components (recommended)
  - `date_calendar_position.js` - Legacy hook for backward compatibility
  - `index.js` - Module exports for both approaches

  ## Migration from Legacy Hooks

  If you're upgrading from an older version that used individual hooks:

  1. Replace `import DateCalendarPosition from "./hooks/live_filter/date_calendar_position"`
  2. With `import LiveFilter from "./hooks/live_filter/live_filter"`
  3. Update hooks: `{ DateCalendarPosition }` to `{ LiveFilter }`

  The old hooks remain available for backward compatibility.

  """
  use Mix.Task

  @shortdoc "Installs LiveFilter JavaScript assets"

  @impl Mix.Task
  def run(_args) do
    # Ensure the application is loaded
    Mix.Task.run("app.start", [])

    app_dir = File.cwd!()
    assets_dir = Path.join([app_dir, "assets", "js", "hooks", "live_filter"])
    source_dir = Path.join([:code.priv_dir(:live_filter), "static", "js", "hooks"])

    # Create target directory
    case File.mkdir_p(assets_dir) do
      :ok ->
        Mix.shell().info("Created directory: #{assets_dir}")

      {:error, reason} ->
        Mix.shell().error("Failed to create directory #{assets_dir}: #{reason}")
        System.halt(1)
    end

    # Copy hooks
    case File.ls(source_dir) do
      {:ok, files} ->
        for file <- files do
          source_file = Path.join(source_dir, file)
          target_file = Path.join(assets_dir, file)

          case File.cp(source_file, target_file) do
            :ok ->
              Mix.shell().info("Copied: #{file}")

            {:error, reason} ->
              Mix.shell().error("Failed to copy #{file}: #{reason}")
              System.halt(1)
          end
        end

        Mix.shell().info("")
        Mix.shell().info("LiveFilter JavaScript assets installed successfully!")
        Mix.shell().info("")
        Mix.shell().info("Next steps:")
        Mix.shell().info("1. Import the LiveFilter hook in your app.js:")
        Mix.shell().info("")
        Mix.shell().info("   import LiveFilter from \"./hooks/live_filter/live_filter\"")
        Mix.shell().info("")
        Mix.shell().info("2. Add the hook to your LiveSocket:")
        Mix.shell().info("")
        Mix.shell().info("   let liveSocket = new LiveSocket(\"/live\", Socket, {")
        Mix.shell().info("     hooks: { LiveFilter }")
        Mix.shell().info("   })")
        Mix.shell().info("")
        Mix.shell().info("Note: For backward compatibility, the legacy DateCalendarPosition hook")
        Mix.shell().info("is also available. See the documentation for migration details.")
        Mix.shell().info("")

      {:error, reason} ->
        Mix.shell().error("Failed to read source directory #{source_dir}: #{reason}")
        System.halt(1)
    end
  end
end
