defmodule LiveFilter.MixProject do
  use Mix.Project

  @version "0.1.2"
  @source_url "https://github.com/cpursley/livefilter"

  def project do
    [
      app: :live_filter,
      version: @version,
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: ExCoveralls],
      package: package(),
      name: "LiveFilter",
      description:
        "A flexible and composable filtering library for Phoenix LiveView applications",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {LiveFilter.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      # Run tests and check coverage
      test: ["test", "coveralls"],
      # Run to check the quality of your code
      quality: [
        "format --check-formatted",
        "sobelow --config",
        "credo --only warning"
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0.0"},
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10"},
      {:salad_ui, "~> 1.0.0-beta.3"},
      {:jason, "~> 1.2"},

      # Dev & Test
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp package() do
    [
      name: :livefilter,
      files: ~w(lib priv .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      maintainers: ["Chase Pursley"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Demo" => "https://livefilter.fly.dev/"
      }
    ]
  end

  defp docs() do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
