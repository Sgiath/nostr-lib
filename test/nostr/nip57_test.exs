defmodule Nostr.NIP57Test do
  use ExUnit.Case, async: true

  alias Nostr.Event.ZapReceipt
  alias Nostr.Event.ZapRequest
  alias Nostr.NIP57
  alias Nostr.Tag
  alias Nostr.Test.Fixtures

  @sample_bolt11 "lntb100n1pnqz8x3pp5qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqdq8w3jhxaqcqzzsxqyz5vqsp5qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqs9qxpqysgqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqpqxzwj7y"

  describe "create_zap_request/4" do
    test "creates and signs a zap request" do
      {:ok, request} =
        NIP57.create_zap_request(
          Fixtures.seckey(),
          Fixtures.pubkey(),
          1000,
          relays: ["wss://relay.example.com"]
        )

      assert %ZapRequest{} = request
      assert request.event.kind == 9734
      assert request.event.pubkey == Fixtures.pubkey()
      assert request.event.sig != nil
      assert request.amount_msats == 1_000_000
    end

    test "returns error without relays" do
      assert {:error, "relays option is required"} =
               NIP57.create_zap_request(Fixtures.seckey(), Fixtures.pubkey(), 1000, [])
    end

    test "passes additional options" do
      {:ok, request} =
        NIP57.create_zap_request(
          Fixtures.seckey(),
          Fixtures.pubkey(),
          100,
          relays: ["wss://relay.example.com"],
          event_id: "event123",
          kind: 1,
          message: "Great post!"
        )

      assert request.event_id == "event123"
      assert request.kind == 1
      assert request.message == "Great post!"
    end
  end

  describe "build_callback_url/2" do
    test "builds callback URL" do
      {:ok, request} =
        NIP57.create_zap_request(
          Fixtures.seckey(),
          Fixtures.pubkey(),
          1000,
          relays: ["wss://relay.example.com"]
        )

      url = NIP57.build_callback_url(request, "https://lnurl.example.com/pay")

      assert String.starts_with?(url, "https://lnurl.example.com/pay?")
      assert String.contains?(url, "amount=1000000")
      assert String.contains?(url, "nostr=")
    end
  end

  describe "validate_receipt/2" do
    test "validates receipt with matching pubkey" do
      wallet_pubkey = Fixtures.pubkey()

      tags = [
        Tag.create(:p, wallet_pubkey),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, "{}")
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      receipt = ZapReceipt.parse(event)

      assert :ok = NIP57.validate_receipt(receipt, wallet_pubkey)
    end
  end

  describe "get_zap_amount/1" do
    test "returns amount in sats" do
      # Create receipt with manually constructed invoice
      invoice = %Nostr.Bolt11{amount_msats: 10_000}
      receipt = %ZapReceipt{invoice: invoice}

      # 10000 msats = 10 sats
      assert NIP57.get_zap_amount(receipt) == 10
    end

    test "returns nil when no invoice" do
      receipt = %ZapReceipt{invoice: nil}
      assert NIP57.get_zap_amount(receipt) == nil
    end
  end

  describe "get_zap_amount_msats/1" do
    test "returns amount in millisats" do
      # Create receipt with manually constructed invoice
      invoice = %Nostr.Bolt11{amount_msats: 10_000}
      receipt = %ZapReceipt{invoice: invoice}

      assert NIP57.get_zap_amount_msats(receipt) == 10_000
    end

    test "returns nil when no invoice" do
      receipt = %ZapReceipt{invoice: nil}
      assert NIP57.get_zap_amount_msats(receipt) == nil
    end
  end

  describe "get_zap_request/1" do
    test "returns embedded zap request" do
      zap_request_tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, Fixtures.pubkey())
      ]

      zap_request_event =
        Fixtures.signed_event(kind: 9734, content: "Thanks!", tags: zap_request_tags)

      description_json = ZapReceipt.serialize_event_to_json(zap_request_event)

      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, description_json)
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      receipt = ZapReceipt.parse(event)

      {:ok, request} = NIP57.get_zap_request(receipt)
      assert %ZapRequest{} = request
      assert request.message == "Thanks!"
    end
  end

  describe "supports_zaps?/1" do
    test "returns true for user with lud16" do
      metadata = %{lud16: "user@getalby.com"}
      assert NIP57.supports_zaps?(metadata) == true
    end

    test "returns true for user with lud06" do
      metadata = %{lud06: "lnurl1..."}
      assert NIP57.supports_zaps?(metadata) == true
    end

    test "returns false for user without lightning address" do
      metadata = %{name: "test", about: "hi"}
      assert NIP57.supports_zaps?(metadata) == false
    end

    test "returns false for empty lightning address" do
      metadata = %{lud16: ""}
      assert NIP57.supports_zaps?(metadata) == false
    end
  end

  describe "get_sender/1" do
    test "returns sender from P tag" do
      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:P, "sender_pubkey"),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, "{}")
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      receipt = ZapReceipt.parse(event)

      assert NIP57.get_sender(receipt) == "sender_pubkey"
    end

    test "falls back to zap request pubkey" do
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

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      receipt = ZapReceipt.parse(event)

      # Should return the zap request's pubkey (Fixtures.pubkey())
      assert NIP57.get_sender(receipt) == Fixtures.pubkey()
    end
  end

  describe "get_recipient/1" do
    test "returns recipient pubkey" do
      tags = [
        Tag.create(:p, "recipient_pubkey"),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, "{}")
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      receipt = ZapReceipt.parse(event)

      assert NIP57.get_recipient(receipt) == "recipient_pubkey"
    end
  end

  describe "get_message/1" do
    test "returns message from zap request" do
      zap_request_tags = [
        Tag.create(:relays, "wss://relay.example.com"),
        Tag.create(:p, Fixtures.pubkey())
      ]

      zap_request_event =
        Fixtures.signed_event(kind: 9734, content: "Great post!", tags: zap_request_tags)

      description_json = ZapReceipt.serialize_event_to_json(zap_request_event)

      tags = [
        Tag.create(:p, Fixtures.pubkey()),
        Tag.create(:bolt11, @sample_bolt11),
        Tag.create(:description, description_json)
      ]

      event = Fixtures.signed_event(kind: 9735, tags: tags)
      receipt = ZapReceipt.parse(event)

      assert NIP57.get_message(receipt) == "Great post!"
    end

    test "returns empty string when no zap request" do
      receipt = %ZapReceipt{zap_request: nil}
      assert NIP57.get_message(receipt) == ""
    end
  end
end
