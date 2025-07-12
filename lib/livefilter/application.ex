defmodule LiveFilter.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # The LiveFilter library doesn't need any supervised processes by default
      # Applications using LiveFilter can add their own supervised processes
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveFilter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
