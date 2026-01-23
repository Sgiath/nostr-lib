defmodule Nostr.NIP51Test do
  use ExUnit.Case, async: true

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag
  alias Nostr.Test.Fixtures

  describe "NIP51 encryption utilities" do
    test "detect_encryption_version/1 detects NIP-04" do
      nip04_ciphertext = "encrypted_content?iv=base64iv"
      assert NIP51.detect_encryption_version(nip04_ciphertext) == :nip04
    end

    test "detect_encryption_version/1 detects NIP-44" do
      nip44_ciphertext = "AgKK5encrypted_content_without_iv"
      assert NIP51.detect_encryption_version(nip44_ciphertext) == :nip44
    end

    test "encrypt_private_items/3 encrypts tags" do
      tags = [Tag.create(:p, "pubkey123"), Tag.create(:t, "nostr")]
      seckey = Fixtures.seckey()
      pubkey = Fixtures.pubkey()

      encrypted = NIP51.encrypt_private_items(tags, seckey, pubkey)
      assert is_binary(encrypted)
      refute encrypted == ""
    end

    test "decrypt_private_items/3 decrypts NIP-44 content" do
      tags = [Tag.create(:p, "pubkey123"), Tag.create(:t, "test")]
      seckey = Fixtures.seckey()
      pubkey = Fixtures.pubkey()

      encrypted = NIP51.encrypt_private_items(tags, seckey, pubkey)
      {:ok, decrypted} = NIP51.decrypt_private_items(encrypted, seckey, pubkey)

      assert length(decrypted) == 2
      assert Enum.at(decrypted, 0).type == :p
      assert Enum.at(decrypted, 0).data == "pubkey123"
      assert Enum.at(decrypted, 1).type == :t
      assert Enum.at(decrypted, 1).data == "test"
    end

    test "decrypt_private_items/3 handles empty content" do
      assert {:ok, []} = NIP51.decrypt_private_items("", Fixtures.seckey(), Fixtures.pubkey())
      assert {:ok, []} = NIP51.decrypt_private_items(nil, Fixtures.seckey(), Fixtures.pubkey())
    end

    test "get_tags_by_type/2 extracts tags" do
      event =
        Event.create(1,
          tags: [Tag.create(:p, "pk1"), Tag.create(:e, "ev1"), Tag.create(:p, "pk2")]
        )

      p_tags = NIP51.get_tags_by_type(event, :p)

      assert length(p_tags) == 2
      assert Enum.all?(p_tags, fn t -> t.type == :p end)
    end

    test "get_tag_values/2 extracts data values" do
      event =
        Event.create(1,
          tags: [Tag.create(:relay, "wss://r1.com"), Tag.create(:relay, "wss://r2.com")]
        )

      values = NIP51.get_tag_values(event, :relay)

      assert values == ["wss://r1.com", "wss://r2.com"]
    end

    test "get_identifier/1 extracts d tag" do
      event = Event.create(30_000, tags: [Tag.create(:d, "my-set")])
      assert NIP51.get_identifier(event) == "my-set"
    end

    test "get_set_metadata/1 extracts title, image, description" do
      event =
        Event.create(30_000,
          tags: [
            Tag.create(:title, "My Title"),
            Tag.create(:image, "https://example.com/img.png"),
            Tag.create(:description, "A description")
          ]
        )

      metadata = NIP51.get_set_metadata(event)
      assert metadata.title == "My Title"
      assert metadata.image == "https://example.com/img.png"
      assert metadata.description == "A description"
    end
  end

  describe "ListMute (kind 10000)" do
    alias Nostr.Event.ListMute

    test "create/1 with pubkeys list (backward compatible)" do
      mute = ListMute.create(["pk1", "pk2"])

      assert %ListMute{} = mute
      assert mute.event.kind == 10_000
      assert mute.pubkeys == ["pk1", "pk2"]
    end

    test "create/2 with full item types" do
      mute =
        ListMute.create(%{
          pubkeys: ["pk1"],
          hashtags: ["spam"],
          words: ["annoying"],
          threads: ["ev1"]
        })

      assert mute.pubkeys == ["pk1"]
      assert mute.hashtags == ["spam"]
      assert mute.words == ["annoying"]
      assert mute.threads == ["ev1"]
    end

    test "create/2 with private items" do
      seckey = Fixtures.seckey()

      mute =
        ListMute.create(
          %{
            pubkeys: ["public_pk"],
            private_pubkeys: ["private_pk"],
            private_words: ["secret_word"]
          },
          seckey: seckey
        )

      assert mute.pubkeys == ["public_pk"]
      assert mute.private_pubkeys == :not_loaded
      refute mute.event.content == ""
    end

    test "decrypt_private/2 decrypts private items" do
      seckey = Fixtures.seckey()
      pubkey = Fixtures.pubkey()

      mute =
        ListMute.create(
          %{
            pubkeys: ["public_pk"],
            private_pubkeys: ["private_pk"],
            private_words: ["secret"]
          },
          seckey: seckey,
          pubkey: pubkey
        )

      decrypted = ListMute.decrypt_private(mute, seckey)

      assert decrypted.pubkeys == ["public_pk"]
      assert decrypted.private_pubkeys == ["private_pk"]
      assert decrypted.private_words == ["secret"]
    end

    test "parse/1 parses event" do
      tags = [
        Tag.create(:p, "pk1"),
        Tag.create(:t, "hashtag"),
        Tag.create(:word, "word1"),
        Tag.create(:e, "ev1")
      ]

      event = Event.create(10_000, tags: tags)

      mute = ListMute.parse(event)

      assert mute.pubkeys == ["pk1"]
      assert mute.hashtags == ["hashtag"]
      assert mute.words == ["word1"]
      assert mute.threads == ["ev1"]
    end
  end

  describe "PinnedNotes (kind 10001)" do
    alias Nostr.Event.PinnedNotes

    test "create/1 creates pinned notes list" do
      pinned = PinnedNotes.create(["note1", "note2"])

      assert %PinnedNotes{} = pinned
      assert pinned.event.kind == 10_001
      assert pinned.notes == ["note1", "note2"]
    end

    test "parse/1 parses event" do
      event = Event.create(10_001, tags: [Tag.create(:e, "note1")])
      pinned = PinnedNotes.parse(event)

      assert pinned.notes == ["note1"]
    end
  end

  describe "RelayList (kind 10002)" do
    alias Nostr.Event.RelayList

    test "create/1 with simple URLs" do
      list = RelayList.create(["wss://relay1.com", "wss://relay2.com"])

      assert %RelayList{} = list
      assert list.event.kind == 10_002
      assert length(list.relays) == 2
      assert Enum.all?(list.relays, fn r -> r.marker == :both end)
    end

    test "create/1 with markers" do
      list =
        RelayList.create([
          "wss://both.com",
          {"wss://read.com", :read},
          {"wss://write.com", :write}
        ])

      both = Enum.find(list.relays, fn r -> r.url.host == "both.com" end)
      read = Enum.find(list.relays, fn r -> r.url.host == "read.com" end)
      write = Enum.find(list.relays, fn r -> r.url.host == "write.com" end)

      assert both.marker == :both
      assert read.marker == :read
      assert write.marker == :write
    end

    test "read_relays/1 returns read relays" do
      list =
        RelayList.create([
          {"wss://read.com", :read},
          {"wss://write.com", :write},
          "wss://both.com"
        ])

      read = RelayList.read_relays(list)
      hosts = Enum.map(read, & &1.host)

      assert "read.com" in hosts
      assert "both.com" in hosts
      refute "write.com" in hosts
    end

    test "write_relays/1 returns write relays" do
      list =
        RelayList.create([
          {"wss://read.com", :read},
          {"wss://write.com", :write},
          "wss://both.com"
        ])

      write = RelayList.write_relays(list)
      hosts = Enum.map(write, & &1.host)

      assert "write.com" in hosts
      assert "both.com" in hosts
      refute "read.com" in hosts
    end
  end

  describe "Bookmarks (kind 10003)" do
    alias Nostr.Event.Bookmarks

    test "create/2 with public bookmarks" do
      bookmarks =
        Bookmarks.create(%{
          notes: ["note1"],
          articles: ["30023:pk:article1"]
        })

      assert %Bookmarks{} = bookmarks
      assert bookmarks.event.kind == 10_003
      assert bookmarks.notes == ["note1"]
      assert bookmarks.articles == ["30023:pk:article1"]
    end

    test "create/2 with private bookmarks" do
      seckey = Fixtures.seckey()

      bookmarks =
        Bookmarks.create(
          %{
            notes: ["public_note"],
            private_notes: ["private_note"]
          },
          seckey: seckey
        )

      assert bookmarks.notes == ["public_note"]
      assert bookmarks.private_notes == :not_loaded
      refute bookmarks.event.content == ""
    end

    test "decrypt_private/2 decrypts private bookmarks" do
      seckey = Fixtures.seckey()
      pubkey = Fixtures.pubkey()

      bookmarks =
        Bookmarks.create(
          %{
            private_notes: ["secret_note"],
            private_articles: ["30023:pk:secret"]
          },
          seckey: seckey,
          pubkey: pubkey
        )

      decrypted = Bookmarks.decrypt_private(bookmarks, seckey)

      assert decrypted.private_notes == ["secret_note"]
      assert decrypted.private_articles == ["30023:pk:secret"]
    end
  end

  describe "BlockedRelays (kind 10006)" do
    alias Nostr.Event.BlockedRelays

    test "create/1 creates blocked relays list" do
      blocked = BlockedRelays.create(["wss://bad.com", "wss://spam.com"])

      assert %BlockedRelays{} = blocked
      assert blocked.event.kind == 10_006
      assert length(blocked.relays) == 2
      assert Enum.any?(blocked.relays, fn r -> r.host == "bad.com" end)
    end
  end

  describe "Interests (kind 10015)" do
    alias Nostr.Event.Interests

    test "create/2 creates interests list" do
      interests =
        Interests.create(%{
          hashtags: ["nostr", "bitcoin"],
          interest_sets: ["30015:pk:tech"]
        })

      assert %Interests{} = interests
      assert interests.event.kind == 10_015
      assert interests.hashtags == ["nostr", "bitcoin"]
      assert interests.interest_sets == ["30015:pk:tech"]
    end
  end

  describe "FollowSets (kind 30000)" do
    alias Nostr.Event.FollowSets

    test "create/3 creates follow set with metadata" do
      set =
        FollowSets.create("devs", ["pk1", "pk2"],
          title: "Developers",
          description: "Nostr devs"
        )

      assert %FollowSets{} = set
      assert set.event.kind == 30_000
      assert set.identifier == "devs"
      assert set.title == "Developers"
      assert set.description == "Nostr devs"
      assert set.pubkeys == ["pk1", "pk2"]
    end

    test "parse/1 parses set with metadata" do
      tags = [
        Tag.create(:d, "my-set"),
        Tag.create(:title, "My Set"),
        Tag.create(:p, "pk1")
      ]

      event = Event.create(30_000, tags: tags)

      set = FollowSets.parse(event)

      assert set.identifier == "my-set"
      assert set.title == "My Set"
      assert set.pubkeys == ["pk1"]
    end
  end

  describe "RelaySets (kind 30002)" do
    alias Nostr.Event.RelaySets

    test "create/3 creates relay set" do
      set = RelaySets.create("premium", ["wss://r1.com", "wss://r2.com"], title: "Premium Relays")

      assert %RelaySets{} = set
      assert set.event.kind == 30_002
      assert set.identifier == "premium"
      assert length(set.relays) == 2
    end
  end

  describe "CurationSets (kinds 30004-30006)" do
    alias Nostr.Event.CurationSets

    test "create_articles/3 creates article curation set" do
      set =
        CurationSets.create_articles(
          "reading-list",
          %{
            articles: ["30023:pk:art1"],
            notes: ["note1"]
          },
          title: "Reading List"
        )

      assert %CurationSets{} = set
      assert set.kind == 30_004
      assert set.identifier == "reading-list"
      assert set.title == "Reading List"
    end

    test "create_videos/3 creates video curation set" do
      set = CurationSets.create_videos("tutorials", ["video1", "video2"])

      assert set.kind == 30_005
      assert length(set.items) == 2
    end

    test "create_pictures/3 creates picture curation set" do
      set = CurationSets.create_pictures("photos", ["pic1"])

      assert set.kind == 30_006
    end
  end

  describe "KindMuteSets (kind 30007)" do
    alias Nostr.Event.KindMuteSets

    test "create/3 creates kind mute set" do
      set = KindMuteSets.create(6, ["pk1", "pk2"])

      assert %KindMuteSets{} = set
      assert set.event.kind == 30_007
      assert set.muted_kind == 6
      assert set.pubkeys == ["pk1", "pk2"]
    end

    test "parse/1 parses muted kind from d tag" do
      tags = [Tag.create(:d, "7"), Tag.create(:p, "pk1")]
      event = Event.create(30_007, tags: tags)

      set = KindMuteSets.parse(event)

      assert set.muted_kind == 7
    end
  end

  describe "StarterPacks (kind 39089)" do
    alias Nostr.Event.StarterPacks

    test "create/3 creates starter pack" do
      pack =
        StarterPacks.create("nostr-devs", ["pk1", "pk2", "pk3"],
          title: "Nostr Developers",
          description: "Follow all the top devs"
        )

      assert %StarterPacks{} = pack
      assert pack.event.kind == 39_089
      assert pack.identifier == "nostr-devs"
      assert pack.title == "Nostr Developers"
      assert pack.pubkeys == ["pk1", "pk2", "pk3"]
    end
  end

  describe "Parser integration" do
    alias Nostr.Event.Parser

    test "routes list kinds to correct modules" do
      # Test a few representative kinds
      kinds_and_modules = [
        {10_000, Nostr.Event.ListMute},
        {10_001, Nostr.Event.PinnedNotes},
        {10_002, Nostr.Event.RelayList},
        {10_003, Nostr.Event.Bookmarks},
        {30_000, Nostr.Event.FollowSets},
        {30_004, Nostr.Event.CurationSets},
        {39_089, Nostr.Event.StarterPacks}
      ]

      for {kind, module} <- kinds_and_modules do
        event = Event.create(kind, tags: [Tag.create(:d, "test")])
        parsed = Parser.parse_specific(event)
        assert parsed.__struct__ == module, "Kind #{kind} should parse to #{module}"
      end
    end
  end

  describe "roundtrip tests" do
    alias Nostr.Event.FollowSets
    alias Nostr.Event.ListMute
    alias Nostr.Event.RelayList

    test "ListMute roundtrip with encryption" do
      seckey = Fixtures.seckey()

      original =
        ListMute.create(
          %{
            pubkeys: ["public1"],
            hashtags: ["spam"],
            private_pubkeys: ["private1"],
            private_words: ["secret"]
          },
          seckey: seckey
        )

      signed = Event.sign(original, seckey)
      json = JSON.encode!(signed.event)
      raw = JSON.decode!(json)
      parsed = Event.parse_specific(raw)

      assert parsed.pubkeys == ["public1"]
      assert parsed.hashtags == ["spam"]
      assert parsed.private_pubkeys == :not_loaded

      decrypted = ListMute.decrypt_private(parsed, seckey)
      assert decrypted.private_pubkeys == ["private1"]
      assert decrypted.private_words == ["secret"]
    end

    test "RelayList roundtrip" do
      original =
        RelayList.create([
          "wss://relay1.com",
          {"wss://relay2.com", :read},
          {"wss://relay3.com", :write}
        ])

      signed = Event.sign(original, Fixtures.seckey())
      json = JSON.encode!(signed.event)
      raw = JSON.decode!(json)
      parsed = Event.parse_specific(raw)

      assert length(parsed.relays) == 3
      read_relay = Enum.find(parsed.relays, fn r -> r.url.host == "relay2.com" end)
      assert read_relay.marker == :read
    end

    test "FollowSets roundtrip with metadata" do
      original =
        FollowSets.create("test-set", ["pk1", "pk2"],
          title: "Test Set",
          description: "A test"
        )

      signed = Event.sign(original, Fixtures.seckey())
      json = JSON.encode!(signed.event)
      raw = JSON.decode!(json)
      parsed = Event.parse_specific(raw)

      assert parsed.identifier == "test-set"
      assert parsed.title == "Test Set"
      assert parsed.description == "A test"
      assert parsed.pubkeys == ["pk1", "pk2"]
    end
  end
end
