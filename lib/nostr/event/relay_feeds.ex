defmodule Nostr.Event.RelayFeeds do
  @moduledoc """
  Relay Feeds List (Kind 10012)

  A list of user favorite browsable relays (and relay sets). Contains
  `relay` tags for individual relays and `a` tags for relay sets (kind:30002).

  Defined in NIP 51
  https://github.com/nostr-protocol/nips/blob/master/51.md
  """
  @moduledoc tags: [:event, :nip51], nip: 51

  alias Nostr.Event
  alias Nostr.NIP51
  alias Nostr.Tag

  defstruct [:event, relays: [], relay_sets: []]

  @type t() :: %__MODULE__{
          event: Event.t(),
          relays: [URI.t()],
          relay_sets: [binary()]
        }

  @doc """
  Parses a kind 10012 event into a `RelayFeeds` struct.
  """
  @spec parse(Event.t()) :: t()
  def parse(%Event{kind: 10_012} = event) do
    relays =
      event
      |> NIP51.get_tag_values(:relay)
      |> Enum.map(&URI.parse/1)

    %__MODULE__{
      event: event,
      relays: relays,
      relay_sets: NIP51.get_tag_values(event, :a)
    }
  end

  @doc """
  Creates a new relay feeds list (kind 10012).

  ## Arguments

    - `items` - Map or keyword list with feed items
    - `opts` - Optional event arguments (`pubkey`, `created_at`)

  ## Item Keys

    - `:relays` - List of relay URLs
    - `:relay_sets` - List of relay set addresses (kind:30002)

  ## Example

      RelayFeeds.create(%{
        relays: ["wss://relay.com"],
        relay_sets: ["30002:pubkey:identifier"]
      })
  """
  @spec create(map() | Keyword.t(), Keyword.t()) :: t()
  def create(items, opts \\ [])

  def create(items, opts) when is_list(items), do: create(Map.new(items), opts)

  def create(items, opts) when is_map(items) do
    relay_tags =
      items
      |> Map.get(:relays, [])
      |> Enum.map(&Tag.create(:relay, &1))

    set_tags =
      items
      |> Map.get(:relay_sets, [])
      |> Enum.map(&Tag.create(:a, &1))

    tags = relay_tags ++ set_tags

    opts = Keyword.merge(opts, tags: tags, content: "")

    10_012
    |> Event.create(opts)
    |> parse()
  end
end
