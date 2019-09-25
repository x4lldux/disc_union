defmodule DiscUnion.Mixfile do
  use Mix.Project

  def project do
    [
      app: :disc_union,
      version: "0.2.0",
      elixir: "~> 1.2",
      description: "Discriminated unions for Elixir - for building algebraic data types",
      package: package(),
      compilers: compilers(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [coveralls: :test, "coveralls.html": :test,
                          "coveralls.detail": :test, "coveralls.post": :test],
      consolidate_protocols: Mix.env != :test,
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env),
      docs: docs()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:excoveralls, "~> 0.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.21", only: [:dev], runtime: false},
      {:earmark, "~> 1.4", only: [:dev], runtime: false},
      {:credo, "~> 1.1", only: [:dev], runtime: false}
    ]
  end

  defp compilers do
    compilers(Mix.env)
  end
  defp compilers(_), do: Mix.compilers

  defp package do
    [ maintainers: ["X4lldux"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/X4lldux/disc_union"} ]
  end

  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(_), do: ["lib"]

  defp docs do
    [extras: [
        "README.md": [title: "README"],
        "CHANGELOG.md": [title: "Changelog"]
      ]]
  end
end
