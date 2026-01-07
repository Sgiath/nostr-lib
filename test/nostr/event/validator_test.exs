defmodule Nostr.Event.ValidatorTest do
  use ExUnit.Case, async: true

  alias Nostr.Event.Validator
  alias Nostr.Test.Fixtures

  describe "valid?/1" do
    test "returns true for valid signed event" do
      event = Fixtures.signed_event()
      assert Validator.valid?(event)
    end

    test "returns true for event with tags" do
      tags = [Nostr.Tag.create(:e, "abc123"), Nostr.Tag.create(:p, Fixtures.pubkey2())]
      event = Fixtures.signed_event(tags: tags)
      assert Validator.valid?(event)
    end

    test "returns true for different event kinds" do
      for kind <- [0, 1, 3, 4, 5, 6, 7, 40, 1000, 10_000, 20_000, 30_000] do
        event = Fixtures.signed_event(kind: kind)
        assert Validator.valid?(event), "Kind #{kind} should be valid"
      end
    end

    test "returns false for tampered event ID" do
      event = Fixtures.signed_event()
      tampered = %{event | id: "0000000000000000000000000000000000000000000000000000000000000000"}
      refute Validator.valid?(tampered)
    end

    test "returns false for tampered content" do
      event = Fixtures.signed_event(content: "original")
      tampered = %{event | content: "tampered"}
      refute Validator.valid?(tampered)
    end

    test "returns false for tampered pubkey" do
      event = Fixtures.signed_event()
      tampered = %{event | pubkey: Fixtures.pubkey2()}
      refute Validator.valid?(tampered)
    end

    test "returns false for tampered timestamp" do
      event = Fixtures.signed_event()
      tampered = %{event | created_at: ~U[2025-01-01 00:00:00Z]}
      refute Validator.valid?(tampered)
    end

    test "returns false for tampered kind" do
      event = Fixtures.signed_event(kind: 1)
      tampered = %{event | kind: 2}
      refute Validator.valid?(tampered)
    end

    test "returns false for tampered tags" do
      event = Fixtures.signed_event(tags: [])
      tampered = %{event | tags: [Nostr.Tag.create(:e, "fake")]}
      refute Validator.valid?(tampered)
    end

    test "returns false for invalid signature" do
      event = Fixtures.signed_event()
      # Flip a character in the signature
      bad_sig = String.slice(event.sig, 0..-2//1) <> "0"
      tampered = %{event | sig: bad_sig}
      refute Validator.valid?(tampered)
    end

    test "returns false for completely wrong signature" do
      event = Fixtures.signed_event()
      wrong_sig = String.duplicate("0", 128)
      tampered = %{event | sig: wrong_sig}
      refute Validator.valid?(tampered)
    end

    test "returns false for signature from different key" do
      # Create event with one key but sign with another
      event1 = Fixtures.signed_event(seckey: Fixtures.seckey())
      event2 = Fixtures.signed_event(seckey: Fixtures.seckey2())
      # Use event1's data with event2's signature
      tampered = %{event1 | sig: event2.sig}
      refute Validator.valid?(tampered)
    end
  end
end
