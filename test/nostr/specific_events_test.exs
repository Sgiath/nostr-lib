defmodule Nostr.SpecificEventsTest do
  use ExUnit.Case, async: true

  alias Nostr.Test.Fixtures

  doctest Nostr.Event.Metadata
  doctest Nostr.Event.Note

  describe "Nostr.Event.Note" do
    alias Nostr.Event.Note

    test "parses note with content" do
      event = Fixtures.signed_event(kind: 1, content: "Hello World")
      note = Note.parse(event)

      assert %Note{} = note
      assert note.note == "Hello World"
      assert note.author == Fixtures.pubkey()
    end

    test "handles empty tags" do
      event = Fixtures.signed_event(kind: 1, tags: [])
      note = Note.parse(event)

      assert note.root == nil
      assert note.reply_to == nil
      assert note.mentions == []
      assert note.quotes == []
      assert note.participants == []
      assert note.is_legacy_format == true
    end

    test "extracts participants from p tags" do
      tags = [
        Nostr.Tag.create(:p, "pubkey1"),
        Nostr.Tag.create(:p, "pubkey2")
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.participants == ["pubkey1", "pubkey2"]
    end

    test "create/2 creates note event" do
      note = Note.create("Test note")
      assert note.note == "Test note"
      assert note.event.kind == 1
    end
  end

  describe "Nostr.Event.Note NIP-10 marked e-tags" do
    alias Nostr.Event.Note

    test "parses single root tag (top-level reply)" do
      tags = [
        Nostr.Tag.create(:e, "root_event", ["wss://relay.example.com", "root"])
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.root.id == "root_event"
      assert note.root.marker == :root
      assert note.root.relay == "wss://relay.example.com"
      assert note.reply_to == nil
      assert note.mentions == []
      assert note.is_legacy_format == false
    end

    test "parses root + reply tags (nested reply)" do
      tags = [
        Nostr.Tag.create(:e, "root_event", ["wss://relay1.com", "root"]),
        Nostr.Tag.create(:e, "parent_event", ["wss://relay2.com", "reply"])
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.root.id == "root_event"
      assert note.root.marker == :root
      assert note.reply_to.id == "parent_event"
      assert note.reply_to.marker == :reply
      assert note.mentions == []
      assert note.is_legacy_format == false
    end

    test "parses e tags without markers as mentions" do
      tags = [
        Nostr.Tag.create(:e, "root_event", ["", "root"]),
        Nostr.Tag.create(:e, "mentioned_event", [""]),
        Nostr.Tag.create(:e, "another_mention")
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.root.id == "root_event"
      assert note.reply_to == nil
      assert length(note.mentions) == 2
      assert Enum.any?(note.mentions, &(&1.id == "mentioned_event"))
      assert Enum.any?(note.mentions, &(&1.id == "another_mention"))
    end

    test "extracts relay hints from e tags" do
      tags = [
        Nostr.Tag.create(:e, "event1", ["wss://relay.example.com", "root"])
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.root.relay == "wss://relay.example.com"
    end

    test "extracts pubkey hints from e tags" do
      tags = [
        Nostr.Tag.create(:e, "event1", ["wss://relay.example.com", "root", "author123"])
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.root.pubkey == "author123"
    end

    test "handles empty relay hint" do
      tags = [
        Nostr.Tag.create(:e, "event1", ["", "root"])
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.root.relay == nil
    end
  end

  describe "Nostr.Event.Note NIP-10 positional e-tags (deprecated)" do
    alias Nostr.Event.Note

    test "no e tags = not a reply" do
      event = Fixtures.signed_event(kind: 1, tags: [])
      note = Note.parse(event)

      assert note.root == nil
      assert note.reply_to == nil
      assert note.mentions == []
      assert note.is_legacy_format == true
    end

    test "one e tag = reply to that event (as root)" do
      tags = [Nostr.Tag.create(:e, "only_event")]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.root.id == "only_event"
      assert note.reply_to == nil
      assert note.mentions == []
      assert note.is_legacy_format == true
    end

    test "two e tags = [root, reply]" do
      tags = [
        Nostr.Tag.create(:e, "root_event"),
        Nostr.Tag.create(:e, "reply_event")
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.root.id == "root_event"
      assert note.reply_to.id == "reply_event"
      assert note.mentions == []
      assert note.is_legacy_format == true
    end

    test "many e tags = [root, mentions..., reply]" do
      tags = [
        Nostr.Tag.create(:e, "root_event"),
        Nostr.Tag.create(:e, "mention1"),
        Nostr.Tag.create(:e, "mention2"),
        Nostr.Tag.create(:e, "reply_event")
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert note.root.id == "root_event"
      assert note.reply_to.id == "reply_event"
      assert length(note.mentions) == 2
      assert Enum.any?(note.mentions, &(&1.id == "mention1"))
      assert Enum.any?(note.mentions, &(&1.id == "mention2"))
      assert note.is_legacy_format == true
    end
  end

  describe "Nostr.Event.Note q tags (quotes)" do
    alias Nostr.Event.Note

    test "parses q tags with full info" do
      tags = [
        Nostr.Tag.create(:q, "quoted_event", ["wss://relay.example.com", "quoted_author"])
      ]

      event = Fixtures.signed_event(kind: 1, content: "Check this: nostr:nevent1...", tags: tags)
      note = Note.parse(event)

      assert length(note.quotes) == 1
      [quote] = note.quotes
      assert quote.id == "quoted_event"
      assert quote.relay == "wss://relay.example.com"
      assert quote.pubkey == "quoted_author"
    end

    test "parses q tags with only id" do
      tags = [Nostr.Tag.create(:q, "quoted_event")]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert length(note.quotes) == 1
      [quote] = note.quotes
      assert quote.id == "quoted_event"
      assert quote.relay == nil
      assert quote.pubkey == nil
    end

    test "handles multiple q tags" do
      tags = [
        Nostr.Tag.create(:q, "quote1"),
        Nostr.Tag.create(:q, "quote2", ["wss://relay.com"])
      ]

      event = Fixtures.signed_event(kind: 1, tags: tags)
      note = Note.parse(event)

      assert length(note.quotes) == 2
    end
  end

  describe "Nostr.Event.Note create/2 with thread options" do
    alias Nostr.Event.Note

    test "creates note with root tag only (top-level reply)" do
      note = Note.create("My reply", root: %{id: "root123", relay: "wss://relay.com"})

      assert note.root.id == "root123"
      assert note.root.relay == "wss://relay.com"
      assert note.reply_to == nil

      # Check tag was created correctly
      e_tag = Enum.find(note.event.tags, &(&1.type == :e))
      assert e_tag.data == "root123"
      assert e_tag.info == ["wss://relay.com", "root"]
    end

    test "creates note with root + reply tags (nested reply)" do
      note =
        Note.create("Nested reply",
          root: %{id: "root123"},
          reply_to: %{id: "parent456", relay: "wss://relay.com", pubkey: "author789"}
        )

      assert note.root.id == "root123"
      assert note.reply_to.id == "parent456"

      # Check tags
      e_tags = Enum.filter(note.event.tags, &(&1.type == :e))
      assert length(e_tags) == 2

      root_tag = Enum.find(e_tags, &Enum.member?(&1.info, "root"))
      reply_tag = Enum.find(e_tags, &Enum.member?(&1.info, "reply"))

      assert root_tag.data == "root123"
      assert reply_tag.data == "parent456"
      assert reply_tag.info == ["wss://relay.com", "reply", "author789"]
    end

    test "includes participants as p tags" do
      note = Note.create("Hello!", participants: ["pubkey1", "pubkey2"])

      p_tags = Enum.filter(note.event.tags, &(&1.type == :p))
      assert length(p_tags) == 2
      pubkeys = Enum.map(p_tags, & &1.data)
      assert "pubkey1" in pubkeys
      assert "pubkey2" in pubkeys
    end

    test "creates note with quotes (q tags)" do
      note =
        Note.create("Check this: nostr:nevent1...",
          quotes: [%{id: "quoted123", relay: "wss://relay.com", pubkey: "author456"}]
        )

      q_tag = Enum.find(note.event.tags, &(&1.type == :q))
      assert q_tag.data == "quoted123"
      assert q_tag.info == ["wss://relay.com", "author456"]
    end
  end

  describe "Nostr.Event.Note reply/3 helper" do
    alias Nostr.Event.Note

    test "reply to root note uses only root marker" do
      root_note = Note.create("Original post", pubkey: Fixtures.pubkey())

      reply = Note.reply("I agree!", root_note, pubkey: Fixtures.pubkey2())

      assert reply.root.id == root_note.event.id
      assert reply.root.pubkey == root_note.author
      assert reply.reply_to == nil
      assert Note.is_top_level_reply?(reply)
    end

    test "reply to nested note uses root + reply markers" do
      root_note = Note.create("Original", pubkey: Fixtures.pubkey())
      first_reply = Note.reply("First reply", root_note, pubkey: Fixtures.pubkey2())
      nested_reply = Note.reply("Nested reply", first_reply)

      assert nested_reply.root.id == root_note.event.id
      assert nested_reply.reply_to.id == first_reply.event.id
      refute Note.is_top_level_reply?(nested_reply)
    end

    test "carries forward participants as p tags" do
      root_note = Note.create("Original", pubkey: Fixtures.pubkey())
      reply = Note.reply("Reply", root_note, pubkey: Fixtures.pubkey2())

      assert Fixtures.pubkey() in reply.participants
    end

    test "reply to event_ref map" do
      reply = Note.reply("Reply", %{id: "event123", relay: "wss://relay.com"})

      assert reply.root.id == "event123"
      assert reply.root.relay == "wss://relay.com"
    end
  end

  describe "Nostr.Event.Note quote_event/3 helper" do
    alias Nostr.Event.Note

    test "creates note with single q tag" do
      note = Note.quote_event("Check this!", %{id: "quoted123"})

      assert length(note.quotes) == 1
      assert hd(note.quotes).id == "quoted123"
    end

    test "creates note with multiple q tags" do
      note = Note.quote_event("Multiple quotes!", [%{id: "quote1"}, %{id: "quote2"}])

      assert length(note.quotes) == 2
    end

    test "includes relay and pubkey hints in q tags" do
      note =
        Note.quote_event("With hints!", %{
          id: "quoted123",
          relay: "wss://relay.com",
          pubkey: "author456"
        })

      q_tag = Enum.find(note.event.tags, &(&1.type == :q))
      assert q_tag.info == ["wss://relay.com", "author456"]
    end
  end

  describe "Nostr.Event.Note utility functions" do
    alias Nostr.Event.Note

    test "is_reply?/1 returns true for replies" do
      reply = Note.create("Reply", root: %{id: "root123"})
      assert Note.is_reply?(reply)
    end

    test "is_reply?/1 returns false for non-replies" do
      note = Note.create("Just a note")
      refute Note.is_reply?(note)
    end

    test "is_top_level_reply?/1 for top-level reply" do
      reply = Note.create("Top-level", root: %{id: "root123"})
      assert Note.is_top_level_reply?(reply)
    end

    test "is_top_level_reply?/1 for nested reply" do
      reply = Note.create("Nested", root: %{id: "root123"}, reply_to: %{id: "parent456"})
      refute Note.is_top_level_reply?(reply)
    end

    test "has_quotes?/1" do
      with_quotes = Note.quote_event("Quote!", %{id: "quoted"})
      without_quotes = Note.create("No quotes")

      assert Note.has_quotes?(with_quotes)
      refute Note.has_quotes?(without_quotes)
    end

    test "thread_root_id/1" do
      reply = Note.create("Reply", root: %{id: "root123"})
      plain_note = Note.create("Plain")

      assert Note.thread_root_id(reply) == "root123"
      assert Note.thread_root_id(plain_note) == nil
    end

    test "parent_id/1 returns reply_to if present" do
      note = Note.create("Nested", root: %{id: "root123"}, reply_to: %{id: "parent456"})
      assert Note.parent_id(note) == "parent456"
    end

    test "parent_id/1 falls back to root" do
      note = Note.create("Top-level", root: %{id: "root123"})
      assert Note.parent_id(note) == "root123"
    end

    test "parent_id/1 returns nil for non-reply" do
      note = Note.create("Plain")
      assert Note.parent_id(note) == nil
    end
  end

  describe "Nostr.Event.Note NIP-14 subject tag" do
    alias Nostr.Event.Note

    test "parses subject tag" do
      tags = [Nostr.Tag.create(:subject, "Meeting Notes")]
      event = Fixtures.signed_event(kind: 1, content: "Let's discuss", tags: tags)
      note = Note.parse(event)

      assert note.subject == "Meeting Notes"
    end

    test "handles missing subject tag" do
      event = Fixtures.signed_event(kind: 1, content: "No subject", tags: [])
      note = Note.parse(event)

      assert note.subject == nil
    end

    test "create/2 with subject option" do
      note = Note.create("Hello!", subject: "Introduction")

      assert note.subject == "Introduction"
      subject_tag = Enum.find(note.event.tags, &(&1.type == :subject))
      assert subject_tag.data == "Introduction"
    end

    test "create/2 without subject" do
      note = Note.create("Hello!")

      assert note.subject == nil
      subject_tag = Enum.find(note.event.tags, &(&1.type == :subject))
      assert subject_tag == nil
    end

    test "reply/3 replicates subject with Re: prefix" do
      parent = Note.create("Original", subject: "Discussion Topic", pubkey: Fixtures.pubkey())
      reply = Note.reply("My reply", parent)

      assert reply.subject == "Re: Discussion Topic"
    end

    test "reply/3 preserves existing Re: prefix" do
      parent =
        Note.create("First reply", subject: "Re: Discussion Topic", pubkey: Fixtures.pubkey())

      reply = Note.reply("Second reply", parent)

      assert reply.subject == "Re: Discussion Topic"
    end

    test "reply/3 allows explicit subject override" do
      parent = Note.create("Original", subject: "Discussion Topic", pubkey: Fixtures.pubkey())
      reply = Note.reply("New topic!", parent, subject: "Different Topic")

      assert reply.subject == "Different Topic"
    end

    test "reply/3 without parent subject" do
      parent = Note.create("Original without subject", pubkey: Fixtures.pubkey())
      reply = Note.reply("My reply", parent)

      assert reply.subject == nil
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
        ~s({"name":"Carol","lud16":"carol@wallet.com","lud06":"lnurl..."})

      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Nostr.Event.Metadata.parse(event)

      assert meta.other["lud16"] == "carol@wallet.com"
      assert meta.other["lud06"] == "lnurl..."
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

  describe "Nostr.Event.Metadata NIP-24 extra fields" do
    alias Nostr.Event.Metadata

    test "parses display_name field" do
      content = ~s({"name":"alice","display_name":"Alice Wonderland"})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.name == "alice"
      assert meta.display_name == "Alice Wonderland"
    end

    test "parses deprecated displayName as display_name" do
      content = ~s({"name":"alice","displayName":"Alice Wonderland"})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.display_name == "Alice Wonderland"
    end

    test "parses deprecated username as name" do
      content = ~s({"username":"alice"})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.name == "alice"
    end

    test "prefers name over deprecated username" do
      content = ~s({"name":"alice","username":"old_alice"})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.name == "alice"
    end

    test "parses website as URI" do
      content = ~s({"name":"alice","website":"https://alice.example.com"})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.website.host == "alice.example.com"
      assert meta.website.scheme == "https"
    end

    test "parses banner as URI" do
      content = ~s({"name":"alice","banner":"https://example.com/banner.jpg"})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.banner.host == "example.com"
      assert meta.banner.path == "/banner.jpg"
    end

    test "parses bot boolean" do
      content = ~s({"name":"newsbot","bot":true})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.bot == true
    end

    test "parses birthday object with all fields" do
      content = ~s({"name":"alice","birthday":{"year":1990,"month":1,"day":15}})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.birthday.year == 1990
      assert meta.birthday.month == 1
      assert meta.birthday.day == 15
    end

    test "parses partial birthday (year only)" do
      content = ~s({"name":"alice","birthday":{"year":1990}})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.birthday.year == 1990
      assert meta.birthday.month == nil
      assert meta.birthday.day == nil
    end

    test "handles missing NIP-24 fields" do
      content = ~s({"name":"alice"})
      event = Fixtures.signed_event(kind: 0, content: content)
      meta = Metadata.parse(event)

      assert meta.display_name == nil
      assert meta.website == nil
      assert meta.banner == nil
      assert meta.bot == nil
      assert meta.birthday == nil
    end

    test "create/5 with NIP-24 options" do
      meta =
        Metadata.create("alice", "About me", "https://pic.com/a.jpg", "alice@example.com",
          display_name: "Alice Wonderland",
          website: "https://alice.example.com",
          banner: "https://example.com/banner.jpg",
          bot: false,
          birthday: %{year: 1990, month: 1, day: 15}
        )

      assert meta.display_name == "Alice Wonderland"
      assert meta.website.host == "alice.example.com"
      assert meta.banner.path == "/banner.jpg"
      assert meta.bot == false
      assert meta.birthday.year == 1990
    end

    test "create/5 with URI for website and banner" do
      meta =
        Metadata.create("alice", "About", nil, nil,
          website: URI.parse("https://alice.example.com"),
          banner: URI.parse("https://example.com/banner.jpg")
        )

      assert meta.website.host == "alice.example.com"
      assert meta.banner.host == "example.com"
    end

    test "create/5 with partial birthday" do
      meta = Metadata.create("alice", nil, nil, nil, birthday: %{year: 1990})

      assert meta.birthday.year == 1990
      assert meta.birthday.month == nil
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

    test "parses DM with p tag not first (reply thread)" do
      tags = [
        Nostr.Tag.create(:e, "previous_event_id"),
        Nostr.Tag.create(:p, Fixtures.pubkey2())
      ]

      event = Fixtures.signed_event(kind: 4, content: "encrypted", tags: tags)
      dm = Nostr.Event.DirectMessage.parse(event)

      assert dm.to == Fixtures.pubkey2()
    end

    @tag :ecdh
    test "create/4 creates encrypted DM" do
      dm =
        Nostr.Event.DirectMessage.create(
          "Hello, secret message!",
          Fixtures.seckey(),
          Fixtures.pubkey2()
        )

      assert %Nostr.Event.DirectMessage{} = dm
      assert dm.event.kind == 4
      assert dm.from == Fixtures.pubkey()
      assert dm.to == Fixtures.pubkey2()
      assert dm.plain_text == "Hello, secret message!"
      assert dm.cipher_text =~ "?iv="
    end

    @tag :ecdh
    test "create/4 with reply_to option" do
      dm =
        Nostr.Event.DirectMessage.create(
          "Reply message",
          Fixtures.seckey(),
          Fixtures.pubkey2(),
          reply_to: "previous_event_id"
        )

      assert dm.event.kind == 4
      e_tag = Enum.find(dm.event.tags, &(&1.type == :e))
      assert e_tag.data == "previous_event_id"
    end

    @tag :ecdh
    test "create/4 message can be decrypted by recipient" do
      dm =
        Nostr.Event.DirectMessage.create(
          "Secret for recipient",
          Fixtures.seckey(),
          Fixtures.pubkey2()
        )

      # Parse fresh from event (simulating recipient receiving it)
      received = Nostr.Event.DirectMessage.parse(dm.event)
      decrypted = Nostr.Event.DirectMessage.decrypt(received, Fixtures.seckey2())

      assert decrypted.plain_text == "Secret for recipient"
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

    test "create/2 creates contact list event" do
      contacts =
        Nostr.Event.Contacts.create([
          %{user: "pubkey1", relay: "wss://relay1.com", petname: "alice"},
          %{user: "pubkey2", relay: "wss://relay2.com"},
          %{user: "pubkey3"}
        ])

      assert %Nostr.Event.Contacts{} = contacts
      assert contacts.event.kind == 3
      assert contacts.event.content == ""
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

    test "create/2 with empty list" do
      contacts = Nostr.Event.Contacts.create([])

      assert %Nostr.Event.Contacts{} = contacts
      assert contacts.event.kind == 3
      assert contacts.contacts == []
    end
  end

  describe "Nostr.Event.Deletion" do
    test "parses deletion request with e tags" do
      tags = [
        Nostr.Tag.create(:e, "event_to_delete1"),
        Nostr.Tag.create(:e, "event_to_delete2")
      ]

      event = Fixtures.signed_event(kind: 5, tags: tags)
      deletion = Nostr.Event.Deletion.parse(event)

      assert %Nostr.Event.Deletion{} = deletion
      assert deletion.to_delete == ["event_to_delete1", "event_to_delete2"]
    end

    test "parses deletion request with a tags (replaceable events)" do
      tags = [
        Nostr.Tag.create(:a, "30023:pubkey123:article-slug"),
        Nostr.Tag.create(:a, "10000:pubkey456:settings")
      ]

      event = Fixtures.signed_event(kind: 5, tags: tags)
      deletion = Nostr.Event.Deletion.parse(event)

      assert deletion.to_delete_naddr == [
               "30023:pubkey123:article-slug",
               "10000:pubkey456:settings"
             ]
    end

    test "parses deletion request with k tags (kinds)" do
      tags = [
        Nostr.Tag.create(:e, "event1"),
        Nostr.Tag.create(:k, "1"),
        Nostr.Tag.create(:k, "30023")
      ]

      event = Fixtures.signed_event(kind: 5, tags: tags)
      deletion = Nostr.Event.Deletion.parse(event)

      assert deletion.kinds == [1, 30023]
    end

    test "parses deletion reason from content" do
      event = Fixtures.signed_event(kind: 5, content: "posted by mistake", tags: [])
      deletion = Nostr.Event.Deletion.parse(event)

      assert deletion.reason == "posted by mistake"
    end

    test "handles empty deletion list" do
      event = Fixtures.signed_event(kind: 5, content: "", tags: [])
      deletion = Nostr.Event.Deletion.parse(event)

      assert deletion.to_delete == []
      assert deletion.to_delete_naddr == []
      assert deletion.kinds == []
      assert deletion.reason == nil
    end

    test "create/2 creates deletion request" do
      deletion =
        Nostr.Event.Deletion.create(
          ["event1", "event2"],
          reason: "test deletion",
          kinds: [1]
        )

      assert %Nostr.Event.Deletion{} = deletion
      assert deletion.event.kind == 5
      assert deletion.to_delete == ["event1", "event2"]
      assert deletion.kinds == [1]
      assert deletion.reason == "test deletion"
    end

    test "create/2 with replaceable events (a tags)" do
      deletion =
        Nostr.Event.Deletion.create(
          [],
          naddrs: ["30023:pubkey:article"],
          kinds: [30023]
        )

      assert deletion.to_delete_naddr == ["30023:pubkey:article"]
      assert deletion.kinds == [30023]
    end

    test "create/2 with no options" do
      deletion = Nostr.Event.Deletion.create(["event1"])

      assert deletion.to_delete == ["event1"]
      assert deletion.reason == nil
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

    test "parses reaction with relay hint" do
      tags = [
        Nostr.Tag.create(:e, "reacted_event", ["wss://relay.example.com", "author_pubkey"]),
        Nostr.Tag.create(:p, "author_pubkey", ["wss://relay.example.com"])
      ]

      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      reaction = Nostr.Event.Reaction.parse(event)

      assert reaction.relay_hint == "wss://relay.example.com"
    end

    test "parses reaction with k tag (kind of reacted event)" do
      tags = [
        Nostr.Tag.create(:e, "reacted_event"),
        Nostr.Tag.create(:p, "author_pubkey"),
        Nostr.Tag.create(:k, "1")
      ]

      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      reaction = Nostr.Event.Reaction.parse(event)

      assert reaction.kind == 1
    end

    test "parses reaction with a tag (addressable event)" do
      tags = [
        Nostr.Tag.create(:e, "reacted_event"),
        Nostr.Tag.create(:p, "author_pubkey"),
        Nostr.Tag.create(:a, "30023:pubkey:article-slug", ["wss://relay.example.com"])
      ]

      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      reaction = Nostr.Event.Reaction.parse(event)

      assert reaction.address == "30023:pubkey:article-slug"
    end

    test "parses custom emoji reaction" do
      tags = [
        Nostr.Tag.create(:e, "reacted_event"),
        Nostr.Tag.create(:p, "author_pubkey"),
        Nostr.Tag.create(:emoji, "soapbox", ["https://example.com/soapbox.png"])
      ]

      event = Fixtures.signed_event(kind: 7, content: ":soapbox:", tags: tags)
      reaction = Nostr.Event.Reaction.parse(event)

      assert reaction.reaction == ":soapbox:"
      assert reaction.emoji_url == "https://example.com/soapbox.png"
    end

    test "uses last e tag when multiple e tags exist (per NIP-25)" do
      tags = [
        Nostr.Tag.create(:e, "first_event"),
        Nostr.Tag.create(:e, "target_event")
      ]

      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      reaction = Nostr.Event.Reaction.parse(event)

      assert reaction.post == "target_event"
    end

    test "uses last p tag when multiple p tags exist (per NIP-25)" do
      tags = [
        Nostr.Tag.create(:e, "event"),
        Nostr.Tag.create(:p, "first_author"),
        Nostr.Tag.create(:p, "target_author")
      ]

      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      reaction = Nostr.Event.Reaction.parse(event)

      assert reaction.author == "target_author"
    end

    test "p tag is optional (author is nil when missing)" do
      tags = [Nostr.Tag.create(:e, "event")]
      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      reaction = Nostr.Event.Reaction.parse(event)

      assert %Nostr.Event.Reaction{} = reaction
      assert reaction.author == nil
      assert reaction.post == "event"
    end

    test "returns error when missing e tag" do
      tags = [Nostr.Tag.create(:p, "pubkey")]
      event = Fixtures.signed_event(kind: 7, content: "+", tags: tags)
      result = Nostr.Event.Reaction.parse(event)

      assert {:error, "Cannot find post tag", _} = result
    end

    test "create/3 creates basic like reaction" do
      reaction = Nostr.Event.Reaction.create("event_id", "+", author: "author_pubkey")

      assert %Nostr.Event.Reaction{} = reaction
      assert reaction.event.kind == 7
      assert reaction.reaction == "+"
      assert reaction.post == "event_id"
      assert reaction.author == "author_pubkey"
    end

    test "create/3 with relay hint and kind" do
      reaction =
        Nostr.Event.Reaction.create("event_id", "+",
          author: "author_pubkey",
          relay_hint: "wss://relay.example.com",
          kind: 1
        )

      assert reaction.relay_hint == "wss://relay.example.com"
      assert reaction.kind == 1

      # Verify tags are correctly formed
      e_tag = Enum.find(reaction.event.tags, &(&1.type == :e))
      assert e_tag.info == ["wss://relay.example.com", "author_pubkey"]

      k_tag = Enum.find(reaction.event.tags, &(&1.type == :k))
      assert k_tag.data == "1"
    end

    test "create/3 with addressable event" do
      reaction =
        Nostr.Event.Reaction.create("event_id", "+",
          author: "author_pubkey",
          address: "30023:pubkey:article"
        )

      assert reaction.address == "30023:pubkey:article"
    end

    test "create/3 with custom emoji" do
      reaction =
        Nostr.Event.Reaction.create("event_id", ":fire:",
          author: "author_pubkey",
          emoji_url: "https://example.com/fire.png"
        )

      assert reaction.reaction == ":fire:"
      assert reaction.emoji_url == "https://example.com/fire.png"

      emoji_tag = Enum.find(reaction.event.tags, &(&1.type == :emoji))
      assert emoji_tag.data == "fire"
      assert emoji_tag.info == ["https://example.com/fire.png"]
    end

    test "create/3 defaults to + reaction" do
      reaction = Nostr.Event.Reaction.create("event_id")

      assert reaction.reaction == "+"
    end
  end

  describe "Nostr.Event.ExternalReaction" do
    test "parses external reaction to website" do
      tags = [
        Nostr.Tag.create(:k, "web"),
        Nostr.Tag.create(:i, "https://example.com")
      ]

      event = Fixtures.signed_event(kind: 17, content: "⭐", tags: tags)
      reaction = Nostr.Event.ExternalReaction.parse(event)

      assert %Nostr.Event.ExternalReaction{} = reaction
      assert reaction.reaction == "⭐"
      assert reaction.content_type == "web"
      assert [%{id: "https://example.com", hint: nil}] = reaction.identifiers
    end

    test "parses external reaction with hint" do
      tags = [
        Nostr.Tag.create(:k, "podcast:guid"),
        Nostr.Tag.create(:i, "podcast:guid:12345", ["https://fountain.fm/show/abc"])
      ]

      event = Fixtures.signed_event(kind: 17, content: "+", tags: tags)
      reaction = Nostr.Event.ExternalReaction.parse(event)

      assert reaction.content_type == "podcast:guid"

      assert [%{id: "podcast:guid:12345", hint: "https://fountain.fm/show/abc"}] =
               reaction.identifiers
    end

    test "parses external reaction with multiple i tags" do
      tags = [
        Nostr.Tag.create(:k, "podcast:guid"),
        Nostr.Tag.create(:i, "podcast:guid:show123", ["https://example.com/show"]),
        Nostr.Tag.create(:k, "podcast:item:guid"),
        Nostr.Tag.create(:i, "podcast:item:guid:ep456", ["https://example.com/episode"])
      ]

      event = Fixtures.signed_event(kind: 17, content: "+", tags: tags)
      reaction = Nostr.Event.ExternalReaction.parse(event)

      assert length(reaction.identifiers) == 2
    end

    test "parses custom emoji in external reaction" do
      tags = [
        Nostr.Tag.create(:k, "web"),
        Nostr.Tag.create(:i, "https://example.com"),
        Nostr.Tag.create(:emoji, "fire", ["https://example.com/fire.png"])
      ]

      event = Fixtures.signed_event(kind: 17, content: ":fire:", tags: tags)
      reaction = Nostr.Event.ExternalReaction.parse(event)

      assert reaction.emoji_url == "https://example.com/fire.png"
    end

    test "returns error when missing i tag" do
      tags = [Nostr.Tag.create(:k, "web")]
      event = Fixtures.signed_event(kind: 17, content: "+", tags: tags)
      result = Nostr.Event.ExternalReaction.parse(event)

      assert {:error, "Cannot find external content identifier (i tag)", _} = result
    end

    test "create/4 creates external reaction" do
      reaction = Nostr.Event.ExternalReaction.create("web", "https://example.com", "⭐")

      assert %Nostr.Event.ExternalReaction{} = reaction
      assert reaction.event.kind == 17
      assert reaction.reaction == "⭐"
      assert reaction.content_type == "web"
      assert [%{id: "https://example.com", hint: nil}] = reaction.identifiers
    end

    test "create/4 with hint" do
      reaction =
        Nostr.Event.ExternalReaction.create(
          "podcast:guid",
          "podcast:guid:12345",
          "+",
          hint: "https://fountain.fm/show/abc"
        )

      assert [%{id: "podcast:guid:12345", hint: "https://fountain.fm/show/abc"}] =
               reaction.identifiers
    end

    test "create/4 with custom emoji" do
      reaction =
        Nostr.Event.ExternalReaction.create("web", "https://example.com", ":star:",
          emoji_url: "https://example.com/star.png"
        )

      assert reaction.emoji_url == "https://example.com/star.png"
    end

    test "create/4 defaults to + reaction" do
      reaction = Nostr.Event.ExternalReaction.create("web", "https://example.com")

      assert reaction.reaction == "+"
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

  describe "Nostr.Event.OpenTimestamps" do
    test "parses OTS attestation with all fields" do
      tags = [
        Nostr.Tag.create(:e, "target_event_id", ["wss://relay.example.com"]),
        Nostr.Tag.create(:k, "1")
      ]

      event = Fixtures.signed_event(kind: 1040, content: "base64otsdata", tags: tags)
      ots = Nostr.Event.OpenTimestamps.parse(event)

      assert %Nostr.Event.OpenTimestamps{} = ots
      assert ots.target_event == "target_event_id"
      assert ots.target_relay.host == "relay.example.com"
      assert ots.target_kind == 1
      assert ots.ots_data == "base64otsdata"
    end

    test "parses OTS attestation with minimal fields" do
      tags = [Nostr.Tag.create(:e, "target_event_id")]
      event = Fixtures.signed_event(kind: 1040, content: "base64otsdata", tags: tags)
      ots = Nostr.Event.OpenTimestamps.parse(event)

      assert %Nostr.Event.OpenTimestamps{} = ots
      assert ots.target_event == "target_event_id"
      assert ots.target_relay == nil
      assert ots.target_kind == nil
    end

    test "returns error when missing e tag" do
      tags = [Nostr.Tag.create(:k, "1")]
      event = Fixtures.signed_event(kind: 1040, content: "base64otsdata", tags: tags)
      result = Nostr.Event.OpenTimestamps.parse(event)

      assert {:error, "Cannot find target event tag", _} = result
    end

    test "create/3 creates OTS attestation event" do
      ots =
        Nostr.Event.OpenTimestamps.create(
          "target_event_id",
          "base64otsdata",
          target_relay: "wss://relay.example.com",
          target_kind: 1
        )

      assert %Nostr.Event.OpenTimestamps{} = ots
      assert ots.event.kind == 1040
      assert ots.target_event == "target_event_id"
      assert ots.target_relay.host == "relay.example.com"
      assert ots.target_kind == 1
      assert ots.ots_data == "base64otsdata"
    end

    test "create/3 with minimal options" do
      ots = Nostr.Event.OpenTimestamps.create("target_event_id", "base64otsdata")

      assert %Nostr.Event.OpenTimestamps{} = ots
      assert ots.event.kind == 1040
      assert ots.target_event == "target_event_id"
      assert ots.target_relay == nil
      assert ots.target_kind == nil
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
