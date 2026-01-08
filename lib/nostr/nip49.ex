defmodule Nostr.NIP49 do
  @moduledoc """
  NIP-49: Private Key Encryption

  Encrypt and decrypt private keys using password-based encryption.
  Uses scrypt for key derivation and XChaCha20-Poly1305 for encryption.

  ## Examples

      # Encrypt a private key
      {:ok, ncryptsec} = NIP49.encrypt(private_key_hex, "password", log_n: 16)

      # Decrypt
      {:ok, private_key_hex} = NIP49.decrypt(ncryptsec, "password")

  ## Key Security

  The key_security option indicates how securely the key has been handled:
  - `:insecure` (0x00) - key has been handled insecurely (stored/copied unencrypted)
  - `:secure` (0x01) - key has NOT been handled insecurely
  - `:unknown` (0x02) - client doesn't track this (default)

  ## Log N Parameter

  The log_n parameter controls scrypt memory/time cost:
  - 16: ~64 MiB, ~100ms
  - 18: ~256 MiB
  - 20: ~1 GiB, ~2s
  - 21: ~2 GiB
  - 22: ~4 GiB

  See: https://github.com/nostr-protocol/nips/blob/master/49.md
  """
  @moduledoc tags: [:nip49], nip: 49

  import Bitwise

  @version 0x02
  @default_log_n 16

  # ChaCha20 constants: "expand 32-byte k"
  @sigma0 0x61707865
  @sigma1 0x3320646E
  @sigma2 0x79622D32
  @sigma3 0x6B206574

  @type key_security :: :insecure | :secure | :unknown

  @doc """
  Encrypt a private key with a password.

  ## Arguments
    - `private_key_hex` - 64-character hex-encoded private key
    - `password` - password string (will be NFKC-normalized)
    - `opts` - options

  ## Options
    - `:log_n` - scrypt cost parameter (default: 16, range: 16-22)
    - `:key_security` - :insecure | :secure | :unknown (default: :unknown)

  ## Returns
    - `{:ok, ncryptsec}` - bech32-encoded encrypted key
    - `{:error, reason}` - on failure
  """
  @spec encrypt(binary(), String.t(), Keyword.t()) :: {:ok, String.t()} | {:error, atom()}
  def encrypt(private_key_hex, password, opts \\ []) do
    log_n = Keyword.get(opts, :log_n, @default_log_n)
    key_security = Keyword.get(opts, :key_security, :unknown)

    with {:ok, private_key} <- decode_hex(private_key_hex),
         :ok <- validate_log_n(log_n) do
      salt = :crypto.strong_rand_bytes(16)
      nonce = :crypto.strong_rand_bytes(24)
      normalized_password = normalize_password(password)

      symmetric_key = derive_key(normalized_password, salt, log_n)
      security_byte = encode_security_byte(key_security)

      ciphertext = xchacha20_poly1305_encrypt(private_key, symmetric_key, nonce, security_byte)

      payload =
        <<@version, log_n, salt::binary-16, nonce::binary-24, security_byte::binary-1,
          ciphertext::binary>>

      {:ok, Bechamel.encode("ncryptsec", payload)}
    end
  end

  @doc """
  Decrypt an ncryptsec-encoded private key.

  ## Arguments
    - `ncryptsec` - bech32-encoded encrypted key (starts with "ncryptsec1")
    - `password` - password string (will be NFKC-normalized)

  ## Returns
    - `{:ok, private_key_hex}` - 64-character hex-encoded private key
    - `{:error, reason}` - on failure
  """
  @spec decrypt(String.t(), String.t()) :: {:ok, binary()} | {:error, atom()}
  def decrypt(ncryptsec, password) do
    with {:ok, payload} <- decode_ncryptsec(ncryptsec),
         {:ok, {log_n, salt, nonce, security_byte, ciphertext}} <- parse_payload(payload) do
      normalized_password = normalize_password(password)
      symmetric_key = derive_key(normalized_password, salt, log_n)

      case xchacha20_poly1305_decrypt(ciphertext, symmetric_key, nonce, security_byte) do
        {:ok, private_key} -> {:ok, Base.encode16(private_key, case: :lower)}
        {:error, _} = error -> error
      end
    end
  end

  @doc """
  Normalize a password to NFKC unicode format.

  This ensures passwords can be entered identically across different systems.
  """
  @spec normalize_password(String.t()) :: binary()
  def normalize_password(password) when is_binary(password) do
    :unicode.characters_to_nfkc_binary(password)
  end

  # Private functions

  defp decode_hex(hex) when byte_size(hex) == 64 do
    case Base.decode16(hex, case: :mixed) do
      {:ok, bytes} -> {:ok, bytes}
      :error -> {:error, :invalid_hex}
    end
  end

  defp decode_hex(_), do: {:error, :invalid_private_key_length}

  defp validate_log_n(log_n) when log_n >= 1 and log_n <= 22, do: :ok
  defp validate_log_n(_), do: {:error, :invalid_log_n}

  defp decode_ncryptsec(ncryptsec) do
    case Bechamel.decode(ncryptsec, ignore_length: true) do
      {:ok, "ncryptsec", payload} -> {:ok, payload}
      {:ok, _, _} -> {:error, :invalid_hrp}
      {:error, _} -> {:error, :invalid_bech32}
    end
  end

  defp parse_payload(
         <<@version, log_n, salt::binary-16, nonce::binary-24, security_byte::binary-1,
           ciphertext::binary>>
       )
       when byte_size(ciphertext) == 48 do
    {:ok, {log_n, salt, nonce, security_byte, ciphertext}}
  end

  defp parse_payload(<<version, _::binary>>) when version != @version do
    {:error, :unsupported_version}
  end

  defp parse_payload(_), do: {:error, :invalid_payload}

  defp encode_security_byte(:insecure), do: <<0x00>>
  defp encode_security_byte(:secure), do: <<0x01>>
  defp encode_security_byte(:unknown), do: <<0x02>>

  defp derive_key(password, salt, log_n) do
    n = 1 <<< log_n
    :scrypt.scrypt(password, salt, n, 8, 1, 32)
  end

  # XChaCha20-Poly1305 using HChaCha20 construction

  defp xchacha20_poly1305_encrypt(plaintext, key, nonce, aad) do
    <<nonce_prefix::binary-16, nonce_suffix::binary-8>> = nonce
    subkey = hchacha20(key, nonce_prefix)
    nonce12 = <<0::32, nonce_suffix::binary>>

    {ciphertext, tag} =
      :crypto.crypto_one_time_aead(:chacha20_poly1305, subkey, nonce12, plaintext, aad, true)

    ciphertext <> tag
  end

  defp xchacha20_poly1305_decrypt(ciphertext_with_tag, key, nonce, aad) do
    <<nonce_prefix::binary-16, nonce_suffix::binary-8>> = nonce
    subkey = hchacha20(key, nonce_prefix)
    nonce12 = <<0::32, nonce_suffix::binary>>

    # Split ciphertext and tag (tag is 16 bytes)
    ciphertext_len = byte_size(ciphertext_with_tag) - 16
    <<ciphertext::binary-size(ciphertext_len), tag::binary-16>> = ciphertext_with_tag

    # 7-arity: cipher, key, nonce, ciphertext, aad, tag, encrypt_flag
    case :crypto.crypto_one_time_aead(
           :chacha20_poly1305,
           subkey,
           nonce12,
           ciphertext,
           aad,
           tag,
           false
         ) do
      :error -> {:error, :decryption_failed}
      plaintext -> {:ok, plaintext}
    end
  end

  # HChaCha20 - derives a 32-byte subkey from a 32-byte key and 16-byte input
  # This is the core of the XChaCha20 construction

  defp hchacha20(key, input) when byte_size(key) == 32 and byte_size(input) == 16 do
    <<k0::little-32, k1::little-32, k2::little-32, k3::little-32, k4::little-32, k5::little-32,
      k6::little-32, k7::little-32>> = key

    <<n0::little-32, n1::little-32, n2::little-32, n3::little-32>> = input

    # Initialize state: constants, key, input
    state = {
      @sigma0,
      @sigma1,
      @sigma2,
      @sigma3,
      k0,
      k1,
      k2,
      k3,
      k4,
      k5,
      k6,
      k7,
      n0,
      n1,
      n2,
      n3
    }

    # Run 20 rounds (10 double rounds)
    state = Enum.reduce(1..10, state, fn _, s -> double_round(s) end)

    # Extract words 0-3 and 12-15 as output
    {s0, s1, s2, s3, _, _, _, _, _, _, _, _, s12, s13, s14, s15} = state

    <<s0::little-32, s1::little-32, s2::little-32, s3::little-32, s12::little-32, s13::little-32,
      s14::little-32, s15::little-32>>
  end

  # ChaCha20 double round (column round + diagonal round)

  defp double_round({s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15}) do
    # Column rounds
    {s0, s4, s8, s12} = quarter_round(s0, s4, s8, s12)
    {s1, s5, s9, s13} = quarter_round(s1, s5, s9, s13)
    {s2, s6, s10, s14} = quarter_round(s2, s6, s10, s14)
    {s3, s7, s11, s15} = quarter_round(s3, s7, s11, s15)

    # Diagonal rounds
    {s0, s5, s10, s15} = quarter_round(s0, s5, s10, s15)
    {s1, s6, s11, s12} = quarter_round(s1, s6, s11, s12)
    {s2, s7, s8, s13} = quarter_round(s2, s7, s8, s13)
    {s3, s4, s9, s14} = quarter_round(s3, s4, s9, s14)

    {s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15}
  end

  # ChaCha20 quarter round

  defp quarter_round(a, b, c, d) do
    a = band(a + b, 0xFFFFFFFF)
    d = rotl32(bxor(d, a), 16)

    c = band(c + d, 0xFFFFFFFF)
    b = rotl32(bxor(b, c), 12)

    a = band(a + b, 0xFFFFFFFF)
    d = rotl32(bxor(d, a), 8)

    c = band(c + d, 0xFFFFFFFF)
    b = rotl32(bxor(b, c), 7)

    {a, b, c, d}
  end

  # 32-bit left rotation

  defp rotl32(x, n) do
    band(bsl(x, n) ||| bsr(x, 32 - n), 0xFFFFFFFF)
  end
end
