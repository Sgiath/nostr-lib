defmodule Nostr.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      # Library
      app: :nostr_lib,
      version: @version,

      # Elixir
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),

      # Documentation
      name: "Nostr Lib",
      source_url: "https://github.com/Sgiath/nostr-lib",
      homepage_url: "https://nostr.sgiath.dev",
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:secp256k1, github: "Sgiath/secp256k1"},

      # Documentation
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:mix_test_watch, "~> 1.1", only: :dev, runtime: false}
    ]
  end

  # Documentation

  defp description do
    "Library which implements Nostr specs"
  end

  defp package do
    [
      name: "nostr_lib",
      maintainers: ["Sgiath <nostr@sgiath.dev>"],
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*),
      licenses: ["WTFPL"],
      links: %{
        "GitHub" => "https://github.com/Sgiath/nostr-lib",
        "Nostr specs" => "https://github.com/nostr-protocol/nips"
      }
    ]
  end

  defp docs do
    [
      authors: [
        "Sgiath <nostr@sgiath.dev>"
      ],
      main: "overview",
      formatters: ["html"],
      extras: ["README.md"]
    ]
  end
end
