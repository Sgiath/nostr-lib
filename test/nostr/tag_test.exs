defmodule Nostr.TagTest do
  use ExUnit.Case, async: true

  doctest Nostr.Tag

  alias Nostr.Tag

  describe "create/2" do
    test "creates a tag with type and data" do
      tag = Tag.create(:p, "pubkey123")

      assert tag.type == :p
      assert tag.data == "pubkey123"
      assert tag.info == []
    end

    test "creates a tag with string type (converts to atom)" do
      tag = Tag.create("e", "event-id")

      assert tag.type == :e
      assert tag.data == "event-id"
      assert tag.info == []
    end
  end

  describe "create/3" do
    test "creates a tag with type, data, and additional info" do
      tag = Tag.create(:e, "event-id", ["wss://relay.example.com", "reply"])

      assert tag.type == :e
      assert tag.data == "event-id"
      assert tag.info == ["wss://relay.example.com", "reply"]
    end

    test "creates a tag with string type and info" do
      tag = Tag.create("relay", "wss://relay.example.com", ["read", "write"])

      assert tag.type == :relay
      assert tag.data == "wss://relay.example.com"
      assert tag.info == ["read", "write"]
    end
  end

  describe "parse/1" do
    test "parses a simple tag array" do
      tag = Tag.parse(["p", "pubkey123"])

      assert tag.type == :p
      assert tag.data == "pubkey123"
      assert tag.info == []
    end

    test "parses a tag array with additional info" do
      tag = Tag.parse(["e", "event-id", "wss://relay.example.com", "reply"])

      assert tag.type == :e
      assert tag.data == "event-id"
      assert tag.info == ["wss://relay.example.com", "reply"]
    end

    test "parses a d tag (parameterized replaceable event identifier)" do
      tag = Tag.parse(["d", "my-identifier"])

      assert tag.type == :d
      assert tag.data == "my-identifier"
      assert tag.info == []
    end
  end

  describe "JSON encoding" do
    test "encodes a single tag to JSON array" do
      tag = Tag.create(:p, "pubkey123")

      assert JSON.encode!(tag) == ~s(["p","pubkey123"])
    end

    test "encodes a tag with info to JSON array" do
      tag = Tag.create(:e, "event-id", ["wss://relay.example.com", "reply"])

      assert JSON.encode!(tag) == ~s(["e","event-id","wss://relay.example.com","reply"])
    end

    test "encodes a list of tags to JSON array of arrays" do
      tags = [
        Tag.create(:p, "pubkey123"),
        Tag.create(:e, "event-id", ["wss://relay.example.com"])
      ]

      result = JSON.encode!(tags)

      assert result == ~s([["p","pubkey123"],["e","event-id","wss://relay.example.com"]])
    end

    test "encodes nested tags within a map structure" do
      tags = [
        Tag.create(:p, "pubkey123"),
        Tag.create(:e, "event-id")
      ]

      map_with_tags = %{tags: tags, other: "value"}

      result = JSON.encode!(map_with_tags)
      decoded = JSON.decode!(result)

      assert decoded["tags"] == [["p", "pubkey123"], ["e", "event-id"]]
      assert decoded["other"] == "value"
    end

    test "encodes tags within a Nostr.Event struct" do
      tags = [
        Tag.create(:p, "pubkey123"),
        Tag.create(:e, "event-id", ["wss://relay.example.com"])
      ]

      event =
        Nostr.Event.create(1,
          tags: tags,
          created_at: ~U[2023-06-09 11:07:59.000000Z],
          content: "Hello"
        )

      result = JSON.encode!(event)
      decoded = JSON.decode!(result)

      assert decoded["tags"] == [["p", "pubkey123"], ["e", "event-id", "wss://relay.example.com"]]
      assert decoded["content"] == "Hello"
      assert decoded["kind"] == 1
    end
  end
end
