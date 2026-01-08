defmodule Nostr.Event.LabelTest do
  use ExUnit.Case, async: true
  doctest Nostr.Event.Label

  alias Nostr.{Event, Tag}
  alias Nostr.Event.Label
  alias Nostr.Test.Fixtures

  describe "parse/1" do
    test "parses label event with single namespace and label" do
      event = %Event{
        kind: 1985,
        content: "",
        tags: [
          %Tag{type: :L, data: "license", info: []},
          %Tag{type: :l, data: "MIT", info: ["license"]},
          %Tag{type: :e, data: "event123", info: ["wss://relay.example.com"]}
        ],
        pubkey: "labeler_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      label = Label.parse(event)

      assert label.namespaces == ["license"]
      assert label.labels == [{"MIT", "license"}]
      assert label.events == [{"event123", "wss://relay.example.com"}]
    end

    test "parses label event with multiple namespaces and labels" do
      event = %Event{
        kind: 1985,
        content: "",
        tags: [
          %Tag{type: :L, data: "license", info: []},
          %Tag{type: :L, data: "com.example.ontology", info: []},
          %Tag{type: :l, data: "MIT", info: ["license"]},
          %Tag{type: :l, data: "open-source", info: ["com.example.ontology"]},
          %Tag{type: :e, data: "event123", info: []}
        ],
        pubkey: "labeler_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      label = Label.parse(event)

      assert label.namespaces == ["license", "com.example.ontology"]
      assert label.labels == [{"MIT", "license"}, {"open-source", "com.example.ontology"}]
    end

    test "parses label event targeting events (e tags)" do
      event = %Event{
        kind: 1985,
        content: "",
        tags: [
          %Tag{type: :L, data: "ugc", info: []},
          %Tag{type: :l, data: "spam", info: ["ugc"]},
          %Tag{type: :e, data: "event1", info: ["wss://relay1.example.com"]},
          %Tag{type: :e, data: "event2", info: []}
        ],
        pubkey: "labeler_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      label = Label.parse(event)

      assert label.events == [
               {"event1", "wss://relay1.example.com"},
               {"event2", nil}
             ]
    end

    test "parses label event targeting pubkeys (p tags)" do
      event = %Event{
        kind: 1985,
        content: "",
        tags: [
          %Tag{type: :L, data: "#t", info: []},
          %Tag{type: :l, data: "permies", info: ["#t"]},
          %Tag{type: :p, data: "pubkey1", info: ["wss://relay.example.com"]},
          %Tag{type: :p, data: "pubkey2", info: ["wss://relay2.example.com"]}
        ],
        pubkey: "labeler_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      label = Label.parse(event)

      assert label.pubkeys == [
               {"pubkey1", "wss://relay.example.com"},
               {"pubkey2", "wss://relay2.example.com"}
             ]
    end

    test "parses label event targeting addressable events (a tags)" do
      event = %Event{
        kind: 1985,
        content: "",
        tags: [
          %Tag{type: :L, data: "license", info: []},
          %Tag{type: :l, data: "CC-BY-4.0", info: ["license"]},
          %Tag{type: :a, data: "30023:author:my-article", info: ["wss://relay.example.com"]}
        ],
        pubkey: "labeler_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      label = Label.parse(event)

      assert label.addresses == [{"30023:author:my-article", "wss://relay.example.com"}]
    end

    test "parses label event targeting relays (r tags)" do
      event = %Event{
        kind: 1985,
        content: "",
        tags: [
          %Tag{type: :L, data: "ugc", info: []},
          %Tag{type: :l, data: "trusted", info: ["ugc"]},
          %Tag{type: :r, data: "wss://relay1.example.com", info: []},
          %Tag{type: :r, data: "wss://relay2.example.com", info: []}
        ],
        pubkey: "labeler_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      label = Label.parse(event)

      assert label.relays == ["wss://relay1.example.com", "wss://relay2.example.com"]
    end

    test "parses label event targeting topics (t tags)" do
      event = %Event{
        kind: 1985,
        content: "",
        tags: [
          %Tag{type: :L, data: "ugc", info: []},
          %Tag{type: :l, data: "recommended", info: ["ugc"]},
          %Tag{type: :t, data: "nostr", info: []},
          %Tag{type: :t, data: "bitcoin", info: []}
        ],
        pubkey: "labeler_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      label = Label.parse(event)

      assert label.topics == ["nostr", "bitcoin"]
    end

    test "parses label event with mixed targets" do
      event = %Event{
        kind: 1985,
        content: "Multiple targets labeled",
        tags: [
          %Tag{type: :L, data: "ugc", info: []},
          %Tag{type: :l, data: "quality", info: ["ugc"]},
          %Tag{type: :e, data: "event1", info: []},
          %Tag{type: :p, data: "pubkey1", info: []},
          %Tag{type: :a, data: "30023:author:article", info: []},
          %Tag{type: :r, data: "wss://relay.example.com", info: []},
          %Tag{type: :t, data: "topic1", info: []}
        ],
        pubkey: "labeler_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      label = Label.parse(event)

      assert label.events == [{"event1", nil}]
      assert label.pubkeys == [{"pubkey1", nil}]
      assert label.addresses == [{"30023:author:article", nil}]
      assert label.relays == ["wss://relay.example.com"]
      assert label.topics == ["topic1"]
    end

    test "defaults to ugc namespace when l tag has no mark" do
      event = %Event{
        kind: 1985,
        content: "",
        tags: [
          %Tag{type: :l, data: "spam", info: []},
          %Tag{type: :e, data: "event1", info: []}
        ],
        pubkey: "labeler_pubkey",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      label = Label.parse(event)

      assert label.labels == [{"spam", "ugc"}]
    end
  end

  describe "create/3" do
    test "creates label for events" do
      label =
        Label.create(
          [{"MIT", "license"}],
          %{events: ["event123"]}
        )

      assert label.event.kind == 1985
      assert label.namespaces == ["license"]
      assert label.labels == [{"MIT", "license"}]
      assert label.events == [{"event123", nil}]
    end

    test "creates label for events with relay hints" do
      label =
        Label.create(
          [{"approved", "nip28.moderation"}],
          %{events: [{"event123", "wss://relay.example.com"}]}
        )

      assert label.events == [{"event123", "wss://relay.example.com"}]
    end

    test "creates label for pubkeys" do
      label =
        Label.create(
          [{"permies", "#t"}],
          %{pubkeys: ["pubkey1", {"pubkey2", "wss://relay.example.com"}]}
        )

      assert label.namespaces == ["#t"]
      assert label.labels == [{"permies", "#t"}]
      assert label.pubkeys == [{"pubkey1", nil}, {"pubkey2", "wss://relay.example.com"}]
    end

    test "creates label for addressable events" do
      label =
        Label.create(
          [{"CC-BY-4.0", "license"}],
          %{addresses: [{"30023:author:article", "wss://relay.example.com"}]}
        )

      assert label.addresses == [{"30023:author:article", "wss://relay.example.com"}]
    end

    test "creates label for relays" do
      label =
        Label.create(
          [{"trusted", "ugc"}],
          %{relays: ["wss://relay1.example.com", "wss://relay2.example.com"]}
        )

      assert label.relays == ["wss://relay1.example.com", "wss://relay2.example.com"]
    end

    test "creates label for topics" do
      label =
        Label.create(
          [{"recommended", "ugc"}],
          %{topics: ["nostr", "bitcoin"]}
        )

      assert label.topics == ["nostr", "bitcoin"]
    end

    test "creates label with content explanation" do
      label =
        Label.create(
          [{"approve", "nip28.moderation"}],
          %{events: ["event123"]},
          content: "Reviewed and approved for channel"
        )

      assert label.event.content == "Reviewed and approved for channel"
    end

    test "creates label with multiple labels in same namespace" do
      label =
        Label.create(
          [{"open-source", "license"}, {"MIT", "license"}],
          %{events: ["event123"]}
        )

      # Should deduplicate namespaces
      assert label.namespaces == ["license"]
      assert label.labels == [{"open-source", "license"}, {"MIT", "license"}]
    end

    test "creates label with multiple namespaces" do
      label =
        Label.create(
          [{"MIT", "license"}, {"quality", "com.example.review"}],
          %{events: ["event123"]}
        )

      assert Enum.sort(label.namespaces) == Enum.sort(["license", "com.example.review"])
    end

    test "creates label with string-only labels (defaults to ugc)" do
      label =
        Label.create(
          ["spam", "inappropriate"],
          %{events: ["event123"]}
        )

      assert label.namespaces == ["ugc"]
      assert label.labels == [{"spam", "ugc"}, {"inappropriate", "ugc"}]
    end

    test "creates label with mixed targets" do
      label =
        Label.create(
          [{"quality", "ugc"}],
          %{
            events: ["event1"],
            pubkeys: ["pubkey1"],
            addresses: ["30023:author:article"],
            relays: ["wss://relay.example.com"],
            topics: ["topic1"]
          }
        )

      assert label.events == [{"event1", nil}]
      assert label.pubkeys == [{"pubkey1", nil}]
      assert label.addresses == [{"30023:author:article", nil}]
      assert label.relays == ["wss://relay.example.com"]
      assert label.topics == ["topic1"]
    end
  end

  describe "roundtrip" do
    test "create -> sign -> serialize -> parse" do
      label =
        Label.create(
          [{"MIT", "license"}],
          %{events: [{"event123", "wss://relay.example.com"}]},
          content: "License assignment",
          pubkey: Fixtures.pubkey()
        )

      # Sign and serialize
      signed_event = Event.sign(label.event, Fixtures.seckey())
      json = JSON.encode!(signed_event)

      # Parse back
      parsed_event = Nostr.Event.Parser.parse(JSON.decode!(json))
      parsed_label = Label.parse(parsed_event)

      assert parsed_label.namespaces == ["license"]
      assert parsed_label.labels == [{"MIT", "license"}]
      assert parsed_label.events == [{"event123", "wss://relay.example.com"}]
      assert parsed_label.event.content == "License assignment"
    end
  end

  describe "parser integration" do
    test "Parser.parse_specific routes kind 1985 to Label" do
      event = %Event{
        kind: 1985,
        content: "",
        tags: [
          %Tag{type: :L, data: "ugc", info: []},
          %Tag{type: :l, data: "test", info: ["ugc"]},
          %Tag{type: :e, data: "abc", info: []}
        ],
        pubkey: "test",
        created_at: DateTime.utc_now(),
        id: nil,
        sig: nil
      }

      result = Nostr.Event.Parser.parse_specific(event)

      assert %Label{} = result
      assert result.labels == [{"test", "ugc"}]
    end
  end
end
