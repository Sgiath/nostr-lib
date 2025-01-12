defmodule Nostr.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      # Library
      app: :nostr_lib,
      version: @version,

      # Elixir
      elixir: "~> 1.18",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      deps: deps(),

      # Documentation
      name: "Nostr Lib",
      source_url: "https://github.com/Sgiath/nostr-lib",
      homepage_url: "https://sgiath.dev/libraries#nostr_lib",
      description: """
      Library which implements Nostr specs
      """,
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
      {:lib_secp256k1, "~> 0.5"},
      {:ex_bech32, "< 0.6.0"},

      # Development
      {:ex_check, "~> 0.16", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.36", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev], runtime: false},
      {:mix_test_watch, "~> 1.2", only: [:dev], runtime: false}
    ]
  end

  # Documentation

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
      authors: ["Sgiath <nostr@sgiath.dev>"],
      main: "overview",
      api_reference: false,
      formatters: ["html"],
      source_ref: "v#{@version}",
      source_url: "https://github.com/Sgiath/nostr-lib",
      extra_section: "Guides",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: groups_for_modules()
    ]
  end

  defp extras do
    [
      # Introduction
      "docs/introduction/overview.md",
      "docs/introduction/installation.md",
      # Guides
      "docs/guides/basic-usage.md"
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r"docs/introduction/.?",
      Guides: ~r"docs/guides/.?"
    ]
  end

  defp groups_for_modules do
    [
      "Specific Events": [
        # NIP-01
        Nostr.Event.Metadata,
        Nostr.Event.Note,
        Nostr.Event.RecommendRelay,
        # NIP-02
        Nostr.Event.Contacts,
        # NIP-04
        Nostr.Event.DirectMessage,
        # NIP-09
        Nostr.Event.Deletion,
        # NIP-16
        Nostr.Event.Ephemeral,
        Nostr.Event.Regular,
        Nostr.Event.Replaceable,
        # NIP-25
        Nostr.Event.Reaction,
        # NIP-28
        Nostr.Event.ChannelCreation,
        Nostr.Event.ChannelHideMessage,
        Nostr.Event.ChannelMessage,
        Nostr.Event.ChannelMetadata,
        Nostr.Event.ChannelMuteUser,
        # NIP-33
        Nostr.Event.ParameterizedReplaceable,
        # NIP-42
        Nostr.Event.ClientAuth,
        # Other
        Nostr.Event.Unknown
      ]
    ]
  end
end
