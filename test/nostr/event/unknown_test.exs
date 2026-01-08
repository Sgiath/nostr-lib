defmodule Nostr.Event.UnknownTest do
  use ExUnit.Case, async: true

  alias Nostr.Event.Unknown
  alias Nostr.Tag

  describe "parse/1" do
    test "extracts alt tag from event" do
      event = %Nostr.Event{
        kind: 30078,
        tags: [Tag.create(:alt, "Application data event")],
        content: "...",
        created_at: DateTime.utc_now()
      }

      result = Unknown.parse(event)
      assert result.alt == "Application data event"
      assert result.event == event
    end

    test "returns nil alt when no alt tag present" do
      event = %Nostr.Event{
        kind: 30078,
        tags: [],
        content: "...",
        created_at: DateTime.utc_now()
      }

      result = Unknown.parse(event)
      assert result.alt == nil
      assert result.event == event
    end

    test "handles event with other tags but no alt tag" do
      event = %Nostr.Event{
        kind: 30078,
        tags: [Tag.create(:d, "identifier"), Tag.create(:p, "pubkey123")],
        content: "data",
        created_at: DateTime.utc_now()
      }

      result = Unknown.parse(event)
      assert result.alt == nil
    end

    test "extracts alt tag when mixed with other tags" do
      event = %Nostr.Event{
        kind: 30078,
        tags: [
          Tag.create(:d, "identifier"),
          Tag.create(:alt, "Custom protocol message"),
          Tag.create(:p, "pubkey123")
        ],
        content: "data",
        created_at: DateTime.utc_now()
      }

      result = Unknown.parse(event)
      assert result.alt == "Custom protocol message"
    end
  end

  describe "create/2" do
    test "creates event with alt tag" do
      result = Unknown.create(30078, alt: "Custom app data", content: "data")

      assert result.alt == "Custom app data"
      assert result.event.kind == 30078
      assert result.event.content == "data"
      assert Enum.any?(result.event.tags, &(&1.type == :alt && &1.data == "Custom app data"))
    end

    test "creates event without alt tag when not provided" do
      result = Unknown.create(30078, content: "data")

      assert result.alt == nil
      assert result.event.kind == 30078
      assert result.event.content == "data"
      refute Enum.any?(result.event.tags, &(&1.type == :alt))
    end

    test "preserves additional tags" do
      tags = [Tag.create(:d, "identifier")]
      result = Unknown.create(30078, alt: "Description", tags: tags)

      assert result.alt == "Description"
      assert length(result.event.tags) == 2
      assert Enum.any?(result.event.tags, &(&1.type == :alt))
      assert Enum.any?(result.event.tags, &(&1.type == :d))
    end

    test "creates event with default empty content" do
      result = Unknown.create(30078, alt: "Test")

      assert result.event.content == ""
    end

    test "creates event with custom timestamp" do
      timestamp = ~U[2024-01-15 12:00:00Z]
      result = Unknown.create(30078, alt: "Test", created_at: timestamp)

      assert result.event.created_at == timestamp
    end

    test "creates event with pubkey" do
      result = Unknown.create(30078, alt: "Test", pubkey: "abc123")

      assert result.event.pubkey == "abc123"
    end
  end
end
