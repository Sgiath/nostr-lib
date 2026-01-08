defmodule Nostr.NIP19.TLV do
  @moduledoc """
  Simple TLV (Type-Length-Value) encoding for NIP-19 shareable identifiers.

  NIP-19 uses a simple TLV format where:
  - Type: 1 byte (uint8)
  - Length: 1 byte (uint8)
  - Value: L bytes

  This is different from ASN.1 BER-TLV which uses variable-length tags and lengths.

  ## TLV Types

  - `0` (special): depends on prefix - pubkey for nprofile, event_id for nevent, d-tag for naddr
  - `1` (relay): relay URL where entity is likely found (can repeat)
  - `2` (author): 32 bytes of event author pubkey
  - `3` (kind): 32-bit unsigned big-endian integer of event kind
  """

  @type tlv_type :: 0..255
  @type tlv_entry :: {tlv_type(), binary()}

  # TLV type constants
  @special 0
  @relay 1
  @author 2
  @kind 3

  @doc "TLV type for special data (pubkey, event_id, or d-tag depending on prefix)"
  def special, do: @special

  @doc "TLV type for relay URLs"
  def relay, do: @relay

  @doc "TLV type for author pubkey"
  def author, do: @author

  @doc "TLV type for event kind"
  def kind, do: @kind

  @doc """
  Encodes a single TLV entry to binary.

  ## Examples

      iex> Nostr.NIP19.TLV.encode_tlv(0, <<0xCA, 0xFE>>)
      <<0, 2, 0xCA, 0xFE>>

      iex> Nostr.NIP19.TLV.encode_tlv(1, "wss://relay.example.com")
      <<1, 23, "wss://relay.example.com">>

  """
  @spec encode_tlv(tlv_type(), binary()) :: binary()
  def encode_tlv(type, value) when is_integer(type) and type >= 0 and type <= 255 do
    length = byte_size(value)

    if length > 255 do
      raise ArgumentError, "TLV value too long: #{length} bytes (max 255)"
    end

    <<type::8, length::8, value::binary>>
  end

  @doc """
  Encodes a list of TLV entries to binary.

  ## Examples

      iex> entries = [{0, <<0xAB, 0xCD>>}, {1, "relay"}]
      iex> Nostr.NIP19.TLV.encode_tlvs(entries)
      <<0, 2, 0xAB, 0xCD, 1, 5, "relay">>

  """
  @spec encode_tlvs([tlv_entry()]) :: binary()
  def encode_tlvs(entries) when is_list(entries) do
    Enum.reduce(entries, <<>>, fn {type, value}, acc ->
      acc <> encode_tlv(type, value)
    end)
  end

  @doc """
  Decodes binary data into a list of TLV entries.

  Per NIP-19 spec, unknown TLV types are ignored rather than causing errors.

  ## Examples

      iex> Nostr.NIP19.TLV.decode_tlvs(<<0, 2, 0xAB, 0xCD, 1, 5, "relay">>)
      {:ok, [{0, <<0xAB, 0xCD>>}, {1, "relay"}]}

      iex> Nostr.NIP19.TLV.decode_tlvs(<<0, 5, 0xAB>>)
      {:error, :incomplete_tlv}

  """
  @spec decode_tlvs(binary()) :: {:ok, [tlv_entry()]} | {:error, :incomplete_tlv}
  def decode_tlvs(data) when is_binary(data) do
    decode_tlvs_acc(data, [])
  end

  defp decode_tlvs_acc(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  # Handle trailing zero padding from bech32 5-bit to 8-bit conversion
  defp decode_tlvs_acc(<<0>>, acc), do: {:ok, Enum.reverse(acc)}
  defp decode_tlvs_acc(<<0, 0>>, acc), do: {:ok, Enum.reverse(acc)}
  defp decode_tlvs_acc(<<0, 0, 0>>, acc), do: {:ok, Enum.reverse(acc)}
  defp decode_tlvs_acc(<<0, 0, 0, 0>>, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_tlvs_acc(<<type::8, length::8, rest::binary>>, acc) do
    if byte_size(rest) >= length do
      <<value::binary-size(length), remaining::binary>> = rest
      decode_tlvs_acc(remaining, [{type, value} | acc])
    else
      {:error, :incomplete_tlv}
    end
  end

  defp decode_tlvs_acc(_data, _acc), do: {:error, :incomplete_tlv}

  @doc """
  Finds all values for a given TLV type in a list of entries.

  ## Examples

      iex> entries = [{0, "pubkey"}, {1, "relay1"}, {1, "relay2"}]
      iex> Nostr.NIP19.TLV.find_all(entries, 1)
      ["relay1", "relay2"]

      iex> Nostr.NIP19.TLV.find_all(entries, 2)
      []

  """
  @spec find_all([tlv_entry()], tlv_type()) :: [binary()]
  def find_all(entries, type) do
    entries
    |> Enum.filter(fn {t, _v} -> t == type end)
    |> Enum.map(fn {_t, v} -> v end)
  end

  @doc """
  Finds the first value for a given TLV type in a list of entries.

  ## Examples

      iex> entries = [{0, "pubkey"}, {1, "relay1"}]
      iex> Nostr.NIP19.TLV.find_first(entries, 0)
      "pubkey"

      iex> Nostr.NIP19.TLV.find_first(entries, 2)
      nil

  """
  @spec find_first([tlv_entry()], tlv_type()) :: binary() | nil
  def find_first(entries, type) do
    case Enum.find(entries, fn {t, _v} -> t == type end) do
      {_t, v} -> v
      nil -> nil
    end
  end
end
