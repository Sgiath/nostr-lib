defmodule Nostr.NIP19Test do
  use ExUnit.Case, async: true

  alias Nostr.NIP19
  alias Nostr.NIP19.Address
  alias Nostr.NIP19.Event
  alias Nostr.NIP19.Profile

  # Test vectors from NIP-19 spec
  @spec_pubkey "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
  # @spec_npub "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"
  @spec_nprofile_with_relays "nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p"
  @spec_relay1 "wss://r.x.com"
  @spec_relay2 "wss://djbas.sadkb.com"

  @spec_pubkey2 "7e7e9c42a91bfef19fa929e5fda1b72e0ebc1a4c1141673e2794234d86addf4e"
  @spec_npub2 "npub10elfcs4fr0l0r8af98jlmgdh9c8tcxjvz9qkw038js35mp4dma8qzvjptg"

  @spec_seckey "67dea2ed018072d675f5415ecfaed7d2597555e202d85b3d65ea4e58d2d92ffa"
  @spec_nsec "nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5"

  describe "NIP19.TLV" do
    alias Nostr.NIP19.TLV

    test "encodes single TLV entry" do
      result = TLV.encode_tlv(0, <<0xCA, 0xFE>>)
      assert result == <<0, 2, 0xCA, 0xFE>>
    end

    test "encodes multiple TLV entries" do
      entries = [{0, <<0xAB, 0xCD>>}, {1, "relay"}]
      result = TLV.encode_tlvs(entries)
      assert result == <<0, 2, 0xAB, 0xCD, 1, 5, "relay">>
    end

    test "decodes TLV entries" do
      data = <<0, 2, 0xAB, 0xCD, 1, 5, "relay">>
      assert {:ok, [{0, <<0xAB, 0xCD>>}, {1, "relay"}]} = TLV.decode_tlvs(data)
    end

    test "returns error for incomplete TLV" do
      assert {:error, :incomplete_tlv} = TLV.decode_tlvs(<<0, 5, 0xAB>>)
    end

    test "find_all returns all matching values" do
      entries = [{0, "pubkey"}, {1, "relay1"}, {1, "relay2"}, {2, "author"}]
      assert TLV.find_all(entries, 1) == ["relay1", "relay2"]
      assert TLV.find_all(entries, 0) == ["pubkey"]
      assert TLV.find_all(entries, 99) == []
    end

    test "find_first returns first matching value" do
      entries = [{0, "pubkey"}, {1, "relay1"}, {1, "relay2"}]
      assert TLV.find_first(entries, 0) == "pubkey"
      assert TLV.find_first(entries, 1) == "relay1"
      assert TLV.find_first(entries, 99) == nil
    end

    test "roundtrip encode/decode" do
      entries = [
        {0, String.duplicate("x", 32)},
        {1, "wss://relay.example.com"},
        {2, String.duplicate("y", 32)}
      ]

      encoded = TLV.encode_tlvs(entries)
      assert {:ok, ^entries} = TLV.decode_tlvs(encoded)
    end
  end

  describe "decode/1 - bare entities from spec" do
    test "decodes npub from spec example" do
      assert {:ok, :npub, @spec_pubkey2} = NIP19.decode(@spec_npub2)
    end

    test "decodes nsec from spec example" do
      assert {:ok, :nsec, @spec_seckey} = NIP19.decode(@spec_nsec)
    end

    test "returns error for unknown prefix" do
      assert {:error, :unknown_prefix} = NIP19.decode("invalid123")
    end
  end

  describe "decode_nprofile/1" do
    test "decodes nprofile with relays from spec example" do
      assert {:ok, profile} = NIP19.decode_nprofile(@spec_nprofile_with_relays)
      assert %Profile{} = profile
      assert profile.pubkey == @spec_pubkey
      assert profile.relays == [@spec_relay1, @spec_relay2]
    end

    test "decodes nprofile without relays" do
      {:ok, nprofile} = NIP19.encode_nprofile(@spec_pubkey)
      assert {:ok, profile} = NIP19.decode_nprofile(nprofile)
      assert profile.pubkey == @spec_pubkey
      assert profile.relays == []
    end

    test "returns error for invalid prefix" do
      assert {:error, :invalid_prefix} = NIP19.decode_nprofile("npub123")
    end
  end

  describe "encode_nprofile/2" do
    test "encodes profile without relays" do
      assert {:ok, nprofile} = NIP19.encode_nprofile(@spec_pubkey)
      assert String.starts_with?(nprofile, "nprofile1")

      # Verify roundtrip
      assert {:ok, profile} = NIP19.decode_nprofile(nprofile)
      assert profile.pubkey == @spec_pubkey
      assert profile.relays == []
    end

    test "encodes profile with single relay" do
      assert {:ok, nprofile} = NIP19.encode_nprofile(@spec_pubkey, [@spec_relay1])

      assert {:ok, profile} = NIP19.decode_nprofile(nprofile)
      assert profile.pubkey == @spec_pubkey
      assert profile.relays == [@spec_relay1]
    end

    test "encodes profile with multiple relays" do
      relays = [@spec_relay1, @spec_relay2]
      assert {:ok, nprofile} = NIP19.encode_nprofile(@spec_pubkey, relays)

      assert {:ok, profile} = NIP19.decode_nprofile(nprofile)
      assert profile.pubkey == @spec_pubkey
      assert profile.relays == relays
    end

    test "returns error for invalid pubkey" do
      assert {:error, :invalid_pubkey} = NIP19.encode_nprofile("not_hex")
      assert {:error, :invalid_pubkey} = NIP19.encode_nprofile("abcd")
    end
  end

  describe "encode_nevent/2 and decode_nevent/1" do
    @event_id "b9f5441e45ca39179320e0031cfb18e34078673dcc3d3e3a3b3a981571b14f4e"

    test "encodes event without metadata" do
      assert {:ok, nevent} = NIP19.encode_nevent(@event_id)
      assert String.starts_with?(nevent, "nevent1")

      assert {:ok, event} = NIP19.decode_nevent(nevent)
      assert %Event{} = event
      assert event.event_id == @event_id
      assert event.relays == []
      assert event.author == nil
      assert event.kind == nil
    end

    test "encodes event with relays" do
      assert {:ok, nevent} = NIP19.encode_nevent(@event_id, relays: [@spec_relay1])

      assert {:ok, event} = NIP19.decode_nevent(nevent)
      assert event.event_id == @event_id
      assert event.relays == [@spec_relay1]
    end

    test "encodes event with author" do
      assert {:ok, nevent} = NIP19.encode_nevent(@event_id, author: @spec_pubkey)

      assert {:ok, event} = NIP19.decode_nevent(nevent)
      assert event.event_id == @event_id
      assert event.author == @spec_pubkey
    end

    test "encodes event with kind" do
      assert {:ok, nevent} = NIP19.encode_nevent(@event_id, kind: 1)

      assert {:ok, event} = NIP19.decode_nevent(nevent)
      assert event.event_id == @event_id
      assert event.kind == 1
    end

    test "encodes event with all metadata" do
      opts = [relays: [@spec_relay1, @spec_relay2], author: @spec_pubkey, kind: 1]
      assert {:ok, nevent} = NIP19.encode_nevent(@event_id, opts)

      assert {:ok, event} = NIP19.decode_nevent(nevent)
      assert event.event_id == @event_id
      assert event.relays == [@spec_relay1, @spec_relay2]
      assert event.author == @spec_pubkey
      assert event.kind == 1
    end

    test "returns error for invalid event_id" do
      assert {:error, :invalid_event_id} = NIP19.encode_nevent("invalid")
    end

    test "returns error for invalid author" do
      assert {:error, :invalid_author} = NIP19.encode_nevent(@event_id, author: "invalid")
    end

    test "returns error for invalid prefix" do
      assert {:error, :invalid_prefix} = NIP19.decode_nevent("npub123")
    end
  end

  describe "encode_naddr/4 and decode_naddr/1" do
    @identifier "my-article"
    @kind 30_023

    test "encodes addressable event" do
      assert {:ok, naddr} = NIP19.encode_naddr(@identifier, @spec_pubkey, @kind)
      assert String.starts_with?(naddr, "naddr1")

      assert {:ok, addr} = NIP19.decode_naddr(naddr)
      assert %Address{} = addr
      assert addr.identifier == @identifier
      assert addr.pubkey == @spec_pubkey
      assert addr.kind == @kind
      assert addr.relays == []
    end

    test "encodes addressable event with relays" do
      relays = [@spec_relay1]
      assert {:ok, naddr} = NIP19.encode_naddr(@identifier, @spec_pubkey, @kind, relays)

      assert {:ok, addr} = NIP19.decode_naddr(naddr)
      assert addr.identifier == @identifier
      assert addr.pubkey == @spec_pubkey
      assert addr.kind == @kind
      assert addr.relays == relays
    end

    test "encodes addressable event with empty identifier" do
      # Normal replaceable events use empty string for d-tag
      assert {:ok, naddr} = NIP19.encode_naddr("", @spec_pubkey, 0)

      assert {:ok, addr} = NIP19.decode_naddr(naddr)
      assert addr.identifier == ""
      assert addr.kind == 0
    end

    test "returns error for invalid pubkey" do
      assert {:error, :invalid_pubkey} = NIP19.encode_naddr(@identifier, "invalid", @kind)
    end

    test "returns error for invalid prefix" do
      assert {:error, :invalid_prefix} = NIP19.decode_naddr("npub123")
    end
  end

  describe "decode/1 - TLV entities" do
    test "decodes nprofile through generic decode" do
      {:ok, nprofile} = NIP19.encode_nprofile(@spec_pubkey, [@spec_relay1])
      assert {:ok, :nprofile, %Profile{pubkey: @spec_pubkey}} = NIP19.decode(nprofile)
    end

    test "decodes nevent through generic decode" do
      event_id = "b9f5441e45ca39179320e0031cfb18e34078673dcc3d3e3a3b3a981571b14f4e"
      {:ok, nevent} = NIP19.encode_nevent(event_id)
      assert {:ok, :nevent, %Event{event_id: ^event_id}} = NIP19.decode(nevent)
    end

    test "decodes naddr through generic decode" do
      {:ok, naddr} = NIP19.encode_naddr("test", @spec_pubkey, 30_023)
      assert {:ok, :naddr, %Address{identifier: "test"}} = NIP19.decode(naddr)
    end
  end

  describe "spec compliance - ignoring unknown TLV types" do
    test "decoding ignores unknown TLV types" do
      # Manually construct TLV with unknown type 99
      alias Nostr.NIP19.TLV

      {:ok, pubkey_bin} = Base.decode16(@spec_pubkey, case: :lower)

      tlv_data =
        TLV.encode_tlvs([
          {TLV.special(), pubkey_bin},
          {99, "unknown data"},
          {TLV.relay(), @spec_relay1}
        ])

      nprofile = Bechamel.encode("nprofile", tlv_data)

      # Should successfully decode, ignoring type 99
      assert {:ok, profile} = NIP19.decode_nprofile(nprofile)
      assert profile.pubkey == @spec_pubkey
      assert profile.relays == [@spec_relay1]
    end
  end

  describe "roundtrip encoding" do
    test "nprofile roundtrip preserves all data" do
      relays = ["wss://relay1.example.com", "wss://relay2.example.com"]
      {:ok, encoded} = NIP19.encode_nprofile(@spec_pubkey, relays)
      {:ok, decoded} = NIP19.decode_nprofile(encoded)

      assert decoded.pubkey == @spec_pubkey
      assert decoded.relays == relays
    end

    test "nevent roundtrip preserves all data" do
      event_id = "b9f5441e45ca39179320e0031cfb18e34078673dcc3d3e3a3b3a981571b14f4e"
      opts = [relays: [@spec_relay1], author: @spec_pubkey, kind: 1]

      {:ok, encoded} = NIP19.encode_nevent(event_id, opts)
      {:ok, decoded} = NIP19.decode_nevent(encoded)

      assert decoded.event_id == event_id
      assert decoded.relays == [@spec_relay1]
      assert decoded.author == @spec_pubkey
      assert decoded.kind == 1
    end

    test "naddr roundtrip preserves all data" do
      relays = [@spec_relay1, @spec_relay2]
      {:ok, encoded} = NIP19.encode_naddr("article-id", @spec_pubkey, 30_023, relays)
      {:ok, decoded} = NIP19.decode_naddr(encoded)

      assert decoded.identifier == "article-id"
      assert decoded.pubkey == @spec_pubkey
      assert decoded.kind == 30_023
      assert decoded.relays == relays
    end
  end
end
