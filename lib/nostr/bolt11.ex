defmodule Nostr.Bolt11 do
  @moduledoc """
  BOLT-11 Lightning Invoice parser.

  Parses Lightning Network invoices according to the BOLT-11 specification.
  Used by NIP-57 for extracting payment information from zap receipts.

  ## Examples

      iex> {:ok, invoice} = Bolt11.decode("lnbc10u1...")
      iex> Bolt11.amount_sats(invoice)
      1000

  See: https://github.com/lightning/bolts/blob/master/11-payment-encoding.md
  """

  @typedoc "Parsed BOLT-11 invoice"
  @type t() :: %__MODULE__{
          raw: binary(),
          prefix: binary(),
          network: :mainnet | :testnet | :regtest,
          amount_msats: non_neg_integer() | nil,
          timestamp: non_neg_integer(),
          payment_hash: binary() | nil,
          description: binary() | nil,
          description_hash: binary() | nil,
          payee_pubkey: binary() | nil,
          expiry: non_neg_integer(),
          signature: binary() | nil,
          recovery_flag: non_neg_integer() | nil
        }

  defstruct [
    :raw,
    :prefix,
    :network,
    :amount_msats,
    :timestamp,
    :payment_hash,
    :description,
    :description_hash,
    :payee_pubkey,
    :signature,
    :recovery_flag,
    expiry: 3600
  ]

  # Amount multipliers (base unit is bitcoin = 100_000_000_000 msats)
  @multipliers %{
    ?m => 100_000_000,
    ?u => 100_000,
    ?n => 100,
    ?p => 1
  }

  # Tagged field types (5-bit values)
  @tag_payment_hash 1
  @tag_description 13
  @tag_payee_pubkey 19
  @tag_description_hash 23
  @tag_expiry 6

  @doc """
  Decodes a BOLT-11 invoice string.

  Returns `{:ok, invoice}` on success, `{:error, reason}` on failure.

  ## Examples

      iex> Bolt11.decode("lnbc10u1pjq...")
      {:ok, %Bolt11{amount_msats: 1_000_000, ...}}

      iex> Bolt11.decode("invalid")
      {:error, :invalid_prefix}

  """
  @spec decode(binary()) :: {:ok, t()} | {:error, atom()}
  def decode(invoice) when is_binary(invoice) do
    invoice = String.downcase(invoice)

    with {:ok, {hrp, data}} <- decode_bech32(invoice),
         {:ok, prefix, network, amount_msats} <- parse_hrp(hrp),
         {:ok, timestamp, tagged_fields, signature, recovery_flag} <- parse_data(data) do
      {:ok,
       %__MODULE__{
         raw: invoice,
         prefix: prefix,
         network: network,
         amount_msats: amount_msats,
         timestamp: timestamp,
         payment_hash: Map.get(tagged_fields, :payment_hash),
         description: Map.get(tagged_fields, :description),
         description_hash: Map.get(tagged_fields, :description_hash),
         payee_pubkey: Map.get(tagged_fields, :payee_pubkey),
         expiry: Map.get(tagged_fields, :expiry, 3600),
         signature: signature,
         recovery_flag: recovery_flag
       }}
    end
  end

  @doc """
  Returns the amount in satoshis, or nil if no amount specified.

  ## Examples

      iex> {:ok, inv} = Bolt11.decode("lnbc10u1...")
      iex> Bolt11.amount_sats(inv)
      1000

  """
  @spec amount_sats(t()) :: non_neg_integer() | nil
  def amount_sats(%__MODULE__{amount_msats: nil}), do: nil
  def amount_sats(%__MODULE__{amount_msats: msats}), do: div(msats, 1000)

  @doc """
  Returns the amount in millisatoshis, or nil if no amount specified.
  """
  @spec amount_msats(t()) :: non_neg_integer() | nil
  def amount_msats(%__MODULE__{amount_msats: msats}), do: msats

  @doc """
  Checks if the invoice has expired.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{timestamp: ts, expiry: exp}) do
    DateTime.utc_now() |> DateTime.to_unix() > ts + exp
  end

  @doc """
  Returns the expiry time as a DateTime.
  """
  @spec expires_at(t()) :: DateTime.t()
  def expires_at(%__MODULE__{timestamp: ts, expiry: exp}) do
    DateTime.from_unix!(ts + exp)
  end

  # Bech32 decoding (BOLT-11 uses bech32 without length limit)
  defp decode_bech32(invoice) do
    case Bechamel.decode(invoice, ignore_length: true) do
      {:ok, hrp, data} -> {:ok, {hrp, data}}
      {:error, _reason} -> {:error, :invalid_bech32}
    end
  end

  # Parse human readable part: ln + network + [amount + multiplier]
  defp parse_hrp(hrp) do
    case hrp do
      "lnbc" <> rest -> parse_amount("lnbc", :mainnet, rest)
      "lntb" <> rest -> parse_amount("lntb", :testnet, rest)
      "lnbcrt" <> rest -> parse_amount("lnbcrt", :regtest, rest)
      _hrp -> {:error, :invalid_prefix}
    end
  end

  defp parse_amount(prefix, network, "") do
    {:ok, prefix, network, nil}
  end

  defp parse_amount(prefix, network, amount_str) do
    case parse_amount_string(amount_str) do
      {:ok, msats} -> {:ok, prefix, network, msats}
      :error -> {:error, :invalid_amount}
    end
  end

  defp parse_amount_string(str) do
    # Amount format: digits followed by optional multiplier (m, u, n, p)
    case Regex.run(~r/^(\d+)([munp])?$/, str) do
      [_full_match, digits] ->
        # No multiplier means BTC
        {:ok, String.to_integer(digits) * 100_000_000_000}

      [_full_match, digits, <<mult>>] ->
        case Map.get(@multipliers, mult) do
          nil -> :error
          factor -> {:ok, String.to_integer(digits) * factor}
        end

      _no_match ->
        :error
    end
  end

  # Parse data: timestamp (35 bits) + tagged fields + signature (520 bits) + recovery (5 bits)
  defp parse_data(data) when is_list(data) do
    # Convert 5-bit values to binary
    bits =
      Enum.map_join(data, fn val ->
        val
        |> Integer.to_string(2)
        |> String.pad_leading(5, "0")
      end)

    # Total length must be at least timestamp (35) + signature (520) + recovery (5) = 560 bits
    if String.length(bits) < 560 do
      {:error, :data_too_short}
    else
      # Extract timestamp (first 35 bits = 7 * 5-bit values)
      <<timestamp_bits::binary-size(35), rest::binary>> = bits
      timestamp = String.to_integer(timestamp_bits, 2)

      # Signature is last 520 bits, recovery flag is last 5 bits
      sig_start = String.length(rest) - 525
      tagged_bits = String.slice(rest, 0, sig_start)
      sig_bits = String.slice(rest, sig_start, 520)
      recovery_bits = String.slice(rest, sig_start + 520, 5)

      signature = bits_to_binary(sig_bits)
      recovery_flag = String.to_integer(recovery_bits, 2)

      tagged_fields = parse_tagged_fields(tagged_bits, %{})

      {:ok, timestamp, tagged_fields, signature, recovery_flag}
    end
  end

  # Parse tagged fields: each field is type (5 bits) + length (10 bits) + data
  defp parse_tagged_fields("", acc), do: acc

  defp parse_tagged_fields(bits, acc) when byte_size(bits) < 15 do
    # Not enough bits for type + length
    acc
  end

  defp parse_tagged_fields(bits, acc) do
    <<type_bits::binary-size(5), length_bits::binary-size(10), rest::binary>> = bits
    type = String.to_integer(type_bits, 2)
    length = String.to_integer(length_bits, 2)
    data_bits = length * 5

    if String.length(rest) < data_bits do
      acc
    else
      data = String.slice(rest, 0, data_bits)
      remaining = String.slice(rest, data_bits, String.length(rest))

      acc = parse_tagged_field(type, data, acc)
      parse_tagged_fields(remaining, acc)
    end
  end

  # Payment hash (type 1): 52 * 5 = 260 bits = 32 bytes + 4 padding bits
  defp parse_tagged_field(@tag_payment_hash, data, acc) do
    hash =
      data
      |> String.slice(0, 256)
      |> bits_to_binary()
      |> Base.encode16(case: :lower)

    Map.put(acc, :payment_hash, hash)
  end

  # Description (type 13): UTF-8 string
  defp parse_tagged_field(@tag_description, data, acc) do
    # Pad to byte boundary
    padded_len = ceil(String.length(data) / 8) * 8
    padded = String.pad_trailing(data, padded_len, "0")
    desc = bits_to_binary(padded)
    Map.put(acc, :description, desc)
  end

  # Payee pubkey (type 19): 53 * 5 = 265 bits = 33 bytes + 1 padding bit
  defp parse_tagged_field(@tag_payee_pubkey, data, acc) do
    # Take first 264 bits (33 bytes)
    pubkey =
      data
      |> String.slice(0, 264)
      |> bits_to_binary()
      |> Base.encode16(case: :lower)

    Map.put(acc, :payee_pubkey, pubkey)
  end

  # Description hash (type 23): 52 * 5 = 260 bits = 32 bytes + 4 padding bits
  defp parse_tagged_field(@tag_description_hash, data, acc) do
    hash =
      data
      |> String.slice(0, 256)
      |> bits_to_binary()
      |> Base.encode16(case: :lower)

    Map.put(acc, :description_hash, hash)
  end

  # Expiry (type 6): variable length integer
  defp parse_tagged_field(@tag_expiry, data, acc) do
    expiry = String.to_integer(data, 2)
    Map.put(acc, :expiry, expiry)
  end

  # Unknown tag types - ignore
  defp parse_tagged_field(_type, _data, acc), do: acc

  # Convert binary string to bytes
  defp bits_to_binary(bits) do
    bits
    |> String.graphemes()
    |> Enum.chunk_every(8)
    |> Enum.map(fn chunk ->
      chunk
      |> Enum.join()
      |> String.to_integer(2)
    end)
    |> :binary.list_to_bin()
  end
end
