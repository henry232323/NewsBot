defmodule ElixirBot.Mixfile do
  use Mix.Project

  def project do
    [app: :elixirbot,
     version: "0.1.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     name: "Elixirbot"]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {ElixirBotSupervisor, []}
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
    {:nostrum, git: "https://github.com/Kraigie/nostrum.git"},
    {:poison, "~> 3.0"},
    {:html_sanitize_ex, "~> 1.0.0"},
    {:httpoison, "~> 0.11.1"},
    {:ex_doc, "~> 0.14", only: :dev, runtime: false},
    {:fastglobal, "~> 1.0"},
    {:timex, "~> 3.1"},
    {:erlcron, git: "https://github.com/erlware/erlcron"}
    ]
  end
end
