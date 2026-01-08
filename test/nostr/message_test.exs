defmodule Nostr.MessageTest do
  use ExUnit.Case, async: true

  alias Nostr.Test.Fixtures

  doctest Nostr.Message

  describe "create_event/1" do
    test "creates event tuple from Nostr.Event" do
      event = Fixtures.signed_event()
      {:event, result} = Nostr.Message.create_event(event)
      assert result == event
    end

    test "creates event tuple from wrapped event" do
      event = Fixtures.signed_event()
      wrapper = %{event: event}
      {:event, result} = Nostr.Message.create_event(wrapper)
      assert result == event
    end
  end

  describe "request/2" do
    test "creates request tuple with filter (wraps in list)" do
      filter = %Nostr.Filter{kinds: [1], limit: 10}
      {:req, sub_id, result_filters} = Nostr.Message.request(filter, "sub123")

      assert sub_id == "sub123"
      assert result_filters == [filter]
    end

    test "creates request tuple with filter list" do
      filters = [%Nostr.Filter{kinds: [1]}, %Nostr.Filter{kinds: [0]}]
      {:req, sub_id, result_filters} = Nostr.Message.request(filters, "sub456")

      assert sub_id == "sub456"
      assert result_filters == filters
    end
  end

  describe "close/1" do
    test "creates close tuple" do
      {:close, sub_id} = Nostr.Message.close("sub789")
      assert sub_id == "sub789"
    end
  end

  describe "count/2" do
    test "creates count response with integer" do
      {:count, sub_id, %{count: count}} = Nostr.Message.count(42, "sub123")
      assert sub_id == "sub123"
      assert count == 42
    end

    test "creates count request with filter" do
      filter = %Nostr.Filter{kinds: [1]}
      {:count, sub_id, result_filter} = Nostr.Message.count(filter, "sub456")
      assert sub_id == "sub456"
      assert result_filter == filter
    end

    test "creates count request with filter list" do
      filters = [%Nostr.Filter{kinds: [1]}]
      {:count, sub_id, result_filters} = Nostr.Message.count(filters, "sub789")
      assert sub_id == "sub789"
      assert result_filters == filters
    end
  end

  describe "event/2" do
    test "creates relay event tuple" do
      event = Fixtures.signed_event()
      {:event, sub_id, result} = Nostr.Message.event(event, "sub123")

      assert sub_id == "sub123"
      assert result == event
    end
  end

  describe "notice/1" do
    test "creates notice tuple" do
      {:notice, message} = Nostr.Message.notice("Error: rate limited")
      assert message == "Error: rate limited"
    end
  end

  describe "eose/1" do
    test "creates eose tuple" do
      {:eose, sub_id} = Nostr.Message.eose("sub123")
      assert sub_id == "sub123"
    end
  end

  describe "ok/3" do
    test "creates ok tuple for success" do
      {:ok, event_id, success, message} = Nostr.Message.ok("event123", true, "")
      assert event_id == "event123"
      assert success == true
      assert message == ""
    end

    test "creates ok tuple for failure" do
      {:ok, event_id, success, message} =
        Nostr.Message.ok("event456", false, "duplicate: event exists")

      assert event_id == "event456"
      assert success == false
      assert message == "duplicate: event exists"
    end
  end

  describe "auth/1" do
    test "creates auth tuple with challenge string" do
      {:auth, challenge} = Nostr.Message.auth("random_challenge")
      assert challenge == "random_challenge"
    end

    test "creates auth tuple with event" do
      event = Fixtures.signed_event(kind: 22_242)
      {:auth, result} = Nostr.Message.auth(event)
      assert result == event
    end
  end

  describe "serialize/1" do
    test "serializes event message" do
      event = Fixtures.signed_event()
      msg = Nostr.Message.create_event(event)
      json = Nostr.Message.serialize(msg)

      decoded = JSON.decode!(json)
      assert Enum.at(decoded, 0) == "EVENT"
      assert is_map(Enum.at(decoded, 1))
    end

    test "serializes request message" do
      filter = %Nostr.Filter{kinds: [1], limit: 10}
      msg = Nostr.Message.request(filter, "sub123")
      json = Nostr.Message.serialize(msg)

      decoded = JSON.decode!(json)
      assert Enum.at(decoded, 0) == "REQ"
      assert Enum.at(decoded, 1) == "sub123"
    end

    test "serializes close message" do
      msg = Nostr.Message.close("sub123")
      json = Nostr.Message.serialize(msg)

      decoded = JSON.decode!(json)
      assert decoded == ["CLOSE", "sub123"]
    end

    test "serializes notice message" do
      msg = Nostr.Message.notice("hello")
      json = Nostr.Message.serialize(msg)

      decoded = JSON.decode!(json)
      assert decoded == ["NOTICE", "hello"]
    end

    test "serializes eose message" do
      msg = Nostr.Message.eose("sub123")
      json = Nostr.Message.serialize(msg)

      decoded = JSON.decode!(json)
      assert decoded == ["EOSE", "sub123"]
    end

    test "serializes ok message" do
      msg = Nostr.Message.ok("event123", true, "")
      json = Nostr.Message.serialize(msg)

      decoded = JSON.decode!(json)
      assert decoded == ["OK", "event123", true, ""]
    end
  end

  describe "parse/1" do
    test "parses EVENT message from client" do
      event = Fixtures.signed_event()
      json = ~s(["EVENT",#{JSON.encode!(event)}])

      {:event, parsed} = Nostr.Message.parse(json)
      assert parsed.id == event.id
    end

    test "parses EVENT message from relay" do
      event = Fixtures.signed_event()
      json = ~s(["EVENT","sub123",#{JSON.encode!(event)}])

      {:event, sub_id, parsed} = Nostr.Message.parse(json)
      assert sub_id == "sub123"
      assert parsed.id == event.id
    end

    test "parses REQ message with single filter" do
      json = ~s(["REQ","sub123",{"kinds":[1],"limit":10}])

      {:req, sub_id, [filter]} = Nostr.Message.parse(json)
      assert sub_id == "sub123"
      assert filter.kinds == [1]
      assert filter.limit == 10
    end

    test "parses REQ message with multiple filters" do
      json = ~s(["REQ","sub123",{"kinds":[1]},{"kinds":[0],"authors":["abc123"]}])

      {:req, sub_id, filters} = Nostr.Message.parse(json)
      assert sub_id == "sub123"
      assert length(filters) == 2
      assert Enum.at(filters, 0).kinds == [1]
      assert Enum.at(filters, 1).kinds == [0]
      assert Enum.at(filters, 1).authors == ["abc123"]
    end

    test "parses CLOSE message" do
      json = ~s(["CLOSE","sub123"])

      {:close, sub_id} = Nostr.Message.parse(json)
      assert sub_id == "sub123"
    end

    test "parses NOTICE message" do
      json = ~s(["NOTICE","Error message"])

      {:notice, message} = Nostr.Message.parse(json)
      assert message == "Error message"
    end

    test "parses EOSE message" do
      json = ~s(["EOSE","sub123"])

      {:eose, sub_id} = Nostr.Message.parse(json)
      assert sub_id == "sub123"
    end

    test "parses OK message" do
      json = ~s(["OK","event123",true,""])

      {:ok, event_id, success, message} = Nostr.Message.parse(json)
      assert event_id == "event123"
      assert success == true
      assert message == ""
    end

    test "parses OK message with error" do
      json = ~s(["OK","event456",false,"duplicate: already have this event"])

      {:ok, event_id, success, message} = Nostr.Message.parse(json)
      assert event_id == "event456"
      assert success == false
      assert message == "duplicate: already have this event"
    end

    test "parses AUTH challenge message" do
      json = ~s(["AUTH","challenge_string"])

      {:auth, challenge} = Nostr.Message.parse(json)
      assert challenge == "challenge_string"
    end

    test "parses AUTH event message from client" do
      tags = [
        Nostr.Tag.create(:relay, "wss://relay.example.com"),
        Nostr.Tag.create(:challenge, "test_challenge")
      ]

      event = Fixtures.signed_event(kind: 22_242, tags: tags)
      json = ~s(["AUTH",#{JSON.encode!(event)}])

      {:auth, parsed} = Nostr.Message.parse(json)
      assert %Nostr.Event{} = parsed
      assert parsed.kind == 22_242
      assert parsed.id == event.id
    end

    test "parses CLOSED message" do
      json = ~s(["CLOSED","sub123","subscription closed"])

      {:closed, sub_id, message} = Nostr.Message.parse(json)
      assert sub_id == "sub123"
      assert message == "subscription closed"
    end

    test "returns error for unknown message type" do
      json = ~s(["UNKNOWN","data"])

      assert Nostr.Message.parse(json) == :error
    end

    test "parses COUNT message" do
      json = ~s(["COUNT","sub123",{"count":42}])

      {:count, sub_id, %{count: count}} = Nostr.Message.parse(json)
      assert sub_id == "sub123"
      assert count == 42
    end
  end

  describe "closed/2" do
    test "creates closed tuple" do
      {:closed, sub_id, message} = Nostr.Message.closed("sub123", "rate-limited:")
      assert sub_id == "sub123"
      assert message == "rate-limited:"
    end

    test "serializes closed message" do
      msg = Nostr.Message.closed("sub123", "error: subscription not found")
      json = Nostr.Message.serialize(msg)

      decoded = JSON.decode!(json)
      assert decoded == ["CLOSED", "sub123", "error: subscription not found"]
    end
  end

  describe "count/2 roundtrip" do
    test "count request roundtrip" do
      filter = %Nostr.Filter{kinds: [1], limit: 10}
      msg = Nostr.Message.count(filter, "sub123")
      json = Nostr.Message.serialize(msg)

      decoded = JSON.decode!(json)
      assert Enum.at(decoded, 0) == "COUNT"
      assert Enum.at(decoded, 1) == "sub123"
    end

    test "count response roundtrip" do
      msg = Nostr.Message.count(42, "sub123")
      json = Nostr.Message.serialize(msg)

      decoded = JSON.decode!(json)
      assert decoded == ["COUNT", "sub123", %{"count" => 42}]
    end
  end

  describe "parse_specific/1" do
    test "parses event as specific type" do
      raw = Fixtures.raw_event_map(kind: 1, content: "Hello")
      json = ~s(["EVENT","sub123",#{JSON.encode!(raw)}])

      {:event, sub_id, parsed} = Nostr.Message.parse_specific(json)
      assert sub_id == "sub123"
      assert %Nostr.Event.Note{} = parsed
      assert parsed.note == "Hello"
    end

    test "parses AUTH event as ClientAuth type" do
      tags = [
        Nostr.Tag.create(:relay, "wss://relay.example.com"),
        Nostr.Tag.create(:challenge, "test_challenge")
      ]

      event = Fixtures.signed_event(kind: 22_242, tags: tags)
      json = ~s(["AUTH",#{JSON.encode!(event)}])

      {:auth, parsed} = Nostr.Message.parse_specific(json)
      assert %Nostr.Event.ClientAuth{} = parsed
      assert parsed.relay == "wss://relay.example.com"
      assert parsed.challenge == "test_challenge"
    end
  end
end
