defmodule Nostr.Event.ClientAuthTest do
  use ExUnit.Case, async: true

  alias Nostr.Event.ClientAuth
  alias Nostr.Test.Fixtures

  describe "create/3" do
    test "creates ClientAuth struct with relay and challenge" do
      auth = ClientAuth.create("wss://relay.example.com", "challenge123")

      assert %ClientAuth{} = auth
      assert auth.relay == "wss://relay.example.com"
      assert auth.challenge == "challenge123"
      assert auth.event.kind == 22_242
    end

    test "creates event with correct tags" do
      auth = ClientAuth.create("wss://relay.example.com", "test_challenge")

      relay_tag = Enum.find(auth.event.tags, &(&1.type == :relay))
      challenge_tag = Enum.find(auth.event.tags, &(&1.type == :challenge))

      assert relay_tag.data == "wss://relay.example.com"
      assert challenge_tag.data == "test_challenge"
    end

    test "accepts custom options" do
      created_at = ~U[2024-06-01 12:00:00Z]
      auth = ClientAuth.create("wss://relay.example.com", "challenge", created_at: created_at)

      assert auth.event.created_at == created_at
    end

    test "preserves additional tags from options" do
      extra_tag = Nostr.Tag.create(:custom, "value")
      auth = ClientAuth.create("wss://relay.example.com", "challenge", tags: [extra_tag])

      assert Enum.any?(auth.event.tags, &(&1.type == :custom))
      assert Enum.any?(auth.event.tags, &(&1.type == :relay))
      assert Enum.any?(auth.event.tags, &(&1.type == :challenge))
    end
  end

  describe "parse/1" do
    test "parses kind 22242 event into ClientAuth struct" do
      tags = [
        Nostr.Tag.create(:relay, "wss://example.relay"),
        Nostr.Tag.create(:challenge, "abc123")
      ]

      event = Nostr.Event.create(22_242, tags: tags)
      auth = ClientAuth.parse(event)

      assert %ClientAuth{} = auth
      assert auth.event == event
      assert auth.relay == "wss://example.relay"
      assert auth.challenge == "abc123"
    end
  end

  describe "roundtrip" do
    test "create -> sign -> serialize -> parse" do
      auth = ClientAuth.create("wss://relay.example.com", "challenge_string")
      signed = Nostr.Event.sign(auth, Fixtures.seckey())

      # Serialize to JSON (as would be sent over the wire)
      json = JSON.encode!(signed.event)
      raw = JSON.decode!(json)

      # Parse back through the normal event parsing
      parsed = Nostr.Event.parse_specific(raw)

      assert %ClientAuth{} = parsed
      assert parsed.relay == "wss://relay.example.com"
      assert parsed.challenge == "challenge_string"
      assert parsed.event.id == signed.event.id
    end
  end
end
