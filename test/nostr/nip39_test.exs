defmodule Nostr.NIP39Test do
  use ExUnit.Case, async: true

  alias Nostr.NIP39
  alias Nostr.Tag
  alias Nostr.Event.Metadata
  alias Nostr.Test.Fixtures

  describe "to_tag/1" do
    test "creates valid i tag from identity map" do
      identity = %{platform: "github", identity: "alice", proof: "abc123"}
      tag = NIP39.to_tag(identity)

      assert %Tag{type: :i, data: "github:alice", info: ["abc123"]} = tag
    end

    test "returns nil for invalid identity" do
      assert NIP39.to_tag(%{}) == nil
      assert NIP39.to_tag(%{platform: "github"}) == nil
      assert NIP39.to_tag(nil) == nil
    end
  end

  describe "from_tags/1" do
    test "extracts identities from i tags" do
      tags = [
        Tag.create(:i, "github:semisol", ["9721ce4ee4fceb91c9711ca2a6c9a5ab"]),
        Tag.create(:i, "twitter:semisol_public", ["1619358434134196225"]),
        Tag.create(:p, "pubkey123", [])
      ]

      identities = NIP39.from_tags(tags)

      assert length(identities) == 2

      assert Enum.at(identities, 0) == %{
               platform: "github",
               identity: "semisol",
               proof: "9721ce4ee4fceb91c9711ca2a6c9a5ab"
             }

      assert Enum.at(identities, 1) == %{
               platform: "twitter",
               identity: "semisol_public",
               proof: "1619358434134196225"
             }
    end

    test "handles mastodon identity format" do
      tags = [
        Tag.create(:i, "mastodon:bitcoinhackers.org/@semisol", ["109775066355589974"])
      ]

      [identity] = NIP39.from_tags(tags)

      assert identity.platform == "mastodon"
      assert identity.identity == "bitcoinhackers.org/@semisol"
      assert identity.proof == "109775066355589974"
    end

    test "handles telegram identity format" do
      tags = [
        Tag.create(:i, "telegram:1087295469", ["nostrdirectory/770"])
      ]

      [identity] = NIP39.from_tags(tags)

      assert identity.platform == "telegram"
      assert identity.identity == "1087295469"
      assert identity.proof == "nostrdirectory/770"
    end

    test "handles i tags without proof" do
      tags = [
        %Tag{type: :i, data: "github:alice", info: []}
      ]

      [identity] = NIP39.from_tags(tags)

      assert identity.platform == "github"
      assert identity.identity == "alice"
      assert identity.proof == ""
    end

    test "skips malformed i tags" do
      tags = [
        Tag.create(:i, "invalidformat", ["proof"]),
        Tag.create(:i, "github:alice", ["valid"])
      ]

      identities = NIP39.from_tags(tags)

      assert length(identities) == 1
      assert Enum.at(identities, 0).platform == "github"
    end

    test "returns empty list for no i tags" do
      tags = [
        Tag.create(:p, "pubkey", []),
        Tag.create(:e, "eventid", [])
      ]

      assert NIP39.from_tags(tags) == []
    end

    test "returns empty list for empty tags" do
      assert NIP39.from_tags([]) == []
    end
  end

  describe "build_tags/1" do
    test "builds multiple i tags" do
      identities = [
        %{platform: "github", identity: "alice", proof: "abc123"},
        %{platform: "twitter", identity: "alice_btc", proof: "12345"}
      ]

      tags = NIP39.build_tags(identities)

      assert length(tags) == 2
      assert %Tag{type: :i, data: "github:alice", info: ["abc123"]} = Enum.at(tags, 0)
      assert %Tag{type: :i, data: "twitter:alice_btc", info: ["12345"]} = Enum.at(tags, 1)
    end

    test "returns empty list for nil" do
      assert NIP39.build_tags(nil) == []
    end

    test "returns empty list for empty list" do
      assert NIP39.build_tags([]) == []
    end

    test "skips invalid identities" do
      identities = [
        %{platform: "github", identity: "alice", proof: "valid"},
        %{invalid: "map"},
        %{platform: "twitter", identity: "bob", proof: "also_valid"}
      ]

      tags = NIP39.build_tags(identities)

      assert length(tags) == 2
    end
  end

  describe "parse/1" do
    test "parses platform:identity string" do
      assert {:ok, {"github", "alice"}} = NIP39.parse("github:alice")
      assert {:ok, {"twitter", "alice_btc"}} = NIP39.parse("twitter:alice_btc")
    end

    test "handles colons in identity" do
      assert {:ok, {"mastodon", "bitcoinhackers.org/@alice"}} =
               NIP39.parse("mastodon:bitcoinhackers.org/@alice")
    end

    test "returns error for invalid format" do
      assert :error = NIP39.parse("nocolon")
      assert :error = NIP39.parse("")
      assert :error = NIP39.parse(":")
      assert :error = NIP39.parse("platform:")
      assert :error = NIP39.parse(":identity")
    end
  end

  describe "supported_platform?/1" do
    test "returns true for supported platforms" do
      assert NIP39.supported_platform?("github") == true
      assert NIP39.supported_platform?("twitter") == true
      assert NIP39.supported_platform?("mastodon") == true
      assert NIP39.supported_platform?("telegram") == true
    end

    test "returns false for unsupported platforms" do
      assert NIP39.supported_platform?("facebook") == false
      assert NIP39.supported_platform?("unknown") == false
      assert NIP39.supported_platform?("") == false
    end
  end

  describe "supported_platforms/0" do
    test "returns list of supported platforms" do
      platforms = NIP39.supported_platforms()

      assert "github" in platforms
      assert "twitter" in platforms
      assert "mastodon" in platforms
      assert "telegram" in platforms
      assert length(platforms) == 4
    end
  end

  describe "proof_url/1" do
    test "builds GitHub gist URL" do
      identity = %{platform: "github", identity: "alice", proof: "abc123"}

      assert NIP39.proof_url(identity) == "https://gist.github.com/alice/abc123"
    end

    test "builds Twitter status URL" do
      identity = %{platform: "twitter", identity: "alice_btc", proof: "1619358434134196225"}

      assert NIP39.proof_url(identity) ==
               "https://twitter.com/alice_btc/status/1619358434134196225"
    end

    test "builds Mastodon post URL" do
      identity = %{
        platform: "mastodon",
        identity: "bitcoinhackers.org/@alice",
        proof: "109775066355589974"
      }

      assert NIP39.proof_url(identity) == "https://bitcoinhackers.org/@alice/109775066355589974"
    end

    test "builds Telegram message URL" do
      identity = %{platform: "telegram", identity: "1087295469", proof: "nostrdirectory/770"}

      assert NIP39.proof_url(identity) == "https://t.me/nostrdirectory/770"
    end

    test "returns nil for unsupported platform" do
      identity = %{platform: "facebook", identity: "alice", proof: "123"}

      assert NIP39.proof_url(identity) == nil
    end

    test "returns nil for invalid input" do
      assert NIP39.proof_url(%{}) == nil
      assert NIP39.proof_url(nil) == nil
    end
  end

  describe "Metadata integration" do
    test "parse extracts identities from kind 0 event with i tags" do
      tags = [
        Tag.create(:i, "github:alice", ["gist123"]),
        Tag.create(:i, "twitter:alice_btc", ["tweet456"])
      ]

      event = Fixtures.signed_event(kind: 0, content: ~s({"name":"alice"}), tags: tags)
      metadata = Metadata.parse(event)

      assert length(metadata.identities) == 2

      assert Enum.at(metadata.identities, 0) == %{
               platform: "github",
               identity: "alice",
               proof: "gist123"
             }

      assert Enum.at(metadata.identities, 1) == %{
               platform: "twitter",
               identity: "alice_btc",
               proof: "tweet456"
             }
    end

    test "create builds i tags from identities option" do
      identities = [
        %{platform: "github", identity: "alice", proof: "abc123"},
        %{platform: "mastodon", identity: "bitcoinhackers.org/@alice", proof: "post789"}
      ]

      metadata = Metadata.create("alice", "About me", nil, nil, identities: identities)

      assert length(metadata.identities) == 2
      assert Enum.at(metadata.identities, 0).platform == "github"
      assert Enum.at(metadata.identities, 1).platform == "mastodon"

      # Verify tags are in the event
      i_tags = Enum.filter(metadata.event.tags, &(&1.type == :i))
      assert length(i_tags) == 2
    end

    test "round-trip: create and parse preserves identities" do
      identities = [
        %{platform: "github", identity: "bob", proof: "gist999"},
        %{platform: "telegram", identity: "123456", proof: "channel/789"}
      ]

      created = Metadata.create("bob", nil, nil, nil, identities: identities)

      # Parse the raw event
      parsed = Metadata.parse(created.event)

      assert parsed.identities == created.identities
    end

    test "metadata without identities has empty list" do
      metadata = Metadata.create("alice", "About me", nil, nil)

      assert metadata.identities == []
    end
  end
end
