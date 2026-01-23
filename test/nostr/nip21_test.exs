defmodule Nostr.NIP21Test do
  use ExUnit.Case, async: true

  alias Nostr.NIP19.Address
  alias Nostr.NIP19.Event
  alias Nostr.NIP19.Profile
  alias Nostr.NIP21

  # Test vectors from NIP-21 spec
  @spec_npub_uri "nostr:npub1sn0wdenkukak0d9dfczzeacvhkrgz92ak56egt7vdgzn8pv2wfqqhrjdv9"
  @spec_nprofile_uri "nostr:nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p"
  @spec_note_uri "nostr:note1fntxtkcy9pjwucqwa9mddn7v03wwwsu9j330jj350nvhpky2tuaspk6nqc"
  @spec_nevent_uri "nostr:nevent1qqstna2yrezu5wghjvswqqculvvwxsrcvu7uc0f78gan4xqhvz49d9spr3mhxue69uhkummnw3ez6un9d3shjtn4de6x2argwghx6egpr4mhxue69uhkummnw3ez6ur4vgh8wetvd3hhyer9wghxuet5nxnepm"

  # Known values
  @pubkey "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
  @event_id "b9f5441e45ca39179320e0031cfb18e34078673dcc3d3e3a3b3a981571b14f4e"

  describe "parse/1 - spec examples" do
    test "parses npub URI from spec" do
      assert {:ok, :npub, pubkey} = NIP21.parse(@spec_npub_uri)
      assert is_binary(pubkey)
      assert String.length(pubkey) == 64
    end

    test "parses nprofile URI from spec" do
      assert {:ok, :nprofile, %Profile{} = profile} = NIP21.parse(@spec_nprofile_uri)
      assert profile.pubkey == @pubkey
      assert profile.relays == ["wss://r.x.com", "wss://djbas.sadkb.com"]
    end

    test "parses note URI from spec" do
      assert {:ok, :note, event_id} = NIP21.parse(@spec_note_uri)
      assert is_binary(event_id)
      assert String.length(event_id) == 64
    end

    test "parses nevent URI from spec" do
      assert {:ok, :nevent, %Event{} = event} = NIP21.parse(@spec_nevent_uri)
      assert is_binary(event.event_id)
      refute Enum.empty?(event.relays)
    end
  end

  describe "parse/1 - security" do
    test "rejects nsec URIs" do
      # Generate a fake nsec URI
      nsec_uri = "nostr:nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5"
      assert {:error, :nsec_not_allowed} = NIP21.parse(nsec_uri)
    end
  end

  describe "parse/1 - error handling" do
    test "rejects invalid URI scheme" do
      assert {:error, :invalid_uri_scheme} = NIP21.parse("https://example.com")
      assert {:error, :invalid_uri_scheme} = NIP21.parse("npub1...")
      assert {:error, :invalid_uri_scheme} = NIP21.parse("")
    end

    test "returns error for invalid bech32 after nostr:" do
      assert {:error, _reason} = NIP21.parse("nostr:invalid")
    end
  end

  describe "to_uri/1" do
    test "wraps npub in nostr: URI" do
      npub = "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"
      assert {:ok, "nostr:" <> ^npub} = NIP21.to_uri(npub)
    end

    test "wraps nprofile in nostr: URI" do
      {:ok, nprofile} = Nostr.NIP19.encode_nprofile(@pubkey, ["wss://relay.example.com"])
      assert {:ok, "nostr:" <> ^nprofile} = NIP21.to_uri(nprofile)
    end

    test "wraps note in nostr: URI" do
      {:ok, note} = Nostr.Bech32.hex_to_note(@event_id)
      assert {:ok, "nostr:" <> ^note} = NIP21.to_uri(note)
    end

    test "wraps nevent in nostr: URI" do
      {:ok, nevent} = Nostr.NIP19.encode_nevent(@event_id)
      assert {:ok, "nostr:" <> ^nevent} = NIP21.to_uri(nevent)
    end

    test "rejects nsec" do
      nsec = "nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5"
      assert {:error, :nsec_not_allowed} = NIP21.to_uri(nsec)
    end
  end

  describe "encode_npub/1" do
    test "creates npub URI from hex pubkey" do
      assert {:ok, uri} = NIP21.encode_npub(@pubkey)
      assert String.starts_with?(uri, "nostr:npub1")

      # Verify roundtrip
      assert {:ok, :npub, decoded} = NIP21.parse(uri)
      assert decoded == @pubkey
    end

    test "returns error for invalid pubkey" do
      assert {:error, _reason} = NIP21.encode_npub("invalid")
    end
  end

  describe "encode_nprofile/2" do
    test "creates nprofile URI without relays" do
      assert {:ok, uri} = NIP21.encode_nprofile(@pubkey)
      assert String.starts_with?(uri, "nostr:nprofile1")

      assert {:ok, :nprofile, profile} = NIP21.parse(uri)
      assert profile.pubkey == @pubkey
      assert profile.relays == []
    end

    test "creates nprofile URI with relays" do
      relays = ["wss://relay1.example.com", "wss://relay2.example.com"]
      assert {:ok, uri} = NIP21.encode_nprofile(@pubkey, relays)

      assert {:ok, :nprofile, profile} = NIP21.parse(uri)
      assert profile.pubkey == @pubkey
      assert profile.relays == relays
    end
  end

  describe "encode_note/1" do
    test "creates note URI from hex event ID" do
      assert {:ok, uri} = NIP21.encode_note(@event_id)
      assert String.starts_with?(uri, "nostr:note1")

      assert {:ok, :note, decoded} = NIP21.parse(uri)
      assert decoded == @event_id
    end
  end

  describe "encode_nevent/2" do
    test "creates nevent URI without metadata" do
      assert {:ok, uri} = NIP21.encode_nevent(@event_id)
      assert String.starts_with?(uri, "nostr:nevent1")

      assert {:ok, :nevent, event} = NIP21.parse(uri)
      assert event.event_id == @event_id
    end

    test "creates nevent URI with full metadata" do
      opts = [relays: ["wss://relay.example.com"], author: @pubkey, kind: 1]
      assert {:ok, uri} = NIP21.encode_nevent(@event_id, opts)

      assert {:ok, :nevent, event} = NIP21.parse(uri)
      assert event.event_id == @event_id
      assert event.relays == ["wss://relay.example.com"]
      assert event.author == @pubkey
      assert event.kind == 1
    end
  end

  describe "encode_naddr/4" do
    test "creates naddr URI" do
      assert {:ok, uri} = NIP21.encode_naddr("my-article", @pubkey, 30_023)
      assert String.starts_with?(uri, "nostr:naddr1")

      assert {:ok, :naddr, %Address{} = addr} = NIP21.parse(uri)
      assert addr.identifier == "my-article"
      assert addr.pubkey == @pubkey
      assert addr.kind == 30_023
    end

    test "creates naddr URI with relays" do
      relays = ["wss://relay.example.com"]
      assert {:ok, uri} = NIP21.encode_naddr("article", @pubkey, 30_023, relays)

      assert {:ok, :naddr, addr} = NIP21.parse(uri)
      assert addr.relays == relays
    end
  end

  describe "roundtrip" do
    test "encode and parse preserves data for all types" do
      # npub
      {:ok, npub_uri} = NIP21.encode_npub(@pubkey)
      {:ok, :npub, decoded_pubkey} = NIP21.parse(npub_uri)
      assert decoded_pubkey == @pubkey

      # nprofile
      relays = ["wss://relay.example.com"]
      {:ok, nprofile_uri} = NIP21.encode_nprofile(@pubkey, relays)
      {:ok, :nprofile, profile} = NIP21.parse(nprofile_uri)
      assert profile.pubkey == @pubkey
      assert profile.relays == relays

      # note
      {:ok, note_uri} = NIP21.encode_note(@event_id)
      {:ok, :note, decoded_event_id} = NIP21.parse(note_uri)
      assert decoded_event_id == @event_id

      # nevent
      {:ok, nevent_uri} = NIP21.encode_nevent(@event_id, author: @pubkey, kind: 1)
      {:ok, :nevent, event} = NIP21.parse(nevent_uri)
      assert event.event_id == @event_id
      assert event.author == @pubkey
      assert event.kind == 1

      # naddr
      {:ok, naddr_uri} = NIP21.encode_naddr("test", @pubkey, 30_023)
      {:ok, :naddr, addr} = NIP21.parse(naddr_uri)
      assert addr.identifier == "test"
      assert addr.pubkey == @pubkey
      assert addr.kind == 30_023
    end
  end
end
