defmodule Nostr.Event.ZapRequestTest do
  use ExUnit.Case, async: true

  alias Nostr.Event
  alias Nostr.Event.ZapRequest
  alias Nostr.Tag
  alias Nostr.Test.Fixtures

  describe "parse/1" do
    test "parses valid zap request with all fields" do
      tags = [
        Tag.create(:relays, "wss://relay1.example.com", ["wss://relay2.example.com"]),
        Tag.create(:amount, "21000"),
        Tag.create(:lnurl, "lnurl1dp68gurn8ghj7..."),
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:e, "event123"),
        Tag.create(:a, "30023:pubkey:identifier"),
        Tag.create(:k, "1")
      ]

      event = Fixtures.signed_event(kind: 9734, content: "Great post!", tags: tags)
      request = ZapRequest.parse(event)

      assert %ZapRequest{} = request
      assert request.recipient == Fixtures.pubkey()
      assert request.relays == ["wss://relay1.example.com", "wss://relay2.example.com"]
      assert request.amount_msats == 21_000
      assert request.lnurl == "lnurl1dp68gurn8ghj7..."
      assert request.event_id == "event123"
      assert request.address == "30023:pubkey:identifier"
      assert request.kind == 1
      assert request.message == "Great post!"
    end

    test "parses minimal zap request" do
      tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, Fixtures.pubkey())
      ]

      event = Fixtures.signed_event(kind: 9734, content: "", tags: tags)
      request = ZapRequest.parse(event)

      assert %ZapRequest{} = request
      assert request.recipient == Fixtures.pubkey()
      assert request.relays == ["wss://relay.example.com"]
      assert request.amount_msats == nil
      assert request.event_id == nil
      assert request.message == ""
    end

    test "returns error for missing p tag" do
      tags = [Tag.create(:relays, "wss://relay.example.com")]
      event = Fixtures.signed_event(kind: 9734, tags: tags)

      assert {:error, "Zap request must have exactly one p tag", _event} = ZapRequest.parse(event)
    end

    test "returns error for multiple p tags" do
      tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, "pubkey1"),
        Tag.create(:p, "pubkey2")
      ]

      event = Fixtures.signed_event(kind: 9734, tags: tags)

      assert {:error, "Zap request must have exactly one p tag", _event} = ZapRequest.parse(event)
    end

    test "returns error for multiple e tags" do
      tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:e, "event1"),
        Tag.create(:e, "event2")
      ]

      event = Fixtures.signed_event(kind: 9734, tags: tags)

      assert {:error, "Zap request must have 0 or 1 e tags", _event} = ZapRequest.parse(event)
    end

    test "returns error for wrong kind" do
      event = Fixtures.signed_event(kind: 1, content: "Not a zap")

      assert {:error, "Event is not a zap request (expected kind 9734)", _event} =
               ZapRequest.parse(event)
    end
  end

  describe "create/3" do
    test "creates zap request with required fields" do
      recipient = Fixtures.pubkey()
      relays = ["wss://relay.example.com"]

      request = ZapRequest.create(recipient, relays)

      assert %ZapRequest{} = request
      assert request.event.kind == 9734
      assert request.recipient == recipient
      assert request.relays == relays
    end

    test "creates zap request with all options" do
      recipient = Fixtures.pubkey()
      relays = ["wss://relay1.com", "wss://relay2.com"]

      request =
        ZapRequest.create(recipient, relays,
          amount_sats: 1000,
          lnurl: "lnurl1...",
          event_id: "event123",
          address: "30023:pub:id",
          kind: 1,
          message: "Nice work!"
        )

      assert request.amount_msats == 1_000_000
      assert request.lnurl == "lnurl1..."
      assert request.event_id == "event123"
      assert request.address == "30023:pub:id"
      assert request.kind == 1
      assert request.message == "Nice work!"
    end

    test "amount_msats takes precedence over amount_sats" do
      request =
        ZapRequest.create(Fixtures.pubkey(), ["wss://relay.example.com"],
          amount_sats: 1000,
          amount_msats: 500_000
        )

      assert request.amount_msats == 500_000
    end
  end

  describe "to_callback_url/2" do
    test "builds callback URL with parameters" do
      recipient = Fixtures.pubkey()
      relays = ["wss://relay.example.com"]

      request = ZapRequest.create(recipient, relays, amount_sats: 100)
      signed_event = Event.sign(request.event, Fixtures.seckey())
      request = %{request | event: signed_event}

      url = ZapRequest.to_callback_url(request, "https://lnurl.example.com/callback")

      assert String.starts_with?(url, "https://lnurl.example.com/callback?")
      assert String.contains?(url, "amount=100000")
      assert String.contains?(url, "nostr=")
    end

    test "appends to existing query string" do
      request =
        ZapRequest.create(Fixtures.pubkey(), ["wss://relay.example.com"], amount_sats: 100)

      signed_event = Event.sign(request.event, Fixtures.seckey())
      request = %{request | event: signed_event}

      url = ZapRequest.to_callback_url(request, "https://example.com?existing=param")

      assert String.contains?(url, "existing=param")
      assert String.contains?(url, "&amount=")
    end
  end

  describe "parser integration" do
    test "parse_specific routes kind 9734 to ZapRequest" do
      tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, Fixtures.pubkey())
      ]

      event = Fixtures.signed_event(kind: 9734, tags: tags)
      parsed = Event.Parser.parse_specific(event)

      assert %ZapRequest{} = parsed
    end
  end
end
