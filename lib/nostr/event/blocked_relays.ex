defmodule Nostr.Event.BlockedRelays do
  @moduledoc """
  Blocked Relays List (Kind 10006)

  A list of relays that clients should never connect to. Contains relay URLs
  via `relay` tags.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.{Event, Tag, NIP51}

  defstruct [:event, relays: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          relays: [URI.t()]
        }

  @doc """
  Parses a kind 10006 event into a `BlockedRelays` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_006} = event) do
    relays =
      event
      |> NIP51.get_tag_values(:relay)
      |> Enum.map(&URI.parse/1)

    %__MODULE__{
      event: event,
      relays: relays
    }
  end

  @doc """
  Creates a new blocked relays list (kind 10006).

  ## Arguments

    - `relay_urls` - List of relay URLs to block
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Example

      iex> BlockedRelays.create(["wss://spam-relay.com", "wss://bad-relay.net"])
  """
  @spec create([binary()], Keyword.t()) :: t()
  def create(relay_urls, opts \\ []) when is_list(relay_urls) do
    tags = Enum.map(relay_urls, &Tag.create(:relay, &1))
    opts = Keyword.merge(opts, tags: tags, content: "")

    10_006
    |> Event.create(opts)
    |> parse()
  end
end
