defmodule Nostr.NIP21 do
  @moduledoc """
  NIP-21: `nostr:` URI scheme.

  This module provides encoding and decoding of `nostr:` URIs, which wrap
  NIP-19 bech32 identifiers for maximum interoperability.

  Supported identifiers:
  - `npub` - public keys
  - `nprofile` - profiles with relay hints
  - `note` - event IDs
  - `nevent` - events with relay hints
  - `naddr` - addressable event coordinates

  Note: `nsec` (private keys) are explicitly **not supported** in URIs for security reasons.

  ## Examples

      iex> Nostr.NIP21.to_uri("npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6")
      {:ok, "nostr:npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"}

      iex> Nostr.NIP21.parse("nostr:npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6")
      {:ok, :npub, "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"}

  """

  alias Nostr.NIP19

  @uri_scheme "nostr:"

  # Encoding functions

  @doc """
  Converts a bech32-encoded NIP-19 string to a `nostr:` URI.

  Returns `{:error, :nsec_not_allowed}` if attempting to create a URI from a private key.

  ## Examples

      iex> Nostr.NIP21.to_uri("npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6")
      {:ok, "nostr:npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"}

      iex> Nostr.NIP21.to_uri("nsec1...")
      {:error, :nsec_not_allowed}

  """
  @spec to_uri(String.t()) :: {:ok, String.t()} | {:error, :nsec_not_allowed | term()}
  def to_uri("nsec" <> _rest), do: {:error, :nsec_not_allowed}

  def to_uri(bech32) when is_binary(bech32) do
    {:ok, @uri_scheme <> bech32}
  end

  @doc """
  Creates a `nostr:` URI for a public key.

  ## Examples

      iex> Nostr.NIP21.encode_npub("3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d")
      {:ok, "nostr:npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6"}

  """
  @spec encode_npub(String.t()) :: {:ok, String.t()} | {:error, term()}
  def encode_npub(pubkey) do
    with {:ok, npub} <- Nostr.Bech32.hex_to_npub(pubkey) do
      {:ok, @uri_scheme <> npub}
    end
  end

  @doc """
  Creates a `nostr:` URI for a profile with optional relay hints.

  ## Examples

      iex> Nostr.NIP21.encode_nprofile("3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", ["wss://relay.example.com"])
      {:ok, "nostr:nprofile1..."}

  """
  @spec encode_nprofile(String.t(), [String.t()]) :: {:ok, String.t()} | {:error, term()}
  def encode_nprofile(pubkey, relays \\ []) do
    with {:ok, nprofile} <- NIP19.encode_nprofile(pubkey, relays) do
      {:ok, @uri_scheme <> nprofile}
    end
  end

  @doc """
  Creates a `nostr:` URI for an event ID.

  ## Examples

      iex> Nostr.NIP21.encode_note("b9f5441e45ca39179320e0031cfb18e34078673dcc3d3e3a3b3a981571b14f4e")
      {:ok, "nostr:note1..."}

  """
  @spec encode_note(String.t()) :: {:ok, String.t()} | {:error, term()}
  def encode_note(event_id) do
    with {:ok, note} <- Nostr.Bech32.hex_to_note(event_id) do
      {:ok, @uri_scheme <> note}
    end
  end

  @doc """
  Creates a `nostr:` URI for an event with optional metadata.

  ## Options

  - `:relays` - list of relay URLs
  - `:author` - hex-encoded author public key
  - `:kind` - event kind number

  ## Examples

      iex> Nostr.NIP21.encode_nevent("b9f5441e45ca39179320e0031cfb18e34078673dcc3d3e3a3b3a981571b14f4e", relays: ["wss://relay.example.com"])
      {:ok, "nostr:nevent1..."}

  """
  @spec encode_nevent(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def encode_nevent(event_id, opts \\ []) do
    with {:ok, nevent} <- NIP19.encode_nevent(event_id, opts) do
      {:ok, @uri_scheme <> nevent}
    end
  end

  @doc """
  Creates a `nostr:` URI for an addressable event coordinate.

  ## Examples

      iex> Nostr.NIP21.encode_naddr("my-article", "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d", 30023)
      {:ok, "nostr:naddr1..."}

  """
  @spec encode_naddr(String.t(), String.t(), non_neg_integer(), [String.t()]) ::
          {:ok, String.t()} | {:error, term()}
  def encode_naddr(identifier, pubkey, kind, relays \\ []) do
    with {:ok, naddr} <- NIP19.encode_naddr(identifier, pubkey, kind, relays) do
      {:ok, @uri_scheme <> naddr}
    end
  end

  # Decoding functions

  @doc """
  Parses a `nostr:` URI and returns the decoded entity.

  Returns the same result as `Nostr.NIP19.decode/1`, but rejects `nsec` URIs.

  ## Examples

      iex> Nostr.NIP21.parse("nostr:npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6")
      {:ok, :npub, "3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d"}

      iex> Nostr.NIP21.parse("nostr:nsec1...")
      {:error, :nsec_not_allowed}

      iex> Nostr.NIP21.parse("https://example.com")
      {:error, :invalid_uri_scheme}

  """
  @spec parse(String.t()) ::
          {:ok, :npub | :note, String.t()}
          | {:ok, :nprofile, NIP19.Profile.t()}
          | {:ok, :nevent, NIP19.Event.t()}
          | {:ok, :naddr, NIP19.Address.t()}
          | {:error, :nsec_not_allowed | :invalid_uri_scheme | term()}
  def parse(@uri_scheme <> "nsec" <> _rest), do: {:error, :nsec_not_allowed}

  def parse(@uri_scheme <> bech32) do
    NIP19.decode(bech32)
  end

  def parse(_other), do: {:error, :invalid_uri_scheme}
end
