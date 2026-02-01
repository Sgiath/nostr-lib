defmodule Nostr.NIP49Test do
  use ExUnit.Case, async: true

  alias Nostr.NIP49

  describe "decrypt/2" do
    test "decrypts NIP-49 test vector" do
      ncryptsec =
        "ncryptsec1qgg9947rlpvqu76pj5ecreduf9jxhselq2nae2kghhvd5g7dgjtcxfqtd67p9m0w57lspw8gsq6yphnm8623nsl8xn9j4jdzz84zm3frztj3z7s35vpzmqf6ksu8r89qk5z2zxfmu5gv8th8wclt0h4p"

      password = "nostr"
      expected = "3501454135014541350145413501453fefb02227e449e57cf4d3a3ce05378683"

      assert {:ok, ^expected} = NIP49.decrypt(ncryptsec, password)
    end

    test "returns error for wrong password" do
      ncryptsec =
        "ncryptsec1qgg9947rlpvqu76pj5ecreduf9jxhselq2nae2kghhvd5g7dgjtcxfqtd67p9m0w57lspw8gsq6yphnm8623nsl8xn9j4jdzz84zm3frztj3z7s35vpzmqf6ksu8r89qk5z2zxfmu5gv8th8wclt0h4p"

      assert {:error, :decryption_failed} = NIP49.decrypt(ncryptsec, "wrong_password")
    end

    test "returns error for invalid bech32" do
      assert {:error, :invalid_bech32} = NIP49.decrypt("invalid", "password")
    end

    test "returns error for wrong HRP" do
      # npub instead of ncryptsec
      npub = "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"
      assert {:error, :invalid_hrp} = NIP49.decrypt(npub, "password")
    end
  end

  describe "encrypt/3 and decrypt/2" do
    test "round-trip encryption with default log_n" do
      private_key =
        32
        |> :crypto.strong_rand_bytes()
        |> Base.encode16(case: :lower)

      password = "test-password-123"

      assert {:ok, ncryptsec} = NIP49.encrypt(private_key, password)
      assert String.starts_with?(ncryptsec, "ncryptsec1")
      assert {:ok, ^private_key} = NIP49.decrypt(ncryptsec, password)
    end

    test "round-trip encryption with custom log_n" do
      private_key =
        32
        |> :crypto.strong_rand_bytes()
        |> Base.encode16(case: :lower)

      password = "another-password"

      assert {:ok, ncryptsec} = NIP49.encrypt(private_key, password, log_n: 16)
      assert {:ok, ^private_key} = NIP49.decrypt(ncryptsec, password)
    end

    test "round-trip encryption with all security levels" do
      private_key =
        32
        |> :crypto.strong_rand_bytes()
        |> Base.encode16(case: :lower)

      password = "password"

      for security <- [:insecure, :secure, :unknown] do
        assert {:ok, ncryptsec} = NIP49.encrypt(private_key, password, key_security: security)
        assert {:ok, ^private_key} = NIP49.decrypt(ncryptsec, password)
      end
    end

    test "encrypted output varies due to random nonce/salt" do
      private_key =
        32
        |> :crypto.strong_rand_bytes()
        |> Base.encode16(case: :lower)

      password = "test"

      {:ok, ncryptsec1} = NIP49.encrypt(private_key, password)
      {:ok, ncryptsec2} = NIP49.encrypt(private_key, password)

      # Same input but different output (due to random nonce/salt)
      refute ncryptsec1 == ncryptsec2

      # Both decrypt correctly
      assert {:ok, ^private_key} = NIP49.decrypt(ncryptsec1, password)
      assert {:ok, ^private_key} = NIP49.decrypt(ncryptsec2, password)
    end
  end

  describe "encrypt/3 validation" do
    test "returns error for invalid private key length" do
      assert {:error, :invalid_private_key_length} = NIP49.encrypt("abc", "password")
    end

    test "returns error for invalid hex" do
      # 64 chars but not valid hex
      invalid = String.duplicate("zz", 32)
      assert {:error, :invalid_hex} = NIP49.encrypt(invalid, "password")
    end

    test "returns error for invalid log_n" do
      private_key =
        32
        |> :crypto.strong_rand_bytes()
        |> Base.encode16(case: :lower)

      assert {:error, :invalid_log_n} = NIP49.encrypt(private_key, "password", log_n: 30)
    end
  end

  describe "normalize_password/1" do
    test "normalizes NFKC according to NIP-49 spec" do
      # Test from NIP-49 spec:
      # Input: "ÅΩẛ̣" as Unicode codepoints U+212B U+2126 U+1E9B U+0323
      # UTF-8 bytes: [0xE2, 0x84, 0xAB, 0xE2, 0x84, 0xA6, 0xE1, 0xBA, 0x9B, 0xCC, 0xA3]
      input = <<0xE2, 0x84, 0xAB, 0xE2, 0x84, 0xA6, 0xE1, 0xBA, 0x9B, 0xCC, 0xA3>>

      # Expected NFKC: "ÅΩṩ" as codepoints U+00C5 U+03A9 U+1E69
      # UTF-8 bytes: [0xC3, 0x85, 0xCE, 0xA9, 0xE1, 0xB9, 0xA9]
      expected = <<0xC3, 0x85, 0xCE, 0xA9, 0xE1, 0xB9, 0xA9>>

      assert expected == NIP49.normalize_password(input)
    end

    test "ASCII passwords remain unchanged" do
      assert "hello123" == NIP49.normalize_password("hello123")
    end

    test "empty password normalizes to empty" do
      assert "" == NIP49.normalize_password("")
    end
  end
end
