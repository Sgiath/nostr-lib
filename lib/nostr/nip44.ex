defmodule Nostr.NIP44 do
  @moduledoc """
  NIP-44 Versioned Encrypted Payloads

  Implements version 2 encryption: secp256k1 ECDH, HKDF, ChaCha20, HMAC-SHA256

  Defined in NIP 44
  https://github.com/nostr-protocol/nips/blob/master/44.md
  """
  @moduledoc tags: [:crypto, :nip44], nip: 44

  @version 2
  @min_plaintext_size 1
  @max_plaintext_size 65535
  # Payload constraints
  @min_payload_size 132
  @max_payload_size 87472
  @min_decoded_size 99
  @max_decoded_size 65603

  # HKDF salt for NIP-44 v2
  @hkdf_salt "nip44-v2"

  @doc """
  Encrypts plaintext for a recipient using their public key.

  ## Parameters
    - plaintext: The message to encrypt (1-65535 bytes)
    - seckey: Sender's secret key (hex-encoded)
    - pubkey: Recipient's public key (hex-encoded, x-only)

  ## Returns
    Base64-encoded encrypted payload
  """
  @spec encrypt(String.t(), binary(), binary()) :: binary()
  def encrypt(plaintext, seckey, pubkey) do
    conversation_key = get_conversation_key(seckey, pubkey)
    nonce = :crypto.strong_rand_bytes(32)
    do_encrypt(plaintext, conversation_key, nonce)
  end

  @doc """
  Encrypts plaintext using a pre-computed conversation key.

  ## Parameters
    - plaintext: The message to encrypt (1-65535 bytes)
    - conversation_key: 32-byte conversation key (raw bytes)

  ## Returns
    Base64-encoded encrypted payload
  """
  @spec encrypt(String.t(), binary()) :: binary()
  def encrypt(plaintext, conversation_key) when byte_size(conversation_key) == 32 do
    nonce = :crypto.strong_rand_bytes(32)
    do_encrypt(plaintext, conversation_key, nonce)
  end

  @doc """
  Encrypts plaintext using a conversation key and specific nonce.

  This function is primarily for testing with deterministic nonces.
  In production, use `encrypt/2` or `encrypt/3` which generate random nonces.

  ## Parameters
    - plaintext: The message to encrypt (1-65535 bytes)
    - conversation_key: 32-byte conversation key (raw bytes)
    - nonce: 32-byte nonce (raw bytes)

  ## Returns
    Base64-encoded encrypted payload
  """
  @spec encrypt_with_nonce(String.t(), binary(), binary()) :: binary()
  def encrypt_with_nonce(plaintext, conversation_key, nonce)
      when byte_size(conversation_key) == 32 and byte_size(nonce) == 32 do
    do_encrypt(plaintext, conversation_key, nonce)
  end

  # Internal encrypt implementation with explicit nonce
  defp do_encrypt(plaintext, conversation_key, nonce)
       when byte_size(conversation_key) == 32 and byte_size(nonce) == 32 do
    plaintext_len = byte_size(plaintext)

    if plaintext_len < @min_plaintext_size or plaintext_len > @max_plaintext_size do
      raise ArgumentError, "plaintext length must be between 1 and 65535 bytes"
    end

    {chacha_key, chacha_nonce, hmac_key} = get_message_keys(conversation_key, nonce)

    padded = pad(plaintext)
    ciphertext = chacha20_encrypt(chacha_key, chacha_nonce, padded)
    mac = hmac_aad(hmac_key, ciphertext, nonce)

    Base.encode64(<<@version::8, nonce::binary, ciphertext::binary, mac::binary>>)
  end

  @doc """
  Decrypts a payload using the recipient's secret key.

  ## Parameters
    - payload: Base64-encoded encrypted payload
    - seckey: Recipient's secret key (hex-encoded)
    - pubkey: Sender's public key (hex-encoded, x-only)

  ## Returns
    - `{:ok, plaintext}` on success
    - `{:error, reason}` on failure
  """
  @spec decrypt(binary(), binary(), binary()) :: {:ok, String.t()} | {:error, atom()}
  def decrypt(payload, seckey, pubkey) do
    conversation_key = get_conversation_key(seckey, pubkey)
    decrypt(payload, conversation_key)
  end

  @doc """
  Decrypts a payload using a pre-computed conversation key.

  ## Parameters
    - payload: Base64-encoded encrypted payload
    - conversation_key: 32-byte conversation key (raw bytes)

  ## Returns
    - `{:ok, plaintext}` on success
    - `{:error, reason}` on failure
  """
  @spec decrypt(binary(), binary()) :: {:ok, String.t()} | {:error, atom()}
  def decrypt(payload, conversation_key) when byte_size(conversation_key) == 32 do
    with :ok <- validate_payload_length(payload),
         {:ok, data} <- decode_payload(payload),
         {:ok, {nonce, ciphertext, mac}} <- parse_payload(data),
         {chacha_key, chacha_nonce, hmac_key} <- get_message_keys(conversation_key, nonce),
         :ok <- verify_mac(hmac_key, ciphertext, nonce, mac),
         padded <- chacha20_decrypt(chacha_key, chacha_nonce, ciphertext) do
      unpad(padded)
    end
  end

  @doc """
  Computes the conversation key between two parties.

  The conversation key is symmetric: `get_conversation_key(a, B) == get_conversation_key(b, A)`

  ## Parameters
    - seckey: Secret key (hex-encoded)
    - pubkey: Public key (hex-encoded, x-only)

  ## Returns
    32-byte conversation key (raw bytes)
  """
  @spec get_conversation_key(binary(), binary()) :: binary()
  def get_conversation_key(seckey, pubkey) do
    shared_x = shared_point(seckey, pubkey)
    hkdf_extract(shared_x, @hkdf_salt)
  end

  @doc """
  Derives message-specific keys from conversation key and nonce.

  ## Parameters
    - conversation_key: 32-byte conversation key (raw bytes)
    - nonce: 32-byte nonce (raw bytes)

  ## Returns
    Tuple of `{chacha_key, chacha_nonce, hmac_key}`
  """
  @spec get_message_keys(binary(), binary()) ::
          {binary(), binary(), binary()}
  def get_message_keys(conversation_key, nonce)
      when byte_size(conversation_key) == 32 and byte_size(nonce) == 32 do
    keys = hkdf_expand(conversation_key, nonce, 76)
    <<chacha_key::binary-32, chacha_nonce::binary-12, hmac_key::binary-32>> = keys
    {chacha_key, chacha_nonce, hmac_key}
  end

  # ECDH shared point (x-coordinate only, unhashed)
  defp shared_point(seckey, pubkey) do
    seckey_bytes = Base.decode16!(seckey, case: :lower)
    # Add 02 prefix for compressed public key format
    pubkey_bytes = Base.decode16!("02" <> pubkey, case: :lower)
    :crypto.compute_key(:ecdh, pubkey_bytes, seckey_bytes, :secp256k1)
  end

  # HKDF-extract: PRK = HMAC-Hash(salt, IKM)
  defp hkdf_extract(ikm, salt) do
    :crypto.mac(:hmac, :sha256, salt, ikm)
  end

  # HKDF-expand: OKM = T(1) || T(2) || ... where T(i) = HMAC-Hash(PRK, T(i-1) || info || i)
  defp hkdf_expand(prk, info, length) when length <= 255 * 32 do
    hash_len = 32
    n = ceil(length / hash_len)

    {output, _} =
      Enum.reduce(1..n, {<<>>, <<>>}, fn i, {acc, prev} ->
        t = :crypto.mac(:hmac, :sha256, prk, <<prev::binary, info::binary, i::8>>)
        {<<acc::binary, t::binary>>, t}
      end)

    binary_part(output, 0, length)
  end

  # ChaCha20 encryption
  defp chacha20_encrypt(key, nonce, plaintext) do
    # ChaCha20 with counter starting at 0
    iv = <<0::32, nonce::binary>>
    :crypto.crypto_one_time(:chacha20, key, iv, plaintext, encrypt: true)
  end

  # ChaCha20 decryption (same as encryption for stream cipher)
  defp chacha20_decrypt(key, nonce, ciphertext) do
    iv = <<0::32, nonce::binary>>
    :crypto.crypto_one_time(:chacha20, key, iv, ciphertext, encrypt: false)
  end

  # HMAC with AAD (additional authenticated data)
  defp hmac_aad(key, message, aad) when byte_size(aad) == 32 do
    :crypto.mac(:hmac, :sha256, key, <<aad::binary, message::binary>>)
  end

  # Verify MAC using constant-time comparison
  defp verify_mac(hmac_key, ciphertext, nonce, expected_mac) do
    calculated_mac = hmac_aad(hmac_key, ciphertext, nonce)

    if constant_time_compare(calculated_mac, expected_mac) do
      :ok
    else
      {:error, :invalid_mac}
    end
  end

  # Constant-time comparison to prevent timing attacks
  defp constant_time_compare(a, b) when byte_size(a) == byte_size(b) do
    :crypto.hash_equals(a, b)
  end

  defp constant_time_compare(_, _), do: false

  # Calculate padded length based on power-of-two chunks
  @doc false
  def calc_padded_len(unpadded_len) when unpadded_len <= 32, do: 32

  def calc_padded_len(unpadded_len) do
    # next_power = 2^(floor(log2(unpadded_len - 1)) + 1)
    next_power = next_power_of_two(unpadded_len - 1)

    chunk =
      if next_power <= 256 do
        32
      else
        div(next_power, 8)
      end

    chunk * (div(unpadded_len - 1, chunk) + 1)
  end

  defp next_power_of_two(n) do
    exp = :math.log2(n) |> floor()
    :erlang.bsl(1, exp + 1)
  end

  # Pad plaintext: [length:u16be][plaintext][zeros]
  defp pad(plaintext) do
    unpadded_len = byte_size(plaintext)
    padded_len = calc_padded_len(unpadded_len)
    padding_len = padded_len - unpadded_len
    <<unpadded_len::big-16, plaintext::binary, 0::size(padding_len * 8)>>
  end

  # Unpad plaintext
  defp unpad(padded) do
    <<unpadded_len::big-16, rest::binary>> = padded

    if unpadded_len == 0 do
      {:error, :invalid_padding}
    else
      plaintext = binary_part(rest, 0, unpadded_len)
      expected_padded_len = calc_padded_len(unpadded_len)

      # Verify padding: total size should be 2 + expected_padded_len
      if byte_size(padded) == 2 + expected_padded_len and byte_size(plaintext) == unpadded_len do
        {:ok, plaintext}
      else
        {:error, :invalid_padding}
      end
    end
  end

  # Validate base64 payload length
  defp validate_payload_length(payload) do
    len = byte_size(payload)

    cond do
      len == 0 -> {:error, :empty_payload}
      String.starts_with?(payload, "#") -> {:error, :unsupported_version}
      len < @min_payload_size -> {:error, :payload_too_short}
      len > @max_payload_size -> {:error, :payload_too_long}
      true -> :ok
    end
  end

  # Decode and validate base64 payload
  defp decode_payload(payload) do
    case Base.decode64(payload) do
      {:ok, data} ->
        len = byte_size(data)

        cond do
          len < @min_decoded_size -> {:error, :decoded_too_short}
          len > @max_decoded_size -> {:error, :decoded_too_long}
          true -> {:ok, data}
        end

      :error ->
        {:error, :invalid_base64}
    end
  end

  # Parse decoded payload into components
  defp parse_payload(data) do
    data_len = byte_size(data)
    ciphertext_len = data_len - 1 - 32 - 32

    <<version::8, nonce::binary-32, ciphertext::binary-size(ciphertext_len), mac::binary-32>> =
      data

    if version != @version do
      {:error, :unsupported_version}
    else
      {:ok, {nonce, ciphertext, mac}}
    end
  end
end
