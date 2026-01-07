defmodule Nostr.Bech32Test do
  use ExUnit.Case, async: true

  alias Nostr.Test.Fixtures

  doctest Nostr.Bech32

  describe "encode/2" do
    test "encodes hex to bech32 with npub prefix" do
      {:ok, encoded} = Nostr.Bech32.encode("npub", Fixtures.pubkey())
      assert String.starts_with?(encoded, "npub1")
    end

    test "encodes hex to bech32 with nsec prefix" do
      {:ok, encoded} = Nostr.Bech32.encode("nsec", Fixtures.seckey())
      assert String.starts_with?(encoded, "nsec1")
    end

    test "encodes hex to bech32 with note prefix" do
      event_id = "0000000000000000000000000000000000000000000000000000000000000001"
      {:ok, encoded} = Nostr.Bech32.encode("note", event_id)
      assert String.starts_with?(encoded, "note1")
    end

    test "returns error for invalid hex" do
      assert {:error, :invalid_hex} = Nostr.Bech32.encode("npub", "not_hex")
    end

    test "returns error for odd-length hex" do
      assert {:error, :invalid_hex} = Nostr.Bech32.encode("npub", "abc")
    end
  end

  describe "decode/1" do
    test "decodes bech32 to hex" do
      {:ok, encoded} = Nostr.Bech32.encode("npub", Fixtures.pubkey())
      {:ok, decoded} = Nostr.Bech32.decode(encoded)
      assert decoded == Fixtures.pubkey()
    end

    test "roundtrip encode/decode preserves data" do
      for prefix <- ["npub", "nsec", "note", "nprofile"] do
        {:ok, encoded} = Nostr.Bech32.encode(prefix, Fixtures.pubkey())
        {:ok, decoded} = Nostr.Bech32.decode(encoded)
        assert decoded == Fixtures.pubkey()
      end
    end

    test "returns error for invalid bech32" do
      assert {:error, _reason} = Nostr.Bech32.decode("invalid_bech32")
    end

    test "returns error for corrupted checksum" do
      {:ok, encoded} = Nostr.Bech32.encode("npub", Fixtures.pubkey())
      # Flip last character to corrupt checksum
      corrupted = String.slice(encoded, 0..-2//1) <> "x"
      assert {:error, _reason} = Nostr.Bech32.decode(corrupted)
    end
  end

  describe "hex_to_npub/1" do
    test "encodes pubkey to npub" do
      {:ok, npub} = Nostr.Bech32.hex_to_npub(Fixtures.pubkey())
      assert String.starts_with?(npub, "npub1")
    end

    test "returns error for invalid hex" do
      assert {:error, :invalid_hex} = Nostr.Bech32.hex_to_npub("invalid")
    end
  end

  describe "hex_to_nsec/1" do
    test "encodes seckey to nsec" do
      {:ok, nsec} = Nostr.Bech32.hex_to_nsec(Fixtures.seckey())
      assert String.starts_with?(nsec, "nsec1")
    end
  end

  describe "hex_to_note/1" do
    test "encodes event id to note" do
      event_id = "0000000000000000000000000000000000000000000000000000000000000001"
      {:ok, note} = Nostr.Bech32.hex_to_note(event_id)
      assert String.starts_with?(note, "note1")
    end
  end

  describe "hex_to_nprofile/1" do
    test "encodes profile id to nprofile" do
      {:ok, nprofile} = Nostr.Bech32.hex_to_nprofile(Fixtures.pubkey())
      assert String.starts_with?(nprofile, "nprofile1")
    end
  end

  describe "npub_to_hex/1" do
    test "decodes npub to hex" do
      {:ok, npub} = Nostr.Bech32.hex_to_npub(Fixtures.pubkey())
      {:ok, hex} = Nostr.Bech32.npub_to_hex(npub)
      assert hex == Fixtures.pubkey()
    end

    test "only accepts npub prefix" do
      {:ok, nsec} = Nostr.Bech32.hex_to_nsec(Fixtures.seckey())

      assert_raise FunctionClauseError, fn ->
        Nostr.Bech32.npub_to_hex(nsec)
      end
    end
  end

  describe "nsec_to_hex/1" do
    test "decodes nsec to hex" do
      {:ok, nsec} = Nostr.Bech32.hex_to_nsec(Fixtures.seckey())
      {:ok, hex} = Nostr.Bech32.nsec_to_hex(nsec)
      assert hex == Fixtures.seckey()
    end

    test "only accepts nsec prefix" do
      {:ok, npub} = Nostr.Bech32.hex_to_npub(Fixtures.pubkey())

      assert_raise FunctionClauseError, fn ->
        Nostr.Bech32.nsec_to_hex(npub)
      end
    end
  end

  describe "note_to_hex/1" do
    test "decodes note to hex" do
      event_id = "0000000000000000000000000000000000000000000000000000000000000001"
      {:ok, note} = Nostr.Bech32.hex_to_note(event_id)
      {:ok, hex} = Nostr.Bech32.note_to_hex(note)
      assert hex == event_id
    end

    test "only accepts note prefix" do
      {:ok, npub} = Nostr.Bech32.hex_to_npub(Fixtures.pubkey())

      assert_raise FunctionClauseError, fn ->
        Nostr.Bech32.note_to_hex(npub)
      end
    end
  end

  describe "nprofile_to_hex/1" do
    test "decodes nprofile to hex" do
      {:ok, nprofile} = Nostr.Bech32.hex_to_nprofile(Fixtures.pubkey())
      {:ok, hex} = Nostr.Bech32.nprofile_to_hex(nprofile)
      assert hex == Fixtures.pubkey()
    end

    test "only accepts nprofile prefix" do
      {:ok, npub} = Nostr.Bech32.hex_to_npub(Fixtures.pubkey())

      assert_raise FunctionClauseError, fn ->
        Nostr.Bech32.nprofile_to_hex(npub)
      end
    end
  end
end
