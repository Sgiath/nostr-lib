defmodule Nostr.Crypto do
  @moduledoc """
  Crypto related stuff
  """

  @doc """
  Get pubkey (hex encoded) from seckey (hex encoded)

  ## Example:

      iex> Nostr.Crypto.pubkey("1111111111111111111111111111111111111111111111111111111111111111")
      "4f355bdcb7cc0af728ef3cceb9615d90684bb5b2ca5f859ab0f0b704075871aa"

  """
  @spec pubkey(seckey :: binary()) :: binary()
  def pubkey(seckey) do
    seckey
    |> d16()
    |> Secp256k1.pubkey(:xonly)
    |> e16()
  end

  @doc """
  Sign binary data (hex encoded) with seckey (hex encoded)
  """
  @spec sign(data :: binary(), seckey :: binary()) :: binary()
  def sign(data, seckey) do
    data
    |> d16()
    |> Secp256k1.schnorr_sign(d16(seckey))
    |> e16()
  end

  @doc """
  Encrypt message with ECDH from seckey and pubkey and append randomly generated IV
  """
  @spec encrypt(String.t(), binary(), binary()) :: binary()
  def encrypt(message, seckey, pubkey) do
    iv = :crypto.strong_rand_bytes(16)

    cipher_text =
      :crypto.crypto_one_time(:aes_256_cbc, shared_secret(seckey, pubkey), iv, message,
        encrypt: true,
        padding: :pkcs_padding
      )

    e64(cipher_text) <> "?iv=" <> e64(iv)
  end

  @doc """
  Decrypt message with ECDH from seckey and pubkey (automatically extracts IV from message)
  """
  @spec decrypt(binary(), binary(), binary()) :: String.t()
  def decrypt(message, seckey, pubkey) do
    [message, iv] = String.split(message, "?iv=")

    :crypto.crypto_one_time(:aes_256_cbc, shared_secret(seckey, pubkey), d64(iv), d64(message),
      encrypt: false,
      padding: :pkcs_padding
    )
  end

  defp shared_secret(seckey, pubkey) when is_binary(seckey) and is_binary(pubkey) do
    :crypto.compute_key(:ecdh, d16("02" <> pubkey), d16(seckey), :secp256k1)
  end

  defp d16(data), do: Base.decode16!(data, case: :lower)
  defp d64(data), do: Base.decode64!(data)

  defp e16(data), do: Base.encode16(data, case: :lower)
  defp e64(data), do: Base.encode64(data)
end
