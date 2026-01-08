defmodule Nostr.MixProject do
  use Mix.Project

  @version "0.2.0"

  def project do
    [
      # Library
      app: :nostr_lib,
      version: @version,

      # Elixir
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() != :test,
      aliases: aliases(),
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

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:lib_secp256k1, "~> 0.7"},
      {:bechamel, "~> 1.0"},
      {:scrypt, "~> 2.1"},
      {:req, "~> 0.5", optional: true},
      {:plug, "~> 1.0", only: :test},

      # Development
      {:ex_check, "~> 0.16", only: [:dev], runtime: false},
      {:credo, "~> 1.7", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false},
      {:mix_audit, "~> 2.1", only: [:dev], runtime: false},
      {:mix_test_watch, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
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
      "docs/guides/basic-usage.md",
      "docs/guides/private-direct-messages.md"
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
        Nostr.Event.Ephemeral,
        Nostr.Event.Regular,
        Nostr.Event.Replaceable,
        # NIP-02
        Nostr.Event.Contacts,
        # NIP-03
        Nostr.Event.OpenTimestamps,
        # NIP-04 (deprecated)
        Nostr.Event.DirectMessage,
        # NIP-09
        Nostr.Event.Deletion,
        # NIP-17
        Nostr.Event.DMRelayList,
        Nostr.Event.FileMessage,
        Nostr.Event.PrivateMessage,
        # NIP-37
        Nostr.Event.DraftWrap,
        Nostr.Event.PrivateContentRelayList,
        # NIP-18 (deprecated)
        Nostr.Event.Repost,
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
        # NIP-51
        Nostr.Event.ListMute,
        # NIP-56
        Nostr.Event.Report,
        # NIP-58
        Nostr.Event.BadgeAward,
        # NIP-59
        Nostr.Event.GiftWrap,
        Nostr.Event.Rumor,
        Nostr.Event.Seal,
        # NIP-94
        Nostr.Event.FileMetadata,
        # Other
        Nostr.Event.Unknown
      ]
    ]
  end
end
