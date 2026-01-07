defmodule Nostr.SpecificEventsTest do
  use ExUnit.Case, async: true

  alias Nostr.Test.Fixtures

  doctest Nostr.Event.Metadata
  doctest Nostr.Event.Note

  describe "Nostr.Event.Note" do
    test "parses note with content" do
      event = Fixtures.signed_event(kind: 1, content: "Hello World")
      note = Nostr.Event.Note.parse(event)

      assert %Nostr.Event.Note{} = note
      assert note.note == "Hello World"
      assert note.author == Fixtures.pubkey()
    end

    test "extracts reply_to from e tags" do
      tags = [
        Nostr.Tag.create(:e, "event1"),
        Nostr.Tag.create(:e, "event2")
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Nostr.Event.Note.parse(event)

      assert note.reply_to == ["event1", "event2"]
    end

    test "extracts reply_to_authors from p tags" do
      tags = [
        Nostr.Tag.create(:p, "pubkey1"),
        Nostr.Tag.create(:p, "pubkey2")
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Nostr.Event.Note.parse(event)

      assert note.reply_to_authors == ["pubkey1", "pubkey2"]
    end

    test "handles empty tags" do
      event = Fixtures.signed_event(kind: 1, tags: [])
      note = Nostr.Event.Note.parse(event)

      assert note.reply_to == []
      assert note.reply_to_authors == []
    end

    test "create/2 creates note event" do
      note = Nostr.Event.Note.create("Test note")
      assert note.note == "Test note"
      assert note.event.kind == 1
    end
  end

  describe "Nostr.Event.Metadata" do
    test "parses metadata with all fields" do
      content =
        ~s({"name":"Alice","about":"Developer","picture":"https://example.com/pic.jpg","nip05":"alice@example.com"})

      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Nostr.Event.Metadata.parse(event)

      assert %Nostr.Event.Metadata{} = meta
      assert meta.name == "Alice"
      assert meta.about == "Developer"
      assert meta.picture.host == "example.com"
      assert meta.nip05 == "alice@example.com"
    end

    test "parses metadata with minimal fields" do
      content = ~s({"name":"Bob"})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Nostr.Event.Metadata.parse(event)

      assert meta.name == "Bob"
      assert meta.about == nil
    end

    test "captures extra fields in other" do
      content =
        ~s({"name":"Carol","lud16":"carol@wallet.com","banner":"https://example.com/banner.jpg"})

      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Nostr.Event.Metadata.parse(event)

      assert meta.other["lud16"] == "carol@wallet.com"
      assert meta.other["banner"] == "https://example.com/banner.jpg"
    end

    test "returns error for invalid JSON content" do
      event = Fixtures.signed_event(kind: 0, content: "not json")
      result = Nostr.Event.Metadata.parse(event)

      assert {:error, "Cannot decode content field", _} = result
    end

    test "create/5 creates metadata event" do
      meta =
        Nostr.Event.Metadata.create(
          "Alice",
          "About me",
          "https://pic.com/a.jpg",
          "alice@example.com"
        )

      assert meta.name == "Alice"
      assert meta.about == "About me"
      assert meta.event.kind == 0
    end
  end

  describe "Nostr.Event.DirectMessage" do
    test "parses DM with recipient" do
      tags = [Nostr.Tag.create(:p, Fixtures.pubkey2())]
      event = Fixtures.signed_event(kind: 4, content: "encrypted content", tags: tags)
      dm = Nostr.Event.DirectMessage.parse(event)

      assert %Nostr.Event.DirectMessage{} = dm
      assert dm.from == Fixtures.pubkey()
      assert dm.to == Fixtures.pubkey2()
      assert dm.cipher_text == "encrypted content"
      assert dm.plain_text == :not_decrypted
    end

    @tag :ecdh
    test "decrypt/2 decrypts message for sender" do
      message = "Secret message"
      encrypted = Nostr.Crypto.encrypt(message, Fixtures.seckey(), Fixtures.pubkey2())

      tags = [Nostr.Tag.create(:p, Fixtures.pubkey2())]
      event = Fixtures.signed_event(kind: 4, content: encrypted, tags: tags)
      dm = Nostr.Event.DirectMessage.parse(event)

      decrypted_dm = Nostr.Event.DirectMessage.decrypt(dm, Fixtures.seckey())
      assert decrypted_dm.plain_text == message
    end

    @tag :ecdh
    test "decrypt/2 decrypts message for recipient" do
      message = "Secret message"
      encrypted = Nostr.Crypto.encrypt(message, Fixtures.seckey(), Fixtures.pubkey2())

      tags = [Nostr.Tag.create(:p, Fixtures.pubkey2())]
      event = Fixtures.signed_event(kind: 4, content: encrypted, tags: tags)
      dm = Nostr.Event.DirectMessage.parse(event)

      decrypted_dm = Nostr.Event.DirectMessage.decrypt(dm, Fixtures.seckey2())
      assert decrypted_dm.plain_text == message
    end

    @tag :ecdh
    test "decrypt/2 returns not_decrypted for wrong key" do
      tags = [Nostr.Tag.create(:p, Fixtures.pubkey2())]
      encrypted = Nostr.Crypto.encrypt("test", Fixtures.seckey(), Fixtures.pubkey2())
      event = Fixtures.signed_event(kind: 4, content: encrypted, tags: tags)
      dm = Nostr.Event.DirectMessage.parse(event)

      # Use a third key that's neither sender nor recipient
      third_key = "3333333333333333333333333333333333333333333333333333333333333333"
      result = Nostr.Event.DirectMessage.decrypt(dm, third_key)
      assert result.plain_text == :not_decrypted
    end
  end

  describe "Nostr.Event.Contacts" do
    test "parses contact list" do
      tags = [
        Nostr.Tag.create(:p, "pubkey1", ["wss://relay1.com", "alice"]),
        Nostr.Tag.create(:p, "pubkey2", ["wss://relay2.com"]),
        Nostr.Tag.create(:p, "pubkey3")
      ]

      event = Fixtures.signed_event(kind: 3, tags: tags)
      contacts = Nostr.Event.Contacts.parse(event)

      assert %Nostr.Event.Contacts{} = contacts
      assert length(contacts.contacts) == 3

      [c1, c2, c3] = contacts.contacts
      assert c1.user == "pubkey1"
      assert c1.relay.host == "relay1.com"
      assert c1.petname == "alice"

      assert c2.user == "pubkey2"
      assert c2.relay.host == "relay2.com"
      refute Map.has_key?(c2, :petname)

      assert c3.user == "pubkey3"
      refute Map.has_key?(c3, :relay)
    end

    test "handles empty contact list" do
      event = Fixtures.signed_event(kind: 3, tags: [])
      contacts = Nostr.Event.Contacts.parse(event)
      assert contacts.contacts == []
    end
  end

  describe "Nostr.Event.Deletion" do
    test "parses deletion request" do
      tags = [
        Nostr.Tag.create(:e, "event_to_delete1"),
        Nostr.Tag.create(:e, "event_to_delete2")
      ]

      event = Fixtures.signed_event(kind: 5, tags: tags)
      deletion = Nostr.Event.Deletion.parse(event)

      assert %Nostr.Event.Deletion{} = deletion
      assert deletion.to_delete == ["event_to_delete1", "event_to_delete2"]
    end

    test "handles empty deletion list" do
      event = Fixtures.signed_event(kind: 5, tags: [])
      deletion = Nostr.Event.Deletion.parse(event)
      assert deletion.to_delete == []
    end
  end

  describe "Nostr.Event.Reaction" do
    test "parses reaction with like" do
      tags = [
        Nostr.Tag.create(:e, "reacted_event"),
        Nostr.Tag.create(:p, "author_pubkey")
      ]

      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      reaction = Nostr.Event.Reaction.parse(event)

      assert %Nostr.Event.Reaction{} = reaction
      assert reaction.reaction == "+"
      assert reaction.post == "reacted_event"
      assert reaction.author == "author_pubkey"
    end

    test "returns error when missing e tag" do
      tags = [Nostr.Tag.create(:p, "pubkey")]
      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      result = Nostr.Event.Reaction.parse(event)

      assert {:error, "Cannot find post tag", _} = result
    end

    test "returns error when missing p tag" do
      tags = [Nostr.Tag.create(:e, "event")]
      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      result = Nostr.Event.Reaction.parse(event)

      assert {:error, "Cannot find post author tag", _} = result
    end
  end

  describe "Nostr.Event.RecommendRelay" do
    test "parses relay recommendation" do
      event = Fixtures.signed_event(kind: 2, content: "wss://relay.example.com")
      relay = Nostr.Event.RecommendRelay.parse(event)

      assert %Nostr.Event.RecommendRelay{} = relay
      assert relay.relay.host == "relay.example.com"
      assert relay.relay.scheme == "wss"
    end
  end

  describe "Event kind ranges" do
    test "Regular events (1000-9999)" do
      event = Fixtures.signed_event(kind: 5000)
      regular = Nostr.Event.Regular.parse(event)

      assert %Nostr.Event.Regular{} = regular
      assert regular.event.kind == 5000
    end

    test "Replaceable events (10000-19999)" do
      event = Fixtures.signed_event(kind: 15000)
      replaceable = Nostr.Event.Replaceable.parse(event)

      assert %Nostr.Event.Replaceable{} = replaceable
      assert replaceable.user == Fixtures.pubkey()
    end

    test "Ephemeral events (20000-29999)" do
      event = Fixtures.signed_event(kind: 25000)
      ephemeral = Nostr.Event.Ephemeral.parse(event)

      assert %Nostr.Event.Ephemeral{} = ephemeral
      assert ephemeral.user == Fixtures.pubkey()
    end

    test "Parameterized replaceable events (30000-39999)" do
      tags = [Nostr.Tag.create(:d, "identifier")]
      event = Fixtures.signed_event(kind: 35000, tags: tags)
      param = Nostr.Event.ParameterizedReplaceable.parse(event)

      assert %Nostr.Event.ParameterizedReplaceable{} = param
      assert param.d == "identifier"
    end

    test "Parameterized replaceable with empty d tag" do
      tags = [Nostr.Tag.create(:d, nil)]
      event = Fixtures.signed_event(kind: 35000, tags: tags)
      param = Nostr.Event.ParameterizedReplaceable.parse(event)

      assert param.d == ""
    end

    test "Parameterized replaceable without d tag" do
      event = Fixtures.signed_event(kind: 35000, tags: [])
      param = Nostr.Event.ParameterizedReplaceable.parse(event)

      assert param.d == ""
    end
  end

  describe "Nostr.Event.Unknown" do
    test "wraps unknown event kinds" do
      event = Fixtures.signed_event(kind: 99999)
      unknown = %Nostr.Event.Unknown{event: event}

      assert unknown.event.kind == 99999
    end
  end
end
