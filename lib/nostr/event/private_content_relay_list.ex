defmodule Nostr.Event.PrivateContentRelayList do
  @moduledoc """
  Private Content Relay List (Kind 10013)

  Lists preferred relays for storing private events like Draft Wraps.
  Relay URLs are stored as NIP-44 encrypted private tags.

  Clients SHOULD publish kind 31234 (Draft Wraps) events to relays listed here.
  It's recommended that private storage relays be NIP-42 authed and only allow
  downloads of events signed by the authenticated user.

  ## Examples

      # Create a private content relay list
      relays = ["wss://private.relay.com", "wss://myrelay.mydomain.com"]
      {:ok, list} = PrivateContentRelayList.create(relays, seckey)

      # Decrypt to access relays
      {:ok, decrypted} = PrivateContentRelayList.decrypt(list, seckey)
      decrypted.relays  # => ["wss://private.relay.com", "wss://myrelay.mydomain.com"]

  See: https://github.com/nostr-protocol/nips/blob/master/37.md
  """
  @moduledoc tags: [:event, :nip37], nip: 37

  alias Nostr.{Event, NIP44, Crypto}

  defstruct [:event, :relays]

  @type t() :: %__MODULE__{
          event: Event.t(),
          relays: [binary()] | nil
        }

  @doc """
  Parses a kind 10013 event into a PrivateContentRelayList struct.

  The relays field will be nil until decrypt/2 is called.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_013} = event) do
    %__MODULE__{
      event: event,
      relays: nil
    }
  end

  @doc """
  Creates a private content relay list event.

  Relay URLs are stored as encrypted private tags in the content field.

  ## Arguments
    - `relays` - List of relay URLs (e.g., ["wss://relay.example.com"])
    - `seckey` - Hex-encoded secret key for signing and encryption
    - `opts` - Options

  ## Options
    - `:pubkey` - Override pubkey (derived from seckey if not provided)
    - `:created_at` - Override created_at timestamp

  ## Returns
    - `{:ok, relay_list}` - The created relay list (with relays field populated)
  """
  @spec create(relays :: [binary()], seckey :: binary(), opts :: Keyword.t()) :: {:ok, t()}
  def create(relays, seckey, opts \\ []) when is_list(relays) do
    pubkey = Keyword.get_lazy(opts, :pubkey, fn -> Crypto.pubkey(seckey) end)

    # Private tags are JSON array of tags: [["relay", "wss://..."], ...]
    private_tags = Enum.map(relays, fn relay -> ["relay", relay] end)
    private_tags_json = JSON.encode!(private_tags)
    encrypted_content = NIP44.encrypt(private_tags_json, seckey, pubkey)

    event_opts =
      opts
      |> Keyword.merge(content: encrypted_content, tags: [], pubkey: pubkey)

    event =
      10_013
      |> Event.create(event_opts)
      |> Event.sign(seckey)

    list = %__MODULE__{
      event: event,
      relays: relays
    }

    {:ok, list}
  end

  @doc """
  Decrypts a private content relay list and returns it with the relays field populated.

  ## Arguments
    - `list` - The PrivateContentRelayList struct to decrypt
    - `seckey` - Hex-encoded secret key for decryption

  ## Returns
    - `{:ok, relay_list}` - The list with relays field populated
    - `{:error, reason}` - On decryption failure
  """
  @spec decrypt(t(), binary()) :: {:ok, t()} | {:error, atom()}
  def decrypt(%__MODULE__{event: event} = list, seckey) do
    if event.content == "" do
      {:ok, %{list | relays: []}}
    else
      pubkey = event.pubkey

      case NIP44.decrypt(event.content, seckey, pubkey) do
        {:ok, tags_json} ->
          case JSON.decode(tags_json) do
            {:ok, private_tags} ->
              relays = extract_relays(private_tags)
              {:ok, %{list | relays: relays}}

            {:error, _} ->
              {:error, :invalid_private_tags_json}
          end

        {:error, _} = error ->
          error
      end
    end
  end

  # Extract relay URLs from private tags
  defp extract_relays(private_tags) when is_list(private_tags) do
    private_tags
    |> Enum.filter(fn
      ["relay", _url | _] -> true
      _ -> false
    end)
    |> Enum.map(fn ["relay", url | _] -> url end)
  end
end
