defmodule Nostr.Event.ZapReceiptTest do
  use ExUnit.Case, async: true

  alias Nostr.Event
  alias Nostr.Event.ZapReceipt
  alias Nostr.Event.ZapRequest
  alias Nostr.Tag
  alias Nostr.Test.Fixtures

  # Sample bolt11 invoice (testnet)
  @sample_bolt11 "lntb100n1pnqz8x3pp5qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqdq8w3jhxaqcqzzsxqyz5vqsp5qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqs9qxpqysgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpqxzwj7y"

  describe "parse/1" do
    test "parses valid zap receipt with all fields" do
      # Create a zap request to embed
      zap_request_tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:amount, "100000")
      ]

      zap_request_event =
        Fixtures.signed_event(kind: 9734, content: "Zap!", tags: zap_request_tags)

      description_json = ZapReceipt.serialize_event_to_json(zap_request_event)

      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:P, "sender_pubkey"),
        Tag.create(:e, "zapped_event_id"),
        Tag.create(:a, "30023:pubkey:identifier"),
        Tag.create(:k, "1"),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, description_json),
        Tag.create(:preimage, "preimage_hex")
      ]

      event = Fixtures.signed_event(kind: 9735, content: "", tags: tags)
      receipt = ZapReceipt.parse(event)

      assert %ZapReceipt{} = receipt
      assert receipt.recipient == Fixtures.pubkey()
      assert receipt.sender == "sender_pubkey"
      assert receipt.event_id == "zapped_event_id"
      assert receipt.address == "30023:pubkey:identifier"
      assert receipt.kind == 1
      assert receipt.bolt11 == @sample_bolt11
      assert receipt.preimage == "preimage_hex"
      # invoice may be nil if bolt11 checksum is invalid (test data)
      assert receipt.zap_request != nil
    end

    test "parses minimal zap receipt" do
      zap_request_tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, Fixtures.pubkey())
      ]

      zap_request_event = Fixtures.signed_event(kind: 9734, tags: zap_request_tags)
      description_json = ZapReceipt.serialize_event_to_json(zap_request_event)

      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, description_json)
      ]

      event = Fixtures.signed_event(kind: 9735, content: "", tags: tags)
      receipt = ZapReceipt.parse(event)

      assert %ZapReceipt{} = receipt
      assert receipt.recipient == Fixtures.pubkey()
      assert receipt.sender == nil
      assert receipt.event_id == nil
    end

    test "returns error for missing bolt11 tag" do
      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:description, "{}")
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)

      assert {:error, "Zap receipt must have a bolt11 tag", _event} = ZapReceipt.parse(event)
    end

    test "returns error for missing description tag" do
      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:bolt11, @sample_bolt11)
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)

      assert {:error, "Zap receipt must have a description tag", _event} = ZapReceipt.parse(event)
    end

    test "returns error for wrong kind" do
      event = Fixtures.signed_event(kind: 1)

      assert {:error, "Event is not a zap receipt (expected kind 9735)", _event} =
               ZapReceipt.parse(event)
    end
  end

  describe "create/1" do
    test "creates zap receipt with required fields" do
      zap_request_tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, Fixtures.pubkey())
      ]

      zap_request_event = Fixtures.signed_event(kind: 9734, tags: zap_request_tags)
      description_json = ZapReceipt.serialize_event_to_json(zap_request_event)

      receipt =
        ZapReceipt.create(
          recipient: Fixtures.pubkey(),
          bolt11: @sample_bolt11,
          description: description_json
        )

      assert %ZapReceipt{} = receipt
      assert receipt.event.kind == 9735
      assert receipt.recipient == Fixtures.pubkey()
      assert receipt.bolt11 == @sample_bolt11
    end

    test "creates zap receipt with all options" do
      receipt =
        ZapReceipt.create(
          recipient: Fixtures.pubkey(),
          bolt11: @sample_bolt11,
          description: "{}",
          sender: "sender_pubkey",
          event_id: "event123",
          address: "30023:pub:id",
          kind: 1,
          preimage: "preimage123"
        )

      assert receipt.sender == "sender_pubkey"
      assert receipt.event_id == "event123"
      assert receipt.address == "30023:pub:id"
      assert receipt.kind == 1
      assert receipt.preimage == "preimage123"
    end

    test "returns error for missing required fields" do
      assert {:error, "recipient is required"} = ZapReceipt.create(bolt11: "x", description: "y")
      assert {:error, "bolt11 is required"} = ZapReceipt.create(recipient: "x", description: "y")

      assert {:error, "description is required"} =
               ZapReceipt.create(recipient: "x", bolt11: "y")
    end
  end

  describe "get_amount_sats/1" do
    test "returns amount from parsed invoice" do
      # Create a receipt with a manually constructed invoice
      invoice = %Nostr.Bolt11{amount_msats: 10_000}
      receipt = %ZapReceipt{invoice: invoice}

      assert ZapReceipt.get_amount_sats(receipt) == 10
    end

    test "returns nil when invoice not parsed" do
      receipt = %ZapReceipt{invoice: nil}
      assert ZapReceipt.get_amount_sats(receipt) == nil
    end
  end

  describe "get_zap_request/1" do
    test "returns parsed zap request from description" do
      zap_request_tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:amount, "100000")
      ]

      zap_request_event =
        Fixtures.signed_event(kind: 9734, content: "Hello!", tags: zap_request_tags)

      description_json = ZapReceipt.serialize_event_to_json(zap_request_event)

      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, description_json)
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      receipt = ZapReceipt.parse(event)

      {:ok, request} = ZapReceipt.get_zap_request(receipt)
      assert %ZapRequest{} = request
      assert request.message == "Hello!"
      assert request.amount_msats == 100_000
    end

    test "returns error when zap request not parsed" do
      receipt = %ZapReceipt{zap_request: nil}
      assert {:error, _reason} = ZapReceipt.get_zap_request(receipt)
    end
  end

  describe "validate/2" do
    test "validates receipt against wallet pubkey" do
      wallet_pubkey = Fixtures.pubkey()

      tags = [
        Tag.create(:p, wallet_pubkey),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, "{}")
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      receipt = ZapReceipt.parse(event)

      # Receipt is signed by Fixtures.pubkey()
      assert :ok = ZapReceipt.validate(receipt, wallet_pubkey)
    end

    test "returns error when pubkey doesn't match" do
      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, "{}")
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      receipt = ZapReceipt.parse(event)

      assert {:error, "Receipt pubkey does not match wallet's nostrPubkey"} =
               ZapReceipt.validate(receipt, "different_pubkey")
    end
  end

  describe "parser integration" do
    test "parse_specific routes kind 9735 to ZapReceipt" do
      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, "{}")
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      parsed = Event.Parser.parse_specific(event)

      assert %ZapReceipt{} = parsed
    end
  end
end
