defmodule Nostr.Event.SearchRelays do
  @moduledoc """
  Search Relays List (Kind 10007)

  A list of relays that clients should use when performing search queries.
  Contains relay URLs via `relay` tags.

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, relays: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          relays: [URI.t()]
        }

  @doc """
  Parses a kind 10007 event into a `SearchRelays` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_007} = event) do
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
  Creates a new search relays list (kind 10007).

  ## Arguments

    - `relay_urls` - List of relay URLs to use for search
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Example

      iex> SearchRelays.create(["wss://search.nostr.band", "wss://relay.nostr.band"])
  """
  @spec create([binary()], Keyword.t()) :: t()
  def create(relay_urls, opts \\ []) when is_list(relay_urls) do
    tags = Enum.map(relay_urls, &Tag.create(:relay, &1))
    opts = Keyword.merge(opts, tags: tags, content: "")

    10_007
    |> Event.create(opts)
    |> parse()
  end
end
