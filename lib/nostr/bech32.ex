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

  def encode(hrp, data) do
    case Base.decode16(data, case: :lower) do
      {:ok, bin} -> {:ok, Bechamel.encode(hrp, bin)}
      :error -> {:error, :invalid_hex}
    end
  end

  def decode(data) do
    case Bechamel.decode(data) do
      {:ok, _hrp, bin} ->
         hex_bin = Base.encode16(bin, case: :lower)
         {:ok, hex_bin}
      {:error, reason} -> {:error, reason}
    end
  end

  def bytes_to_nsec(seckey), do: encode("nsec", seckey)
  def bytes_to_npub(pubkey), do: encode("npub", pubkey)
  def bytes_to_note(event_id), do: encode("note", event_id)
  def bytes_to_nprofile(event_id), do: encode("nprofile", event_id)

  def nsec_to_hex("nsec" <> _data = data), do: decode(data)
  def npub_to_hex("npub" <> _data = data), do: decode(data)
  def note_to_hex("note" <> _data = data), do: decode(data)
  def nprofile_to_hex("nprofile" <> _data = data), do: decode(data)
end
