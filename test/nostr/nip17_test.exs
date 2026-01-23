defmodule Nostr.NIP17Test do
  use ExUnit.Case, async: true

  alias Nostr.Event
  alias Nostr.Event.DMRelayList
  alias Nostr.Event.FileMessage
  alias Nostr.Event.PrivateMessage
  alias Nostr.Event.Rumor
  alias Nostr.NIP17
  alias Nostr.Tag
  alias Nostr.Test.Fixtures

  # Test keys
  @sender_seckey "0beebd062ec8735f4243466049d7747ef5d6594ee838de147f8aab842b15e273"
  @sender_pubkey "611df01bfcf85c26ae65453b772d8f1dfd25c264621c0277e1fc1518686faef9"
  @recipient_seckey "e108399bd8424357a710b606ae0c13166d853d327e47a6e5e038197346bdbf45"
  @recipient_pubkey "166bf3765ebd1fc55decfe395beff2ea3b2a4e0a8946e7eb578512b555737c99"

  describe "PrivateMessage" do
    test "create/4 creates kind 14 rumor with receiver" do
      msg = PrivateMessage.create(@sender_pubkey, [@recipient_pubkey], "Hello!")

      assert msg.rumor.kind == 14
      assert msg.content == "Hello!"
      assert length(msg.receivers) == 1
      assert hd(msg.receivers).pubkey == @recipient_pubkey
    end

    test "create/4 with multiple receivers" do
      receiver2 = Fixtures.pubkey()
      msg = PrivateMessage.create(@sender_pubkey, [@recipient_pubkey, receiver2], "Hello all!")

      assert length(msg.receivers) == 2
      pubkeys = Enum.map(msg.receivers, & &1.pubkey)
      assert @recipient_pubkey in pubkeys
      assert receiver2 in pubkeys
    end

    test "create/4 with receiver relay URL" do
      receiver = %{pubkey: @recipient_pubkey, relay: "wss://relay.example.com"}
      msg = PrivateMessage.create(@sender_pubkey, [receiver], "Hello!")

      assert hd(msg.receivers).relay == URI.parse("wss://relay.example.com")
    end

    test "create/4 with reply_to" do
      parent_id = "abc123def456"

      msg =
        PrivateMessage.create(@sender_pubkey, [@recipient_pubkey], "Reply!", reply_to: parent_id)

      assert msg.reply_to == parent_id
    end

    test "create/4 with subject" do
      msg =
        PrivateMessage.create(@sender_pubkey, [@recipient_pubkey], "Hello!", subject: "Greetings")

      assert msg.subject == "Greetings"
    end

    test "create/4 with quotes" do
      quotes = [
        %{id: "event1", relay: "wss://relay.com", pubkey: "pubkey1"},
        %{id: "event2"}
      ]

      msg =
        PrivateMessage.create(@sender_pubkey, [@recipient_pubkey], "See this!", quotes: quotes)

      assert length(msg.quotes) == 2
      assert hd(msg.quotes).id == "event1"
    end

    test "parse/1 parses rumor" do
      tags = [Tag.create(:p, @recipient_pubkey), Tag.create(:subject, "Test")]

      rumor =
        Rumor.create(14,
          pubkey: @sender_pubkey,
          content: "Test message",
          tags: tags
        )

      msg = PrivateMessage.parse(rumor)

      assert msg.content == "Test message"
      assert msg.subject == "Test"
      assert hd(msg.receivers).pubkey == @recipient_pubkey
    end

    test "parse/1 parses Event" do
      event = Fixtures.signed_event(kind: 14, content: "Hello from event")
      msg = PrivateMessage.parse(event)

      assert msg.content == "Hello from event"
    end
  end

  describe "FileMessage" do
    @file_metadata %{
      file_type: "image/jpeg",
      encryption_algorithm: "aes-gcm",
      decryption_key: "key123abc",
      decryption_nonce: "nonce456def",
      hash: "sha256hashofencryptedfile"
    }

    test "create/5 creates kind 15 rumor" do
      msg =
        FileMessage.create(
          @sender_pubkey,
          [@recipient_pubkey],
          "https://example.com/file.enc",
          @file_metadata
        )

      assert msg.rumor.kind == 15
      assert msg.file_url == "https://example.com/file.enc"
      assert msg.file_type == "image/jpeg"
      assert msg.encryption_algorithm == "aes-gcm"
      assert msg.decryption_key == "key123abc"
      assert msg.decryption_nonce == "nonce456def"
      assert msg.hash == "sha256hashofencryptedfile"
    end

    test "create/5 with optional metadata" do
      metadata =
        Map.merge(@file_metadata, %{
          original_hash: "originalhash",
          size: 1024,
          dimensions: %{width: 800, height: 600},
          blurhash: "LEHV6nWB",
          thumbnail: "https://example.com/thumb.enc",
          fallbacks: ["https://backup1.com/file.enc", "https://backup2.com/file.enc"]
        })

      msg =
        FileMessage.create(
          @sender_pubkey,
          [@recipient_pubkey],
          "https://example.com/file.enc",
          metadata
        )

      assert msg.original_hash == "originalhash"
      assert msg.size == 1024
      assert msg.dimensions == %{width: 800, height: 600}
      assert msg.blurhash == "LEHV6nWB"
      assert msg.thumbnail == "https://example.com/thumb.enc"
      assert length(msg.fallbacks) == 2
    end

    test "create/5 with reply_to" do
      msg =
        FileMessage.create(
          @sender_pubkey,
          [@recipient_pubkey],
          "https://example.com/file.enc",
          @file_metadata,
          reply_to: "parent_event_id"
        )

      assert msg.reply_to == "parent_event_id"
    end

    test "parse/1 parses rumor" do
      tags = [
        Tag.create(:p, @recipient_pubkey),
        Tag.create(:"file-type", "image/png"),
        Tag.create(:"encryption-algorithm", "aes-gcm"),
        Tag.create(:"decryption-key", "key"),
        Tag.create(:"decryption-nonce", "nonce"),
        Tag.create(:x, "hash123"),
        Tag.create(:size, "2048"),
        Tag.create(:dim, "1920x1080")
      ]

      rumor =
        Rumor.create(15,
          pubkey: @sender_pubkey,
          content: "https://example.com/file.enc",
          tags: tags
        )

      msg = FileMessage.parse(rumor)

      assert msg.file_url == "https://example.com/file.enc"
      assert msg.file_type == "image/png"
      assert msg.size == 2048
      assert msg.dimensions == %{width: 1920, height: 1080}
    end
  end

  describe "DMRelayList" do
    test "create/2 creates kind 10_050 event" do
      relays = ["wss://relay1.example.com", "wss://relay2.example.com"]
      list = DMRelayList.create(relays, pubkey: @sender_pubkey)

      assert list.event.kind == 10_050
      assert list.event.content == ""
      assert length(list.relays) == 2
    end

    test "create/2 parses relay URIs" do
      relays = ["wss://relay.example.com"]
      list = DMRelayList.create(relays)

      assert hd(list.relays) == URI.parse("wss://relay.example.com")
    end

    test "parse/1 extracts relays from event" do
      event =
        Fixtures.signed_event(
          kind: 10_050,
          content: "",
          tags: [
            Tag.create(:relay, "wss://inbox.example.com"),
            Tag.create(:relay, "wss://backup.example.com")
          ]
        )

      list = DMRelayList.parse(event)

      assert length(list.relays) == 2
      relay_strings = Enum.map(list.relays, &URI.to_string/1)
      assert "wss://inbox.example.com" in relay_strings
    end
  end

  describe "NIP17 convenience functions" do
    test "send_dm/4 creates gift wraps for receiver and sender" do
      {:ok, gift_wraps} = NIP17.send_dm(@sender_seckey, [@recipient_pubkey], "Hello!")

      # Should have 2 gift wraps: one for recipient, one for sender
      assert length(gift_wraps) == 2

      recipients = Enum.map(gift_wraps, & &1.recipient)
      assert @sender_pubkey in recipients
      assert @recipient_pubkey in recipients
    end

    test "send_dm/4 and receive_dm/2 round trip" do
      content = "Secret message for you!"

      {:ok, gift_wraps} = NIP17.send_dm(@sender_seckey, [@recipient_pubkey], content)

      # Find the gift wrap for the recipient
      recipient_wrap = Enum.find(gift_wraps, &(&1.recipient == @recipient_pubkey))

      {:ok, msg, sender} = NIP17.receive_dm(recipient_wrap, @recipient_seckey)

      assert msg.content == content
      assert sender == @sender_pubkey
    end

    test "send_dm/4 with options" do
      {:ok, gift_wraps} =
        NIP17.send_dm(@sender_seckey, [@recipient_pubkey], "Reply",
          subject: "Important",
          reply_to: "parent123"
        )

      recipient_wrap = Enum.find(gift_wraps, &(&1.recipient == @recipient_pubkey))
      {:ok, msg, _sender} = NIP17.receive_dm(recipient_wrap, @recipient_seckey)

      assert msg.subject == "Important"
      assert msg.reply_to == "parent123"
    end

    test "send_dm/4 with multiple receivers" do
      receiver2_seckey = Fixtures.seckey()
      receiver2_pubkey = Nostr.Crypto.pubkey(receiver2_seckey)

      {:ok, gift_wraps} =
        NIP17.send_dm(@sender_seckey, [@recipient_pubkey, receiver2_pubkey], "Hello everyone!")

      # Should have 3 gift wraps: sender + 2 receivers
      assert length(gift_wraps) == 3

      # Each receiver can unwrap their message
      for {seckey, pubkey} <- [
            {@recipient_seckey, @recipient_pubkey},
            {receiver2_seckey, receiver2_pubkey}
          ] do
        wrap = Enum.find(gift_wraps, &(&1.recipient == pubkey))
        {:ok, msg, _sender} = NIP17.receive_dm(wrap, seckey)
        assert msg.content == "Hello everyone!"
      end
    end

    test "receive_dm/2 validates sender" do
      {:ok, gift_wraps} = NIP17.send_dm(@sender_seckey, [@recipient_pubkey], "Test")
      recipient_wrap = Enum.find(gift_wraps, &(&1.recipient == @recipient_pubkey))

      {:ok, _msg, sender} = NIP17.receive_dm(recipient_wrap, @recipient_seckey)

      # Sender should match the signer of the seal
      assert sender == @sender_pubkey
    end

    test "receive_dm/2 with raw Event" do
      {:ok, gift_wraps} = NIP17.send_dm(@sender_seckey, [@recipient_pubkey], "Test")
      recipient_wrap = Enum.find(gift_wraps, &(&1.recipient == @recipient_pubkey))

      # Pass the raw event instead of GiftWrap struct
      {:ok, msg, _sender} = NIP17.receive_dm(recipient_wrap.event, @recipient_seckey)

      assert msg.content == "Test"
    end

    test "send_file/5 and receive_file/2 round trip" do
      file_url = "https://example.com/secret.enc"

      metadata = %{
        file_type: "application/pdf",
        encryption_algorithm: "aes-gcm",
        decryption_key: "supersecretkey",
        decryption_nonce: "randomnonce",
        hash: "sha256hash"
      }

      {:ok, gift_wraps} =
        NIP17.send_file(@sender_seckey, [@recipient_pubkey], file_url, metadata)

      recipient_wrap = Enum.find(gift_wraps, &(&1.recipient == @recipient_pubkey))
      {:ok, file_msg, sender} = NIP17.receive_file(recipient_wrap, @recipient_seckey)

      assert file_msg.file_url == file_url
      assert file_msg.file_type == "application/pdf"
      assert file_msg.decryption_key == "supersecretkey"
      assert sender == @sender_pubkey
    end

    test "receive_message/2 handles kind 14" do
      {:ok, gift_wraps} = NIP17.send_dm(@sender_seckey, [@recipient_pubkey], "Text message")
      recipient_wrap = Enum.find(gift_wraps, &(&1.recipient == @recipient_pubkey))

      {:ok, msg, _sender} = NIP17.receive_message(recipient_wrap, @recipient_seckey)

      assert %PrivateMessage{} = msg
      assert msg.content == "Text message"
    end

    test "receive_message/2 handles kind 15" do
      metadata = %{
        file_type: "image/png",
        encryption_algorithm: "aes-gcm",
        decryption_key: "key",
        decryption_nonce: "nonce",
        hash: "hash"
      }

      {:ok, gift_wraps} =
        NIP17.send_file(@sender_seckey, [@recipient_pubkey], "https://file.com/x", metadata)

      recipient_wrap = Enum.find(gift_wraps, &(&1.recipient == @recipient_pubkey))

      {:ok, msg, _sender} = NIP17.receive_message(recipient_wrap, @recipient_seckey)

      assert %FileMessage{} = msg
      assert msg.file_url == "https://file.com/x"
    end
  end

  describe "Parser routing" do
    test "parse_specific routes kind 14 to PrivateMessage" do
      event = Fixtures.signed_event(kind: 14, content: "Test")
      parsed = Event.Parser.parse_specific(event)

      assert %PrivateMessage{} = parsed
    end

    test "parse_specific routes kind 15 to FileMessage" do
      tags = [
        Tag.create(:"file-type", "image/jpeg"),
        Tag.create(:"encryption-algorithm", "aes-gcm"),
        Tag.create(:"decryption-key", "key"),
        Tag.create(:"decryption-nonce", "nonce"),
        Tag.create(:x, "hash")
      ]

      event = Fixtures.signed_event(kind: 15, content: "https://file.com", tags: tags)
      parsed = Event.Parser.parse_specific(event)

      assert %FileMessage{} = parsed
    end

    test "parse_specific routes kind 10_050 to DMRelayList" do
      tags = [Tag.create(:relay, "wss://relay.example.com")]
      event = Fixtures.signed_event(kind: 10_050, content: "", tags: tags)
      parsed = Event.Parser.parse_specific(event)

      assert %DMRelayList{} = parsed
    end
  end

  describe "full NIP-17 workflow" do
    test "complete DM conversation flow" do
      # Alice sends a message to Bob
      {:ok, alice_wraps} = NIP17.send_dm(@sender_seckey, [@recipient_pubkey], "Hi Bob!")

      # Bob receives and reads the message
      bob_wrap = Enum.find(alice_wraps, &(&1.recipient == @recipient_pubkey))
      {:ok, msg1, alice_pubkey} = NIP17.receive_dm(bob_wrap, @recipient_seckey)

      assert msg1.content == "Hi Bob!"
      assert alice_pubkey == @sender_pubkey

      # Bob replies to Alice
      {:ok, bob_wraps} =
        NIP17.send_dm(@recipient_seckey, [@sender_pubkey], "Hey Alice!", reply_to: msg1.rumor.id)

      # Alice receives Bob's reply
      alice_wrap = Enum.find(bob_wraps, &(&1.recipient == @sender_pubkey))
      {:ok, msg2, bob_pubkey} = NIP17.receive_dm(alice_wrap, @sender_seckey)

      assert msg2.content == "Hey Alice!"
      assert msg2.reply_to == msg1.rumor.id
      assert bob_pubkey == @recipient_pubkey

      # Alice can also read her own sent message from her sent folder
      alice_sent_wrap = Enum.find(alice_wraps, &(&1.recipient == @sender_pubkey))
      {:ok, sent_msg, _extra} = NIP17.receive_dm(alice_sent_wrap, @sender_seckey)
      assert sent_msg.content == "Hi Bob!"
    end
  end
end
