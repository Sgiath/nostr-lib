defmodule Nostr.NIP37Test do
  use ExUnit.Case, async: true

  alias Nostr.Event
  alias Nostr.Event.{DraftWrap, PrivateContentRelayList}
  alias Nostr.Test.Fixtures

  describe "DraftWrap.create/3" do
    test "creates encrypted draft wrap from map" do
      draft = %{kind: 1, content: "My draft note", tags: []}
      seckey = Fixtures.seckey()

      assert {:ok, wrap} = DraftWrap.create(draft, seckey, identifier: "my-draft")
      assert wrap.event.kind == 31_234
      assert wrap.identifier == "my-draft"
      assert wrap.draft_kind == 1
      assert wrap.draft == draft
      assert wrap.event.content != ""
      assert wrap.event.sig != nil
    end

    test "creates draft wrap with expiration" do
      draft = %{kind: 1, content: "Expiring draft", tags: []}
      seckey = Fixtures.seckey()
      expiration = DateTime.utc_now() |> DateTime.add(86400) |> DateTime.to_unix()

      assert {:ok, wrap} =
               DraftWrap.create(draft, seckey, identifier: "exp-draft", expiration: expiration)

      assert wrap.expiration == expiration

      # Check expiration tag is present
      exp_tag = Enum.find(wrap.event.tags, &(&1.type == :expiration))
      assert exp_tag != nil
      assert exp_tag.data == to_string(expiration)
    end

    test "generates random identifier when not provided" do
      draft = %{kind: 1, content: "Draft", tags: []}
      seckey = Fixtures.seckey()

      assert {:ok, wrap1} = DraftWrap.create(draft, seckey)
      assert {:ok, wrap2} = DraftWrap.create(draft, seckey)
      assert wrap1.identifier != wrap2.identifier
      assert String.length(wrap1.identifier) == 32
    end

    test "creates draft wrap from Event struct" do
      event = Event.create(1, content: "Draft from event", tags: [])
      seckey = Fixtures.seckey()

      assert {:ok, wrap} = DraftWrap.create(event, seckey, identifier: "event-draft")
      assert wrap.draft_kind == 1
      assert wrap.draft.kind == 1
      assert wrap.draft.content == "Draft from event"
    end

    test "includes k tag with draft kind" do
      draft = %{kind: 30023, content: "Article draft", tags: []}
      seckey = Fixtures.seckey()

      assert {:ok, wrap} = DraftWrap.create(draft, seckey, identifier: "article")
      k_tag = Enum.find(wrap.event.tags, &(&1.type == :k))
      assert k_tag != nil
      assert k_tag.data == "30023"
    end
  end

  describe "DraftWrap.parse/1" do
    test "parses draft wrap event" do
      draft = %{kind: 1, content: "Test", tags: []}
      seckey = Fixtures.seckey()

      {:ok, wrap} =
        DraftWrap.create(draft, seckey, identifier: "test-id", expiration: 1_234_567_890)

      parsed = DraftWrap.parse(wrap.event)
      assert parsed.identifier == "test-id"
      assert parsed.draft_kind == 1
      assert parsed.expiration == 1_234_567_890
      # Not decrypted yet
      assert parsed.draft == nil
    end
  end

  describe "DraftWrap.decrypt/2" do
    test "decrypts draft wrap with correct key" do
      draft = %{"kind" => 1, "content" => "Secret draft", "tags" => []}
      seckey = Fixtures.seckey()

      {:ok, wrap} = DraftWrap.create(draft, seckey, identifier: "decrypt-test")
      parsed = DraftWrap.parse(wrap.event)

      assert {:ok, decrypted} = DraftWrap.decrypt(parsed, seckey)
      assert decrypted.draft["content"] == "Secret draft"
      assert decrypted.draft["kind"] == 1
    end

    test "fails to decrypt with wrong key" do
      draft = %{kind: 1, content: "Secret", tags: []}
      seckey = Fixtures.seckey()
      wrong_seckey = Fixtures.seckey2()

      {:ok, wrap} = DraftWrap.create(draft, seckey, identifier: "wrong-key-test")
      parsed = DraftWrap.parse(wrap.event)

      assert {:error, _reason} = DraftWrap.decrypt(parsed, wrong_seckey)
    end

    test "handles blanked content (deletion)" do
      seckey = Fixtures.seckey()
      {:ok, deletion} = DraftWrap.delete("deleted-draft", seckey: seckey)

      assert {:ok, decrypted} = DraftWrap.decrypt(deletion, seckey)
      assert decrypted.draft == nil
    end
  end

  describe "DraftWrap.delete/2" do
    test "creates deletion with blanked content" do
      seckey = Fixtures.seckey()

      assert {:ok, deletion} = DraftWrap.delete("my-draft", seckey: seckey)
      assert deletion.event.content == ""
      assert deletion.identifier == "my-draft"
      assert deletion.draft == nil
      assert deletion.event.sig != nil
    end

    test "creates unsigned deletion with only pubkey" do
      pubkey = Fixtures.pubkey()

      assert {:ok, deletion} = DraftWrap.delete("my-draft", pubkey: pubkey)
      assert deletion.event.content == ""
      assert deletion.event.sig == nil
    end

    test "includes draft kind when provided" do
      seckey = Fixtures.seckey()

      {:ok, deletion} = DraftWrap.delete("my-draft", seckey: seckey, draft_kind: 30023)
      assert deletion.draft_kind == 30023

      k_tag = Enum.find(deletion.event.tags, &(&1.type == :k))
      assert k_tag.data == "30023"
    end

    test "raises without pubkey or seckey" do
      assert_raise ArgumentError, fn ->
        DraftWrap.delete("my-draft", [])
      end
    end
  end

  describe "DraftWrap.is_deleted?/1" do
    test "returns true for blanked content" do
      seckey = Fixtures.seckey()
      {:ok, deletion} = DraftWrap.delete("my-draft", seckey: seckey)
      assert DraftWrap.is_deleted?(deletion) == true
    end

    test "returns false for non-empty content" do
      draft = %{kind: 1, content: "Not deleted", tags: []}
      seckey = Fixtures.seckey()
      {:ok, wrap} = DraftWrap.create(draft, seckey)
      assert DraftWrap.is_deleted?(wrap) == false
    end
  end

  describe "PrivateContentRelayList.create/3" do
    test "creates encrypted relay list" do
      relays = ["wss://relay1.example.com", "wss://relay2.example.com"]
      seckey = Fixtures.seckey()

      assert {:ok, list} = PrivateContentRelayList.create(relays, seckey)
      assert list.event.kind == 10_013
      assert list.relays == relays
      assert list.event.content != ""
      assert list.event.tags == []
      assert list.event.sig != nil
    end

    test "creates empty relay list" do
      seckey = Fixtures.seckey()

      assert {:ok, list} = PrivateContentRelayList.create([], seckey)
      assert list.relays == []
    end
  end

  describe "PrivateContentRelayList.parse/1" do
    test "parses relay list event" do
      relays = ["wss://private.relay.com"]
      seckey = Fixtures.seckey()

      {:ok, list} = PrivateContentRelayList.create(relays, seckey)

      parsed = PrivateContentRelayList.parse(list.event)
      assert parsed.event.kind == 10_013
      # Not decrypted yet
      assert parsed.relays == nil
    end
  end

  describe "PrivateContentRelayList.decrypt/2" do
    test "decrypts relay list with correct key" do
      relays = ["wss://relay1.com", "wss://relay2.com", "wss://relay3.com"]
      seckey = Fixtures.seckey()

      {:ok, list} = PrivateContentRelayList.create(relays, seckey)
      parsed = PrivateContentRelayList.parse(list.event)

      assert {:ok, decrypted} = PrivateContentRelayList.decrypt(parsed, seckey)
      assert decrypted.relays == relays
    end

    test "fails to decrypt with wrong key" do
      relays = ["wss://private.relay.com"]
      seckey = Fixtures.seckey()
      wrong_seckey = Fixtures.seckey2()

      {:ok, list} = PrivateContentRelayList.create(relays, seckey)
      parsed = PrivateContentRelayList.parse(list.event)

      assert {:error, _reason} = PrivateContentRelayList.decrypt(parsed, wrong_seckey)
    end

    test "handles empty content" do
      seckey = Fixtures.seckey()
      pubkey = Fixtures.pubkey()

      # Create an event with empty content manually
      event =
        Event.create(10_013, content: "", tags: [], pubkey: pubkey)
        |> Event.sign(seckey)

      parsed = PrivateContentRelayList.parse(event)
      assert {:ok, decrypted} = PrivateContentRelayList.decrypt(parsed, seckey)
      assert decrypted.relays == []
    end
  end

  describe "Parser integration" do
    test "routes kind 31234 to DraftWrap" do
      draft = %{kind: 1, content: "Test", tags: []}
      seckey = Fixtures.seckey()

      {:ok, wrap} = DraftWrap.create(draft, seckey)
      parsed = Event.Parser.parse_specific(wrap.event)

      assert %DraftWrap{} = parsed
    end

    test "routes kind 10013 to PrivateContentRelayList" do
      relays = ["wss://relay.example.com"]
      seckey = Fixtures.seckey()

      {:ok, list} = PrivateContentRelayList.create(relays, seckey)
      parsed = Event.Parser.parse_specific(list.event)

      assert %PrivateContentRelayList{} = parsed
    end
  end
end
