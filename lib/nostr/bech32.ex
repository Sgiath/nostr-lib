defmodule Nostr.Bech32 do
  @moduledoc """
  Bech32 encoded entities

  Defined in NIP-19
  https://github.com/nostr-protocol/nips/blob/master/19.md

  ## Example:

      iex> Nostr.Bech32.hex_to_npub("3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d")
      "npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"

      iex> Nostr.Bech32.npub_to_hex("npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6")
      "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"

  """

  def bytes_to_nsec(seckey), do: encode("nsec", seckey)
  def hex_to_nsec(seckey), do: seckey |> hex_to_bytes() |> bytes_to_nsec()

  def bytes_to_npub(pubkey), do: encode("npub", pubkey)
  def hex_to_npub(pubkey), do: pubkey |> hex_to_bytes() |> bytes_to_npub()

  def bytes_to_note(event_id), do: encode("note", event_id)
  def hex_to_note(event_id), do: event_id |> hex_to_bytes() |> bytes_to_note()

  def bytes_to_nprofile(event_id), do: encode("nprofile", event_id)

  def nsec_to_bytes("nsec" <> _data = data), do: decode(data)
  def nsec_to_hex("nsec" <> _data = data), do: data |> decode() |> bytes_to_hex()

  def npub_to_bytes("npub" <> _data = data), do: decode(data)
  def npub_to_hex("npub" <> _data = data), do: data |> decode() |> bytes_to_hex()

  def note_to_bytes("note" <> _data = data), do: decode(data)
  def note_to_hex("note" <> _data = data), do: data |> decode() |> bytes_to_hex()

  def nprofile_to_bytes("nprofile" <> _data = data), do: decode(data)

  # Utils

  defp hex_to_bytes(data), do: Base.decode16!(data, case: :lower)
  defp bytes_to_hex(data), do: Base.encode16(data, case: :lower)

  defp encode(hrp, data) do
    {:ok, encoded} = ExBech32.encode(hrp, data, :bech32)
    encoded
  end

  def decode(data) do
    {:ok, {_hrp, bytes, :bech32}} = ExBech32.decode(data)
    bytes
  end
end
