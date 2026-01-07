defmodule Nostr.Bech32 do
  @moduledoc """
  Bech32 encoded entities

  Defined in NIP-19
  https://github.com/nostr-protocol/nips/blob/master/19.md

  ## Example:

      iex> Nostr.Bech32.encode("npub", "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d")
      {:ok, "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"}

      iex> Nostr.Bech32.npub_to_hex("npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6")
      {:ok, "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"}

  """

  @typedoc "Human-readable part of bech32 string (nsec, npub, note, nprofile, etc.)"
  @type hrp :: String.t()

  @typedoc "Hex-encoded data (lowercase)"
  @type hex :: String.t()

  @typedoc "Bech32-encoded string"
  @type bech32 :: String.t()

  @doc """
  Encodes hex data with a bech32 human-readable prefix.

  ## Examples

      iex> Nostr.Bech32.encode("npub", "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d")
      {:ok, "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"}

      iex> Nostr.Bech32.encode("npub", "invalid")
      {:error, :invalid_hex}

  """
  @spec encode(hrp(), hex()) :: {:ok, bech32()} | {:error, :invalid_hex}
  def encode(hrp, data) do
    case Base.decode16(data, case: :lower) do
      {:ok, bin} -> {:ok, Bechamel.encode(hrp, bin)}
      :error -> {:error, :invalid_hex}
    end
  end

  @doc """
  Decodes a bech32 string to hex, discarding the human-readable prefix.

  ## Examples

      iex> Nostr.Bech32.decode("npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6")
      {:ok, "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"}

  """
  @spec decode(bech32()) :: {:ok, hex()} | {:error, term()}
  def decode(data) do
    case Bechamel.decode(data) do
      {:ok, _hrp, bin} ->
        hex_bin = Base.encode16(bin, case: :lower)
        {:ok, hex_bin}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Encodes a hex secret key as a bech32 `nsec` string."
  @spec hex_to_nsec(hex()) :: {:ok, bech32()} | {:error, :invalid_hex}
  def hex_to_nsec(seckey), do: encode("nsec", seckey)

  @doc "Encodes a hex public key as a bech32 `npub` string."
  @spec hex_to_npub(hex()) :: {:ok, bech32()} | {:error, :invalid_hex}
  def hex_to_npub(pubkey), do: encode("npub", pubkey)

  @doc "Encodes a hex event ID as a bech32 `note` string."
  @spec hex_to_note(hex()) :: {:ok, bech32()} | {:error, :invalid_hex}
  def hex_to_note(event_id), do: encode("note", event_id)

  @doc "Encodes a hex profile identifier as a bech32 `nprofile` string."
  @spec hex_to_nprofile(hex()) :: {:ok, bech32()} | {:error, :invalid_hex}
  def hex_to_nprofile(profile_id), do: encode("nprofile", profile_id)

  @doc "Decodes a bech32 `nsec` string to hex."
  @spec nsec_to_hex(bech32()) :: {:ok, hex()} | {:error, term()}
  def nsec_to_hex("nsec" <> _data = data), do: decode(data)

  @doc "Decodes a bech32 `npub` string to hex."
  @spec npub_to_hex(bech32()) :: {:ok, hex()} | {:error, term()}
  def npub_to_hex("npub" <> _data = data), do: decode(data)

  @doc "Decodes a bech32 `note` string to hex."
  @spec note_to_hex(bech32()) :: {:ok, hex()} | {:error, term()}
  def note_to_hex("note" <> _data = data), do: decode(data)

  @doc "Decodes a bech32 `nprofile` string to hex."
  @spec nprofile_to_hex(bech32()) :: {:ok, hex()} | {:error, term()}
  def nprofile_to_hex("nprofile" <> _data = data), do: decode(data)
end
