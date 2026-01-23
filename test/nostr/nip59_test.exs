defmodule Nostr.NIP59Test do
  use ExUnit.Case, async: true

  alias Nostr.Event
  alias Nostr.Event.GiftWrap
  alias Nostr.Event.Rumor
  alias Nostr.Event.Seal
  alias Nostr.Test.Fixtures

  # Test vectors from NIP-59 spec
  @sender_seckey "0beebd062ec8735f4243466049d7747ef5d6594ee838de147f8aab842b15e273"
  @sender_pubkey "611df01bfcf85c26ae65453b772d8f1dfd25c264621c0277e1fc1518686faef9"
  @recipient_seckey "e108399bd8424357a710b606ae0c13166d853d327e47a6e5e038197346bdbf45"
  @recipient_pubkey "166bf3765ebd1fc55decfe395beff2ea3b2a4e0a8946e7eb578512b555737c99"

  describe "Rumor" do
    test "create/2 creates unsigned event with computed ID" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")

      assert rumor.kind == 1
      assert rumor.content == "Hello"
      assert rumor.pubkey == @sender_pubkey
      assert rumor.id != nil
      assert String.length(rumor.id) == 64
    end

    test "create/2 with tags" do
      tags = [Nostr.Tag.create(:p, @recipient_pubkey)]
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello", tags: tags)

      assert length(rumor.tags) == 1
      assert hd(rumor.tags).type == :p
    end

    test "create/2 with custom timestamp" do
      timestamp = ~U[2024-01-01 12:00:00Z]
      rumor = Rumor.create(1, pubkey: @sender_pubkey, created_at: timestamp)

      assert rumor.created_at == timestamp
    end

    test "from_event/1 strips signature from signed event" do
      event = Fixtures.signed_event()
      rumor = Rumor.from_event(event)

      assert rumor.id == event.id
      assert rumor.pubkey == event.pubkey
      assert rumor.kind == event.kind
      assert rumor.content == event.content
      assert rumor.tags == event.tags
      assert rumor.created_at == event.created_at
      # Rumor has no sig field
      refute Map.has_key?(rumor, :sig)
    end

    test "compute_id/1 matches Event.compute_id/1" do
      timestamp = ~U[2024-01-01 00:00:00Z]
      content = "test content"

      rumor = Rumor.create(1, pubkey: Fixtures.pubkey(), content: content, created_at: timestamp)

      event = %Event{
        kind: 1,
        pubkey: Fixtures.pubkey(),
        content: content,
        tags: [],
        created_at: timestamp
      }

      assert rumor.id == Event.compute_id(event)
    end

    test "parse/1 parses raw map to rumor" do
      # Create a rumor first to get a valid ID
      original =
        Rumor.create(1,
          pubkey: @sender_pubkey,
          content: "Hello",
          created_at: ~U[2024-01-01 00:00:00Z]
        )

      data = %{
        "id" => original.id,
        "pubkey" => @sender_pubkey,
        "kind" => 1,
        "content" => "Hello",
        "tags" => [],
        "created_at" => 1_704_067_200
      }

      rumor = Rumor.parse(data)

      assert rumor.kind == 1
      assert rumor.content == "Hello"
      assert rumor.pubkey == @sender_pubkey
      assert rumor.id == original.id
    end

    test "parse/1 returns error for invalid ID" do
      data = %{
        "id" => "invalid_id",
        "pubkey" => @sender_pubkey,
        "kind" => 1,
        "content" => "Hello",
        "tags" => [],
        "created_at" => 1_704_067_200
      }

      result = Rumor.parse(data)

      assert {:error, :invalid_id, _rumor} = result
    end

    test "JSON encoding" do
      rumor =
        Rumor.create(1,
          pubkey: @sender_pubkey,
          content: "Hello",
          created_at: ~U[2024-01-01 00:00:00Z]
        )

      json = JSON.encode!(rumor)
      decoded = JSON.decode!(json)

      assert decoded["kind"] == 1
      assert decoded["content"] == "Hello"
      assert decoded["pubkey"] == @sender_pubkey
      refute Map.has_key?(decoded, "sig")
    end
  end

  describe "Seal" do
    test "create/3 creates valid kind 13 event" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)

      assert seal.event.kind == 13
      assert seal.sender == @sender_pubkey
      assert seal.encrypted_rumor != nil
      assert seal.event.tags == []
    end

    test "create/3 sets pubkey from seckey if not provided" do
      rumor = Rumor.create(1, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)

      assert seal.sender == @sender_pubkey
    end

    test "parse/1 parses kind 13 event" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)

      # Re-parse from the event
      parsed = Seal.parse(seal.event)

      assert parsed.sender == @sender_pubkey
      assert parsed.encrypted_rumor == seal.event.content
    end

    test "unwrap/2 decrypts to original rumor" do
      original_content = "Are you going to the party tonight?"
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: original_content)
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)

      {:ok, unwrapped} = Seal.unwrap(seal, @recipient_seckey)

      assert unwrapped.content == original_content
      assert unwrapped.kind == 1
      assert unwrapped.pubkey == @sender_pubkey
    end

    test "unwrap/2 fails with wrong key" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)

      # Try to unwrap with a different key
      result = Seal.unwrap(seal, Fixtures.seckey())

      assert {:error, _reason} = result
    end

    test "seal has empty tags per NIP-59 spec" do
      rumor =
        Rumor.create(1,
          pubkey: @sender_pubkey,
          content: "Hello",
          tags: [Nostr.Tag.create(:p, @recipient_pubkey)]
        )

      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)

      # Seal tags must be empty even if rumor has tags
      assert seal.event.tags == []
    end
  end

  describe "GiftWrap" do
    test "create/2 creates valid kind 1059 event" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)
      gift_wrap = GiftWrap.create(seal, @recipient_pubkey)

      assert gift_wrap.event.kind == 1059
      assert gift_wrap.recipient == @recipient_pubkey
      assert gift_wrap.encrypted_seal != nil
    end

    test "create/2 adds p tag for recipient" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)
      gift_wrap = GiftWrap.create(seal, @recipient_pubkey)

      assert length(gift_wrap.event.tags) == 1
      [tag] = gift_wrap.event.tags
      assert tag.type == :p
      assert tag.data == @recipient_pubkey
    end

    test "create/2 uses ephemeral signing key" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)
      gift_wrap = GiftWrap.create(seal, @recipient_pubkey)

      # The pubkey on gift wrap should NOT be the sender's pubkey
      refute gift_wrap.event.pubkey == @sender_pubkey
      refute gift_wrap.event.pubkey == @recipient_pubkey
    end

    test "parse/1 parses kind 1059 event" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)
      gift_wrap = GiftWrap.create(seal, @recipient_pubkey)

      # Re-parse from the event
      parsed = GiftWrap.parse(gift_wrap.event)

      assert parsed.recipient == @recipient_pubkey
      assert parsed.encrypted_seal == gift_wrap.event.content
    end

    test "parse/1 returns error if no p tag" do
      event = %Event{
        id: "abc",
        kind: 1059,
        pubkey: "ephemeral",
        content: "encrypted",
        tags: [],
        created_at: DateTime.utc_now(),
        sig: "sig"
      }

      result = GiftWrap.parse(event)
      assert {:error, "Missing recipient p tag", ^event} = result
    end

    test "unwrap/2 decrypts to seal" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)
      gift_wrap = GiftWrap.create(seal, @recipient_pubkey)

      {:ok, unwrapped_seal} = GiftWrap.unwrap(gift_wrap, @recipient_seckey)

      assert unwrapped_seal.event.kind == 13
      assert unwrapped_seal.sender == @sender_pubkey
    end
  end

  describe "GiftWrap convenience functions" do
    test "wrap_message/4 creates complete gift wrap" do
      content = "Are you going to the party tonight?"
      gift_wrap = GiftWrap.wrap_message(1, content, @sender_seckey, @recipient_pubkey)

      assert gift_wrap.event.kind == 1059
      assert gift_wrap.recipient == @recipient_pubkey
    end

    test "unwrap_message/2 decrypts all layers" do
      content = "Are you going to the party tonight?"
      gift_wrap = GiftWrap.wrap_message(1, content, @sender_seckey, @recipient_pubkey)

      {:ok, rumor} = GiftWrap.unwrap_message(gift_wrap, @recipient_seckey)

      assert rumor.content == content
      assert rumor.kind == 1
      assert rumor.pubkey == @sender_pubkey
    end

    test "wrap_message/4 with custom tags" do
      tags = [Nostr.Tag.create(:t, "test")]
      gift_wrap = GiftWrap.wrap_message(1, "Hello", @sender_seckey, @recipient_pubkey, tags: tags)

      {:ok, rumor} = GiftWrap.unwrap_message(gift_wrap, @recipient_seckey)

      assert length(rumor.tags) == 1
      assert hd(rumor.tags).type == :t
    end

    test "full round trip with multiple messages" do
      messages = ["Hello!", "How are you?", "See you later!"]

      for content <- messages do
        gift_wrap = GiftWrap.wrap_message(1, content, @sender_seckey, @recipient_pubkey)
        {:ok, rumor} = GiftWrap.unwrap_message(gift_wrap, @recipient_seckey)
        assert rumor.content == content
      end
    end
  end

  describe "Parser routing" do
    test "parse_specific routes kind 13 to Seal" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)

      raw = event_to_raw_map(seal.event)
      parsed = Event.parse_specific(raw)

      assert %Seal{} = parsed
    end

    test "parse_specific routes kind 1059 to GiftWrap" do
      rumor = Rumor.create(1, pubkey: @sender_pubkey, content: "Hello")
      seal = Seal.create(rumor, @sender_seckey, @recipient_pubkey)
      gift_wrap = GiftWrap.create(seal, @recipient_pubkey)

      raw = event_to_raw_map(gift_wrap.event)
      parsed = Event.parse_specific(raw)

      assert %GiftWrap{} = parsed
    end
  end

  # Helper to convert event to raw map (as if received from JSON)
  defp event_to_raw_map(%Event{} = event) do
    %{
      "id" => event.id,
      "pubkey" => event.pubkey,
      "kind" => event.kind,
      "tags" =>
        Enum.map(event.tags, fn tag -> [Atom.to_string(tag.type), tag.data | tag.info] end),
      "created_at" => DateTime.to_unix(event.created_at),
      "content" => event.content,
      "sig" => event.sig
    }
  end
end
