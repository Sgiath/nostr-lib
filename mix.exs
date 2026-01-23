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
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
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
      "Core Events (NIP-01)": [
        Nostr.Event.Metadata,
        Nostr.Event.Note,
        Nostr.Event.Ephemeral,
        Nostr.Event.Regular,
        Nostr.Event.Replaceable,
        Nostr.Event.ParameterizedReplaceable,
        Nostr.Event.Unknown
      ],
      "Private Messaging (NIP-17/59)": [
        Nostr.Event.PrivateMessage,
        Nostr.Event.FileMessage,
        Nostr.Event.DMRelayList,
        Nostr.Event.GiftWrap,
        Nostr.Event.Seal,
        Nostr.Event.Rumor
      ],
      "Lists (NIP-51)": [
        Nostr.Event.ListMute,
        Nostr.Event.PinnedNotes,
        Nostr.Event.Bookmarks,
        Nostr.Event.BookmarkSets,
        Nostr.Event.Communities,
        Nostr.Event.PublicChats,
        Nostr.Event.BlockedRelays,
        Nostr.Event.SearchRelays,
        Nostr.Event.SimpleGroups,
        Nostr.Event.RelayFeeds,
        Nostr.Event.Interests,
        Nostr.Event.InterestSets,
        Nostr.Event.MediaFollows,
        Nostr.Event.EmojiList,
        Nostr.Event.EmojiSets,
        Nostr.Event.GoodWikiAuthors,
        Nostr.Event.GoodWikiRelays,
        Nostr.Event.FollowSets,
        Nostr.Event.RelaySets,
        Nostr.Event.CurationSets,
        Nostr.Event.KindMuteSets,
        Nostr.Event.ReleaseArtifactSets,
        Nostr.Event.AppCurationSets,
        Nostr.Event.StarterPacks,
        Nostr.Event.MediaStarterPacks
      ],
      "Public Channels (NIP-28)": [
        Nostr.Event.ChannelCreation,
        Nostr.Event.ChannelMetadata,
        Nostr.Event.ChannelMessage,
        Nostr.Event.ChannelHideMessage,
        Nostr.Event.ChannelMuteUser
      ],
      "Lightning Zaps (NIP-57)": [
        Nostr.Event.ZapRequest,
        Nostr.Event.ZapReceipt
      ],
      "Other Events": [
        # NIP-02
        Nostr.Event.Contacts,
        # NIP-03
        Nostr.Event.OpenTimestamps,
        # NIP-09
        Nostr.Event.Deletion,
        # NIP-22
        Nostr.Event.Comment,
        # NIP-23
        Nostr.Event.Article,
        # NIP-25
        Nostr.Event.Reaction,
        Nostr.Event.ExternalReaction,
        # NIP-32
        Nostr.Event.Label,
        # NIP-37
        Nostr.Event.DraftWrap,
        Nostr.Event.PrivateContentRelayList,
        # NIP-38
        Nostr.Event.UserStatus,
        # NIP-42
        Nostr.Event.ClientAuth,
        # NIP-52
        Nostr.Event.Calendar,
        # NIP-56
        Nostr.Event.Report,
        # NIP-58
        Nostr.Event.BadgeAward,
        # NIP-65
        Nostr.Event.RelayList,
        # NIP-94
        Nostr.Event.FileMetadata
      ],
      "Deprecated Events": [
        # NIP-01 (deprecated)
        Nostr.Event.RecommendRelay,
        # NIP-04 (use NIP-17 instead)
        Nostr.Event.DirectMessage,
        # NIP-18 (deprecated)
        Nostr.Event.Repost
      ]
    ]
  end
end
