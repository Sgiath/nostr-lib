defmodule Nostr.Event.GoodWikiRelays do
  @moduledoc """
  Good Wiki Relays List (Kind 10102)

  A list of NIP-54 relays deemed to only host useful wiki articles. Contains
  relay URLs via `relay` tags.

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
  Parses a kind 10102 event into a `GoodWikiRelays` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_102} = event) do
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
  Creates a new good wiki relays list (kind 10102).

  ## Arguments

    - `relay_urls` - List of relay URLs hosting quality wiki content
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Example

      iex> GoodWikiRelays.create(["wss://wiki.nostr.com", "wss://wiki-relay.example"])
  """
  @spec create([binary()], Keyword.t()) :: t()
  def create(relay_urls, opts \\ []) when is_list(relay_urls) do
    tags = Enum.map(relay_urls, &Tag.create(:relay, &1))
    opts = Keyword.merge(opts, tags: tags, content: "")

    10_102
    |> Event.create(opts)
    |> parse()
  end
end
