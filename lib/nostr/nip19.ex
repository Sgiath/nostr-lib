defmodule Nostr.NIP19 do
  @moduledoc """
  NIP-19: Bech32-encoded shareable identifiers with metadata.

  This module provides encoding and decoding of NIP-19 entities that include
  TLV (Type-Length-Value) metadata such as relay hints.

  ## Supported Formats

  ### Bare keys and IDs (simple 32-byte data)
  - `npub` - public key
  - `nsec` - private key
  - `note` - event ID

  ### Shareable identifiers with metadata (TLV encoded)
  - `nprofile` - profile with optional relay hints
  - `nevent` - event with optional relay hints, author, and kind
  - `naddr` - addressable event coordinate with identifier, author, kind, and optional relays

  ## Examples

      # Encode a profile with relay hints
      iex> Nostr.NIP19.encode_nprofile("3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", ["wss://relay.example.com"])
      {:ok, "nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpvem8x6"}

      # Decode an nprofile to get pubkey and relays
      iex> {:ok, profile} = Nostr.NIP19.decode_nprofile("nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpvem8x6")
      iex> profile.pubkey
      "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"

  """

  alias Nostr.NIP19.TLV

  # Struct definitions

  defmodule Profile do
    @moduledoc """
    Represents a decoded nprofile entity.

    Fields:
    - `pubkey` - 32-byte hex-encoded public key
    - `relays` - list of relay URLs where the profile might be found
    """
    @type t :: %__MODULE__{
            pubkey: String.t(),
            relays: [String.t()]
          }
    defstruct [:pubkey, relays: []]
  end

  defmodule Event do
    @moduledoc """
    Represents a decoded nevent entity.

    Fields:
    - `event_id` - 32-byte hex-encoded event ID
    - `relays` - list of relay URLs where the event might be found
    - `author` - optional 32-byte hex-encoded author public key
    - `kind` - optional event kind number
    """
    @type t :: %__MODULE__{
            event_id: String.t(),
            relays: [String.t()],
            author: String.t() | nil,
            kind: non_neg_integer() | nil
          }
    defstruct [:event_id, :author, :kind, relays: []]
  end

  defmodule Address do
    @moduledoc """
    Represents a decoded naddr entity (addressable event coordinate).

    Fields:
    - `identifier` - the "d" tag value (can be empty string for normal replaceable events)
    - `pubkey` - 32-byte hex-encoded author public key (required)
    - `kind` - event kind number (required)
    - `relays` - list of relay URLs where the event might be found
    """
    @type t :: %__MODULE__{
            identifier: String.t(),
            pubkey: String.t(),
            kind: non_neg_integer(),
            relays: [String.t()]
          }
    defstruct [:identifier, :pubkey, :kind, relays: []]
  end

  # Encoding functions

  @doc """
  Encodes a profile as an nprofile bech32 string with optional relay hints.

  ## Parameters
  - `pubkey` - 32-byte hex-encoded public key
  - `relays` - list of relay URLs (optional, defaults to empty)

  ## Examples

      iex> Nostr.NIP19.encode_nprofile("3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d")
      {:ok, "nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gxerzmt"}

      iex> Nostr.NIP19.encode_nprofile("3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", ["wss://r.x.com"])
      {:ok, "nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpz4mhxue69uhkc6t8dph8x3k7d"}

  """
  @spec encode_nprofile(String.t(), [String.t()]) ::
          {:ok, String.t()} | {:error, :invalid_pubkey}
  def encode_nprofile(pubkey, relays \\ []) do
    with {:ok, pubkey_bin} <- decode_hex(pubkey, 32) do
      tlv_entries = [{TLV.special(), pubkey_bin}] ++ relay_entries(relays)
      tlv_data = TLV.encode_tlvs(tlv_entries)
      {:ok, Bechamel.encode("nprofile", tlv_data)}
    end
  end

  @doc """
  Encodes an event as an nevent bech32 string with optional metadata.

  ## Parameters
  - `event_id` - 32-byte hex-encoded event ID
  - `opts` - keyword list with optional `:relays`, `:author`, and `:kind`

  ## Examples

      iex> Nostr.NIP19.encode_nevent("b9f5441e45ca39179320e0031cfb18e34078673dcc3d3e3a3b3a981571b14f4e")
      {:ok, "nevent1qqsw04gswg4e5wr9uecqrxpelvvwxsupmhd8pa8c6ww6fvz4cmg578gpzemhxue69uhhyetvv9ujuurjd9kkzmpwdejhgxz0p8m"}

      iex> Nostr.NIP19.encode_nevent("b9f5441e45ca39179320e0031cfb18e34078673dcc3d3e3a3b3a981571b14f4e", relays: ["wss://relay.example.com"], author: "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", kind: 1)
      {:ok, nevent}

  """
  @spec encode_nevent(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, :invalid_event_id | :invalid_author}
  def encode_nevent(event_id, opts \\ []) do
    relays = Keyword.get(opts, :relays, [])
    author = Keyword.get(opts, :author)
    kind = Keyword.get(opts, :kind)

    with {:ok, event_id_bin} <- decode_hex(event_id, 32, :invalid_event_id),
         {:ok, author_bin} <- maybe_decode_hex(author, 32) do
      tlv_entries =
        [{TLV.special(), event_id_bin}] ++
          relay_entries(relays) ++
          maybe_author_entry(author_bin) ++
          maybe_kind_entry(kind)

      tlv_data = TLV.encode_tlvs(tlv_entries)
      {:ok, Bechamel.encode("nevent", tlv_data)}
    end
  end

  @doc """
  Encodes an addressable event coordinate as an naddr bech32 string.

  ## Parameters
  - `identifier` - the "d" tag value (use "" for normal replaceable events)
  - `pubkey` - 32-byte hex-encoded author public key
  - `kind` - event kind number
  - `relays` - list of relay URLs (optional)

  ## Examples

      iex> Nostr.NIP19.encode_naddr("my-article", "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", 30023)
      {:ok, naddr}

  """
  @spec encode_naddr(String.t(), String.t(), non_neg_integer(), [String.t()]) ::
          {:ok, String.t()} | {:error, :invalid_pubkey}
  def encode_naddr(identifier, pubkey, kind, relays \\ []) do
    with {:ok, pubkey_bin} <- decode_hex(pubkey, 32) do
      tlv_entries =
        [{TLV.special(), identifier}] ++
          relay_entries(relays) ++
          [{TLV.author(), pubkey_bin}] ++
          [{TLV.kind(), <<kind::unsigned-big-integer-32>>}]

      tlv_data = TLV.encode_tlvs(tlv_entries)
      {:ok, Bechamel.encode("naddr", tlv_data)}
    end
  end

  # Decoding functions

  @doc """
  Decodes an nprofile bech32 string to a Profile struct.

  ## Examples

      iex> {:ok, profile} = Nostr.NIP19.decode_nprofile("nprofile1qqsrhuxx8l9ex335q7he0f09aej04zpazpl0ne2cgukyawd24mayt8gpp4mhxue69uhhytnc9e3k7mgpz4mhxue69uhkg6nzv9ejuumpv34kytnrdaksjlyr9p")
      iex> profile.pubkey
      "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"
      iex> profile.relays
      ["wss://r.x.com", "wss://djbas.sadkb.com"]

  """
  @spec decode_nprofile(String.t()) ::
          {:ok, Profile.t()} | {:error, term()}
  def decode_nprofile("nprofile" <> _rest = bech32) do
    # NIP-19 strings can exceed BIP-173's 90 char limit when including relays
    with {:ok, "nprofile", data} <- Bechamel.decode(bech32, ignore_length: true),
         {:ok, entries} <- TLV.decode_tlvs(data) do
      case TLV.find_first(entries, TLV.special()) do
        nil ->
          {:error, :missing_pubkey}

        pubkey_bin when byte_size(pubkey_bin) == 32 ->
          relays = TLV.find_all(entries, TLV.relay())

          {:ok,
           %Profile{
             pubkey: Base.encode16(pubkey_bin, case: :lower),
             relays: relays
           }}

        _other ->
          {:error, :invalid_pubkey}
      end
    end
  end

  def decode_nprofile(_other), do: {:error, :invalid_prefix}

  @doc """
  Decodes an nevent bech32 string to an Event struct.

  ## Examples

      iex> {:ok, event} = Nostr.NIP19.decode_nevent(nevent_string)
      iex> event.event_id
      "b9f5441e45ca39179320e0031cfb18e34078673dcc3d3e3a3b3a981571b14f4e"

  """
  @spec decode_nevent(String.t()) ::
          {:ok, Event.t()} | {:error, term()}
  def decode_nevent("nevent" <> _rest = bech32) do
    # NIP-19 strings can exceed BIP-173's 90 char limit when including relays
    with {:ok, "nevent", data} <- Bechamel.decode(bech32, ignore_length: true),
         {:ok, entries} <- TLV.decode_tlvs(data) do
      case TLV.find_first(entries, TLV.special()) do
        nil ->
          {:error, :missing_event_id}

        event_id_bin when byte_size(event_id_bin) == 32 ->
          relays = TLV.find_all(entries, TLV.relay())
          author_bin = TLV.find_first(entries, TLV.author())
          kind_bin = TLV.find_first(entries, TLV.kind())

          author =
            if author_bin && byte_size(author_bin) == 32,
              do: Base.encode16(author_bin, case: :lower),
              else: nil

          kind =
            if kind_bin && byte_size(kind_bin) == 4 do
              <<k::unsigned-big-integer-32>> = kind_bin
              k
            else
              nil
            end

          {:ok,
           %Event{
             event_id: Base.encode16(event_id_bin, case: :lower),
             relays: relays,
             author: author,
             kind: kind
           }}

        _other ->
          {:error, :invalid_event_id}
      end
    end
  end

  def decode_nevent(_other), do: {:error, :invalid_prefix}

  @doc """
  Decodes an naddr bech32 string to an Address struct.

  ## Examples

      iex> {:ok, addr} = Nostr.NIP19.decode_naddr(naddr_string)
      iex> addr.identifier
      "my-article"
      iex> addr.kind
      30023

  """
  @spec decode_naddr(String.t()) ::
          {:ok, Address.t()} | {:error, term()}
  def decode_naddr("naddr" <> _rest = bech32) do
    # NIP-19 strings can exceed BIP-173's 90 char limit when including relays
    with {:ok, "naddr", data} <- Bechamel.decode(bech32, ignore_length: true),
         {:ok, entries} <- TLV.decode_tlvs(data) do
      identifier = TLV.find_first(entries, TLV.special()) || ""
      author_bin = TLV.find_first(entries, TLV.author())
      kind_bin = TLV.find_first(entries, TLV.kind())
      relays = TLV.find_all(entries, TLV.relay())

      cond do
        author_bin == nil ->
          {:error, :missing_author}

        byte_size(author_bin) != 32 ->
          {:error, :invalid_author}

        kind_bin == nil ->
          {:error, :missing_kind}

        byte_size(kind_bin) != 4 ->
          {:error, :invalid_kind}

        true ->
          <<kind::unsigned-big-integer-32>> = kind_bin

          {:ok,
           %Address{
             identifier: identifier,
             pubkey: Base.encode16(author_bin, case: :lower),
             kind: kind,
             relays: relays
           }}
      end
    end
  end

  def decode_naddr(_other), do: {:error, :invalid_prefix}

  @doc """
  Decodes any NIP-19 bech32 string and returns the appropriate struct or hex value.

  Returns:
  - `{:ok, :npub, hex}` for public keys
  - `{:ok, :nsec, hex}` for secret keys
  - `{:ok, :note, hex}` for event IDs
  - `{:ok, :nprofile, %Profile{}}` for profiles
  - `{:ok, :nevent, %Event{}}` for events
  - `{:ok, :naddr, %Address{}}` for addressable events
  - `{:error, reason}` on failure

  ## Examples

      iex> Nostr.NIP19.decode("npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6")
      {:ok, :npub, "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"}

  """
  @spec decode(String.t()) ::
          {:ok, :npub | :nsec | :note, String.t()}
          | {:ok, :nprofile, Profile.t()}
          | {:ok, :nevent, Event.t()}
          | {:ok, :naddr, Address.t()}
          | {:error, term()}
  def decode("npub" <> _rest = bech32) do
    with {:ok, "npub", data} <- Bechamel.decode(bech32) do
      {:ok, :npub, Base.encode16(data, case: :lower)}
    end
  end

  def decode("nsec" <> _rest = bech32) do
    with {:ok, "nsec", data} <- Bechamel.decode(bech32) do
      {:ok, :nsec, Base.encode16(data, case: :lower)}
    end
  end

  def decode("note" <> _rest = bech32) do
    with {:ok, "note", data} <- Bechamel.decode(bech32) do
      {:ok, :note, Base.encode16(data, case: :lower)}
    end
  end

  def decode("nprofile" <> _rest = bech32) do
    with {:ok, profile} <- decode_nprofile(bech32) do
      {:ok, :nprofile, profile}
    end
  end

  def decode("nevent" <> _rest = bech32) do
    with {:ok, event} <- decode_nevent(bech32) do
      {:ok, :nevent, event}
    end
  end

  def decode("naddr" <> _rest = bech32) do
    with {:ok, addr} <- decode_naddr(bech32) do
      {:ok, :naddr, addr}
    end
  end

  def decode(_other), do: {:error, :unknown_prefix}

  # Private helpers

  defp decode_hex(hex, expected_size, error_type \\ :invalid_pubkey) do
    case Base.decode16(hex, case: :lower) do
      {:ok, bin} when byte_size(bin) == expected_size -> {:ok, bin}
      {:ok, _bin} -> {:error, error_type}
      :error -> {:error, error_type}
    end
  end

  defp maybe_decode_hex(nil, _size), do: {:ok, nil}

  defp maybe_decode_hex(hex, expected_size) do
    case decode_hex(hex, expected_size) do
      {:ok, bin} -> {:ok, bin}
      {:error, _reason} -> {:error, :invalid_author}
    end
  end

  defp relay_entries(relays) do
    Enum.map(relays, fn relay -> {TLV.relay(), relay} end)
  end

  defp maybe_author_entry(nil), do: []
  defp maybe_author_entry(author_bin), do: [{TLV.author(), author_bin}]

  defp maybe_kind_entry(nil), do: []
  defp maybe_kind_entry(kind), do: [{TLV.kind(), <<kind::unsigned-big-integer-32>>}]
end
