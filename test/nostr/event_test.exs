defmodule Nostr.EventTest do
  use ExUnit.Case, async: true

  alias Nostr.Test.Fixtures

  doctest Nostr.Event

  describe "create/2" do
    test "creates event with required fields" do
      event = Nostr.Event.create(1)
      assert event.kind == 1
      assert event.content == ""
      assert event.tags == []
      assert event.pubkey == nil
      assert event.id == nil
      assert event.sig == nil
      assert %DateTime{} = event.created_at
    end

    test "creates event with custom content" do
      event = Nostr.Event.create(1, content: "Hello World")
      assert event.content == "Hello World"
    end

    test "creates event with tags" do
      tags = [Nostr.Tag.create(:e, "event_id"), Nostr.Tag.create(:p, "pubkey")]
      event = Nostr.Event.create(1, tags: tags)
      assert length(event.tags) == 2
    end

    test "creates event with custom timestamp" do
      timestamp = ~U[2024-06-01 12:00:00Z]
      event = Nostr.Event.create(1, created_at: timestamp)
      assert event.created_at == timestamp
    end

    test "creates event with pubkey" do
      event = Nostr.Event.create(1, pubkey: Fixtures.pubkey())
      assert event.pubkey == Fixtures.pubkey()
    end

    test "creates different event kinds" do
      for kind <- [0, 1, 3, 4, 5, 6, 7, 1000, 10_000, 20_000, 30_000] do
        event = Nostr.Event.create(kind)
        assert event.kind == kind
      end
    end
  end

  describe "sign/2" do
    test "signs event and populates all fields" do
      event =
        1
        |> Nostr.Event.create(content: "test", created_at: ~U[2024-01-01 00:00:00Z])
        |> Nostr.Event.sign(Fixtures.seckey())

      assert event.pubkey == Fixtures.pubkey()
      assert event.id != nil
      assert String.length(event.id) == 64
      assert event.sig != nil
      assert String.length(event.sig) == 128
    end

    test "derives pubkey from seckey when not set" do
      event =
        1
        |> Nostr.Event.create()
        |> Nostr.Event.sign(Fixtures.seckey())

      assert event.pubkey == Fixtures.pubkey()
    end

    test "computes id when not set" do
      event =
        1
        |> Nostr.Event.create(created_at: ~U[2024-01-01 00:00:00Z])
        |> Nostr.Event.sign(Fixtures.seckey())

      assert event.id == Nostr.Event.compute_id(event)
    end

    test "raises when pubkey doesn't match seckey" do
      event = Nostr.Event.create(1, pubkey: Fixtures.pubkey2())

      assert_raise RuntimeError, "Event pubkey doesn't match the seckey", fn ->
        Nostr.Event.sign(event, Fixtures.seckey())
      end
    end

    test "raises when pre-set ID is incorrect" do
      event = %Nostr.Event{
        kind: 1,
        content: "test",
        tags: [],
        created_at: ~U[2024-01-01 00:00:00Z],
        pubkey: Fixtures.pubkey(),
        id: "0000000000000000000000000000000000000000000000000000000000000000"
      }

      assert_raise RuntimeError, "Event ID isn't correct", fn ->
        Nostr.Event.sign(event, Fixtures.seckey())
      end
    end

    test "signs wrapped event struct" do
      inner_event = Nostr.Event.create(1, created_at: ~U[2024-01-01 00:00:00Z])
      wrapper = %{event: inner_event, extra: "data"}

      signed = Nostr.Event.sign(wrapper, Fixtures.seckey())

      assert signed.event.sig != nil
      assert signed.event.pubkey == Fixtures.pubkey()
      assert signed.extra == "data"
    end
  end

  describe "compute_id/1" do
    test "computes consistent ID for same event" do
      event = %Nostr.Event{
        kind: 1,
        pubkey: Fixtures.pubkey(),
        content: "test",
        tags: [],
        created_at: ~U[2024-01-01 00:00:00Z]
      }

      id1 = Nostr.Event.compute_id(event)
      id2 = Nostr.Event.compute_id(event)
      assert id1 == id2
    end

    test "computes different IDs for different content" do
      event1 = %Nostr.Event{
        kind: 1,
        pubkey: Fixtures.pubkey(),
        content: "content1",
        tags: [],
        created_at: ~U[2024-01-01 00:00:00Z]
      }

      event2 = %{event1 | content: "content2"}

      refute Nostr.Event.compute_id(event1) == Nostr.Event.compute_id(event2)
    end

    test "ID is 64 hex characters" do
      event = Fixtures.signed_event()
      id = Nostr.Event.compute_id(event)
      assert String.length(id) == 64
      assert String.match?(id, ~r/^[0-9a-f]+$/)
    end
  end

  describe "serialize/1" do
    test "serializes to JSON array format" do
      event = %Nostr.Event{
        kind: 1,
        pubkey: Fixtures.pubkey(),
        content: "test",
        tags: [],
        created_at: ~U[2024-01-01 00:00:00Z]
      }

      json = Nostr.Event.serialize(event)
      decoded = JSON.decode!(json)

      assert is_list(decoded)
      assert Enum.at(decoded, 0) == 0
      assert Enum.at(decoded, 1) == Fixtures.pubkey()
      assert Enum.at(decoded, 2) == 1_704_067_200
      assert Enum.at(decoded, 3) == 1
      assert Enum.at(decoded, 4) == []
      assert Enum.at(decoded, 5) == "test"
    end

    test "serializes tags correctly" do
      event = %Nostr.Event{
        kind: 1,
        pubkey: Fixtures.pubkey(),
        content: "test",
        tags: [Nostr.Tag.create(:e, "eventid", ["relay"]), Nostr.Tag.create(:p, "pubkey")],
        created_at: ~U[2024-01-01 00:00:00Z]
      }

      json = Nostr.Event.serialize(event)
      decoded = JSON.decode!(json)

      tags = Enum.at(decoded, 4)
      assert tags == [["e", "eventid", "relay"], ["p", "pubkey"]]
    end
  end

  describe "parse/1" do
    test "parses valid event map" do
      raw = Fixtures.raw_event_map()
      event = Nostr.Event.parse(raw)

      assert event != nil
      assert event.kind == 1
      assert event.pubkey == Fixtures.pubkey()
      assert event.content == "test content"
    end

    test "returns nil for invalid signature" do
      raw = Fixtures.tampered_sig_event()
      assert Nostr.Event.parse(raw) == nil
    end

    test "returns nil for tampered ID" do
      raw = Fixtures.tampered_id_event()
      assert Nostr.Event.parse(raw) == nil
    end

    test "returns nil for tampered content" do
      raw = Fixtures.tampered_content_event()
      assert Nostr.Event.parse(raw) == nil
    end

    test "parses event with tags" do
      tags = [Nostr.Tag.create(:e, "abc123"), Nostr.Tag.create(:p, "def456")]
      raw = Fixtures.raw_event_map(tags: tags)
      event = Nostr.Event.parse(raw)

      assert length(event.tags) == 2
      assert Enum.at(event.tags, 0).type == :e
      assert Enum.at(event.tags, 0).data == "abc123"
    end

    test "converts unix timestamp to DateTime" do
      raw = Fixtures.raw_event_map()
      event = Nostr.Event.parse(raw)

      assert %DateTime{} = event.created_at
    end
  end

  describe "parse_specific/1" do
    test "parses kind 0 as Metadata" do
      raw = Fixtures.raw_event_map(kind: 0, content: ~s({"name":"test","about":"about"}))
      result = Nostr.Event.parse_specific(raw)

      assert %Nostr.Event.Metadata{} = result
      assert result.name == "test"
    end

    test "parses kind 1 as Note" do
      raw = Fixtures.raw_event_map(kind: 1, content: "Hello world")
      result = Nostr.Event.parse_specific(raw)

      assert %Nostr.Event.Note{} = result
      assert result.note == "Hello world"
    end

    test "parses unknown kind as Unknown" do
      raw = Fixtures.raw_event_map(kind: 99_999)
      result = Nostr.Event.parse_specific(raw)

      assert %Nostr.Event.Unknown{} = result
    end
  end
end
