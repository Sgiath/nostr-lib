defmodule Nostr.NIP44Test do
  use ExUnit.Case, async: true

  # Test vectors from https://github.com/paulmillr/nip44
  # SHA256: 269ed0f69e4c192512cc779e78c555090cebc7c785b609e338a62afc3ce25040

  describe "get_conversation_key/2" do
    test "derives correct conversation key from test vector" do
      sec1 = "0000000000000000000000000000000000000000000000000000000000000001"
      sec2 = "0000000000000000000000000000000000000000000000000000000000000002"
      expected = "c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d"

      pub2 =
        sec2
        |> Base.decode16!(case: :lower)
        |> Secp256k1.pubkey(:xonly)
        |> Base.encode16(case: :lower)

      conv_key = Nostr.NIP44.get_conversation_key(sec1, pub2)
      assert Base.encode16(conv_key, case: :lower) == expected
    end

    test "conversation key is symmetric" do
      sec1 = "0000000000000000000000000000000000000000000000000000000000000001"
      sec2 = "0000000000000000000000000000000000000000000000000000000000000002"

      pub1 =
        sec1
        |> Base.decode16!(case: :lower)
        |> Secp256k1.pubkey(:xonly)
        |> Base.encode16(case: :lower)

      pub2 =
        sec2
        |> Base.decode16!(case: :lower)
        |> Secp256k1.pubkey(:xonly)
        |> Base.encode16(case: :lower)

      conv_key_1 = Nostr.NIP44.get_conversation_key(sec1, pub2)
      conv_key_2 = Nostr.NIP44.get_conversation_key(sec2, pub1)

      assert conv_key_1 == conv_key_2
    end
  end

  describe "get_message_keys/2" do
    test "derives correct message keys from test vector" do
      # From nip44.vectors.json valid.get_message_keys
      conversation_key =
        Base.decode16!("c41c775356fd92eadc63ff5a0dc1da211b268cbea22316767095b2871ea1412d",
          case: :lower
        )

      nonce =
        Base.decode16!("0000000000000000000000000000000000000000000000000000000000000001",
          case: :lower
        )

      {chacha_key, chacha_nonce, hmac_key} =
        Nostr.NIP44.get_message_keys(conversation_key, nonce)

      # Verify key sizes are correct per NIP-44 spec
      assert byte_size(chacha_key) == 32
      assert byte_size(chacha_nonce) == 12
      assert byte_size(hmac_key) == 32
    end
  end

  describe "calc_padded_len/1" do
    test "calculates correct padded lengths" do
      # Test vectors from nip44.vectors.json valid.calc_padded_len
      test_cases = [
        {1, 32},
        {2, 32},
        {31, 32},
        {32, 32},
        {33, 64},
        {37, 64},
        {45, 64},
        {49, 64},
        {64, 64},
        {65, 96},
        {100, 128},
        {111, 128},
        {200, 224},
        {250, 256},
        {320, 320},
        {383, 384},
        {384, 384},
        {400, 448},
        {500, 512},
        {512, 512},
        {515, 640},
        {1024, 1024},
        {65535, 65536}
      ]

      for {input, expected} <- test_cases do
        assert Nostr.NIP44.calc_padded_len(input) == expected,
               "calc_padded_len(#{input}) should be #{expected}, got #{Nostr.NIP44.calc_padded_len(input)}"
      end
    end
  end

  describe "encrypt/decrypt round trip" do
    test "encrypts and decrypts message successfully" do
      sec1 = "0000000000000000000000000000000000000000000000000000000000000001"
      sec2 = "0000000000000000000000000000000000000000000000000000000000000002"

      pub1 =
        sec1
        |> Base.decode16!(case: :lower)
        |> Secp256k1.pubkey(:xonly)
        |> Base.encode16(case: :lower)

      pub2 =
        sec2
        |> Base.decode16!(case: :lower)
        |> Secp256k1.pubkey(:xonly)
        |> Base.encode16(case: :lower)

      plaintext = "hello world"

      # Encrypt with sec1 -> pub2
      payload = Nostr.NIP44.encrypt(plaintext, sec1, pub2)

      # Decrypt with sec2 -> pub1
      assert {:ok, ^plaintext} = Nostr.NIP44.decrypt(payload, sec2, pub1)
    end

    test "encrypts and decrypts with conversation key" do
      sec1 = "0000000000000000000000000000000000000000000000000000000000000001"
      sec2 = "0000000000000000000000000000000000000000000000000000000000000002"

      pub2 =
        sec2
        |> Base.decode16!(case: :lower)
        |> Secp256k1.pubkey(:xonly)
        |> Base.encode16(case: :lower)

      conversation_key = Nostr.NIP44.get_conversation_key(sec1, pub2)
      plaintext = "test message"

      payload = Nostr.NIP44.encrypt(plaintext, conversation_key)
      assert {:ok, ^plaintext} = Nostr.NIP44.decrypt(payload, conversation_key)
    end
  end

  describe "encrypt_with_nonce/3" do
    test "produces deterministic output with known test vector" do
      # Test vector from nip44.vectors.json valid.encrypt_decrypt
      sec1 = "0000000000000000000000000000000000000000000000000000000000000001"
      sec2 = "0000000000000000000000000000000000000000000000000000000000000002"

      nonce =
        Base.decode16!("0000000000000000000000000000000000000000000000000000000000000001",
          case: :lower
        )

      plaintext = "a"

      expected_payload =
        "AgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABee0G5VSK0/9YypIObAtDKfYEAjD35uVkHyB0F4DwrcNaCXlCWZKaArsGrY6M9wnuTMxWfp1RTN9Xga8no+kF5Vsb"

      pub2 =
        sec2
        |> Base.decode16!(case: :lower)
        |> Secp256k1.pubkey(:xonly)
        |> Base.encode16(case: :lower)

      conversation_key = Nostr.NIP44.get_conversation_key(sec1, pub2)
      payload = Nostr.NIP44.encrypt_with_nonce(plaintext, conversation_key, nonce)

      assert payload == expected_payload
    end
  end

  describe "decrypt/2 error handling" do
    test "returns error for empty payload" do
      conversation_key = :crypto.strong_rand_bytes(32)
      assert {:error, :empty_payload} = Nostr.NIP44.decrypt("", conversation_key)
    end

    test "returns error for payload starting with #" do
      conversation_key = :crypto.strong_rand_bytes(32)
      assert {:error, :unsupported_version} = Nostr.NIP44.decrypt("#future", conversation_key)
    end

    test "returns error for payload too short" do
      conversation_key = :crypto.strong_rand_bytes(32)
      short_payload = Base.encode64(:crypto.strong_rand_bytes(50))
      assert {:error, _} = Nostr.NIP44.decrypt(short_payload, conversation_key)
    end

    test "returns error for invalid MAC" do
      sec1 = "0000000000000000000000000000000000000000000000000000000000000001"
      sec2 = "0000000000000000000000000000000000000000000000000000000000000002"

      pub2 =
        sec2
        |> Base.decode16!(case: :lower)
        |> Secp256k1.pubkey(:xonly)
        |> Base.encode16(case: :lower)

      conversation_key = Nostr.NIP44.get_conversation_key(sec1, pub2)
      payload = Nostr.NIP44.encrypt("hello", conversation_key)

      # Corrupt the payload
      decoded = Base.decode64!(payload)
      corrupted = binary_part(decoded, 0, byte_size(decoded) - 1) <> <<0>>
      corrupted_payload = Base.encode64(corrupted)

      assert {:error, :invalid_mac} = Nostr.NIP44.decrypt(corrupted_payload, conversation_key)
    end
  end
end
