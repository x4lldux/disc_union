defmodule DiscUnion.Mixfile do
  use Mix.Project

  def project do
    [app: :disc_union,
     version: "0.0.1",
     elixir: "~> 1.2",
     compilers: compilers,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.post": :test],
     consolidate_protocols: Mix.env != :test,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:excoveralls, "~> 0.4", only: [:dev, :test]},
      {:exref, "~> 0.1.1", only: [:dev]},
      {:dialyxir, "~> 0.3.3", only: [:dev]},
      {:ex_doc, "~> 0.11", only: [:dev]},
      {:earmark, "~> 0.1", only: [:dev]},
    ]
  end

  defp compilers do
    compilers(Mix.env)
  end
  defp compilers(:dev) do
     Mix.compilers ++ [:exref]
  end
  defp compilers(_), do: Mix.compilers
end
