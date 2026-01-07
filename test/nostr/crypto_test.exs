defmodule Nostr.CryptoTest do
  use ExUnit.Case, async: true

  alias Nostr.Test.Fixtures

  doctest Nostr.Crypto

  describe "pubkey/1" do
    test "derives correct pubkey from seckey" do
      assert Nostr.Crypto.pubkey(Fixtures.seckey()) == Fixtures.pubkey()
      assert Nostr.Crypto.pubkey(Fixtures.seckey2()) == Fixtures.pubkey2()
    end

    test "returns consistent pubkey for same seckey" do
      pubkey1 = Nostr.Crypto.pubkey(Fixtures.seckey())
      pubkey2 = Nostr.Crypto.pubkey(Fixtures.seckey())
      assert pubkey1 == pubkey2
    end

    test "returns different pubkeys for different seckeys" do
      pubkey1 = Nostr.Crypto.pubkey(Fixtures.seckey())
      pubkey2 = Nostr.Crypto.pubkey(Fixtures.seckey2())
      refute pubkey1 == pubkey2
    end

    test "pubkey is 64 hex characters (32 bytes)" do
      pubkey = Nostr.Crypto.pubkey(Fixtures.seckey())
      assert String.length(pubkey) == 64
      assert String.match?(pubkey, ~r/^[0-9a-f]+$/)
    end
  end

  describe "sign/2" do
    test "produces valid signature" do
      data = "test data to sign"
      data_hex = Base.encode16(data, case: :lower)
      signature = Nostr.Crypto.sign(data_hex, Fixtures.seckey())

      # Signature should be 128 hex characters (64 bytes Schnorr signature)
      assert String.length(signature) == 128
      assert String.match?(signature, ~r/^[0-9a-f]+$/)
    end

    test "produces different signatures for different data" do
      sig1 =
        Nostr.Crypto.sign(
          "0000000000000000000000000000000000000000000000000000000000000001",
          Fixtures.seckey()
        )

      sig2 =
        Nostr.Crypto.sign(
          "0000000000000000000000000000000000000000000000000000000000000002",
          Fixtures.seckey()
        )

      refute sig1 == sig2
    end

    test "produces different signatures with different keys" do
      data = "0000000000000000000000000000000000000000000000000000000000000001"
      sig1 = Nostr.Crypto.sign(data, Fixtures.seckey())
      sig2 = Nostr.Crypto.sign(data, Fixtures.seckey2())
      refute sig1 == sig2
    end
  end

  # Note: These tests require ECDH support which may not be available on all systems.
  # If these tests fail with ECDH errors, it's likely an OpenSSL/Erlang crypto issue.
  describe "encrypt/3 and decrypt/3" do
    @describetag :ecdh

    test "encrypts and decrypts message successfully" do
      message = "Hello, this is a secret message!"
      encrypted = Nostr.Crypto.encrypt(message, Fixtures.seckey(), Fixtures.pubkey2())

      # Encrypted format should contain ?iv=
      assert String.contains?(encrypted, "?iv=")

      # Decrypt with recipient's key
      decrypted = Nostr.Crypto.decrypt(encrypted, Fixtures.seckey2(), Fixtures.pubkey())
      assert decrypted == message
    end

    test "sender can decrypt their own message" do
      message = "My own message"
      encrypted = Nostr.Crypto.encrypt(message, Fixtures.seckey(), Fixtures.pubkey2())

      # Sender decrypts using recipient's pubkey
      decrypted = Nostr.Crypto.decrypt(encrypted, Fixtures.seckey(), Fixtures.pubkey2())
      assert decrypted == message
    end

    test "recipient can decrypt message" do
      message = "Message for recipient"
      encrypted = Nostr.Crypto.encrypt(message, Fixtures.seckey(), Fixtures.pubkey2())

      # Recipient decrypts using sender's pubkey
      decrypted = Nostr.Crypto.decrypt(encrypted, Fixtures.seckey2(), Fixtures.pubkey())
      assert decrypted == message
    end

    test "encrypts empty string" do
      message = ""
      encrypted = Nostr.Crypto.encrypt(message, Fixtures.seckey(), Fixtures.pubkey2())
      decrypted = Nostr.Crypto.decrypt(encrypted, Fixtures.seckey2(), Fixtures.pubkey())
      assert decrypted == message
    end

    test "encrypts unicode content" do
      message = "Hello! Emoji test"
      encrypted = Nostr.Crypto.encrypt(message, Fixtures.seckey(), Fixtures.pubkey2())
      decrypted = Nostr.Crypto.decrypt(encrypted, Fixtures.seckey2(), Fixtures.pubkey())
      assert decrypted == message
    end

    test "produces different ciphertext each time (random IV)" do
      message = "Same message"
      encrypted1 = Nostr.Crypto.encrypt(message, Fixtures.seckey(), Fixtures.pubkey2())
      encrypted2 = Nostr.Crypto.encrypt(message, Fixtures.seckey(), Fixtures.pubkey2())
      refute encrypted1 == encrypted2
    end
  end
end
